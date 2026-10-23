import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/finca.dart';
import '../models/form_response.dart';
import 'database_service.dart';
import 'finca_service.dart';
import 'firestore_service.dart';
import 'sync_utils.dart';
import 'template_service.dart';

/// Resultado de una operación de sincronización.
class ResultadoSync {
  final bool disponible;
  final bool enCurso;
  final int subidos;
  final int descargados;
  final int sinCambios;
  final int errores;
  final String? mensaje;

  const ResultadoSync({
    this.disponible = true,
    this.enCurso = false,
    this.subidos = 0,
    this.descargados = 0,
    this.sinCambios = 0,
    this.errores = 0,
    this.mensaje,
  });

  const ResultadoSync.noDisponible()
    : disponible = false,
      enCurso = false,
      subidos = 0,
      descargados = 0,
      sinCambios = 0,
      errores = 0,
      mensaje = null;

  const ResultadoSync.enCurso()
    : disponible = true,
      enCurso = true,
      subidos = 0,
      descargados = 0,
      sinCambios = 0,
      errores = 0,
      mensaje = null;

  int get cambios => subidos + descargados;

  String get resumen {
    if (enCurso) return 'Sincronización en curso…';
    if (!disponible) {
      return 'La nube no está disponible en esta plataforma.';
    }
    if (errores > 0 && cambios == 0) {
      return 'No se pudo sincronizar. Se reintentará al recuperar la conexión.';
    }
    if (cambios == 0) return 'Todo está sincronizado.';

    final partes = <String>[];
    if (subidos > 0) partes.add('$subidos subido(s)');
    if (descargados > 0) partes.add('$descargados descargado(s)');
    final detalle = partes.join(', ');
    return errores > 0
        ? 'Sincronización parcial: $detalle. $errores con error.'
        : 'Sincronización completada: $detalle.';
  }
}

enum _AccionSync { subir, descargar, sinCambios }

/// Documento remoto ya validado y convertido a tipos Dart.
class _DocumentoRemoto {
  final String docId;
  final String fincaId;
  final String templateId;
  final String templateTitulo;
  final Map<String, dynamic> respuestas;
  final String hash;
  final DateTime? fecha;

  _DocumentoRemoto({
    required this.docId,
    required this.fincaId,
    required this.templateId,
    required this.templateTitulo,
    required this.respuestas,
    required this.hash,
    required this.fecha,
  });

  factory _DocumentoRemoto.desde(String docId, Map<String, dynamic> data) {
    final respuestas = Map<String, dynamic>.from(data['respuestas'] as Map);
    final hash = data['hashRespuestas'];
    return _DocumentoRemoto(
      docId: docId,
      fincaId: data['fincaId'] as String,
      templateId: data['templateId'] as String,
      templateTitulo: data['templateTitulo'] as String? ?? '',
      respuestas: respuestas,
      hash: hash is String && hash.isNotEmpty
          ? hash
          : SyncUtils.hashRespuestas(respuestas),
      fecha: FirestoreService.fechaDesdeDocumento(data),
    );
  }
}

/// Datos generales de una finca descargados de Firestore.
class _FincaRemota {
  final String docId;
  final String fincaId;
  final String codigo;
  final String canton;
  final String prefijo;
  final String estado;
  final String nombreAgricultor;
  final String hash;
  final DateTime? fecha;

  _FincaRemota({
    required this.docId,
    required this.fincaId,
    required this.codigo,
    required this.canton,
    required this.prefijo,
    required this.estado,
    required this.nombreAgricultor,
    required this.hash,
    required this.fecha,
  });

  factory _FincaRemota.desde(String docId, Map<String, dynamic> data) {
    final codigo = data['codigo'] as String;
    final prefijo =
        data['prefijo'] is String && (data['prefijo'] as String).isNotEmpty
        ? data['prefijo'] as String
        : codigo.contains('-')
        ? codigo.split('-').first
        : 'REM';
    final canton = data['canton'] as String? ?? '';
    final estado = data['estado'] as String? ?? 'Activa';
    final nombreAgricultor = data['nombreAgricultor'] as String? ?? '';
    // Se calcula a partir de los campos editables para no depender de un
    // `hashDatos` antiguo o escrito manualmente.
    final hash = SyncUtils.hashFinca(
      codigo: codigo,
      canton: canton,
      prefijo: prefijo,
      estado: estado,
      nombreAgricultor: nombreAgricultor,
    );

    return _FincaRemota(
      docId: docId,
      fincaId: data['fincaId'] as String? ?? docId,
      codigo: codigo,
      canton: canton,
      prefijo: prefijo,
      estado: estado,
      nombreAgricultor: nombreAgricultor,
      hash: hash,
      fecha: FirestoreService.fechaDesdeFinca(data),
    );
  }
}

/// Orquesta el guardado local-first y la sincronización con Firestore.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final Map<String, String> _cacheTitulos = {};
  StreamSubscription<List<ConnectivityResult>>? _suscripcionConectividad;
  final StreamController<ResultadoSync> _resultadosController =
      StreamController<ResultadoSync>.broadcast();

  bool _inicializado = false;
  bool _sincronizando = false;
  bool _estabaOffline = false;
  bool _notificarAlTerminar = false;

  bool get sincronizando => _sincronizando;

  /// Resultados de sincronizaciones automáticas (por ejemplo al recuperar
  /// internet), para que la UI pueda mostrar un aviso al usuario.
  Stream<ResultadoSync> get resultados => _resultadosController.stream;

  /// Inicializa Firebase/Firestore, escucha la conectividad y lanza una
  /// sincronización inicial con los datos que ya estén en Hive.
  Future<void> initialize() async {
    if (_inicializado) return;
    _inicializado = true;

    final disponible = await FirestoreService.instance.initialize();
    if (!disponible) return;

    final conectividad = Connectivity();
    try {
      final estado = await conectividad.checkConnectivity();
      _estabaOffline = _sinConexion(estado);
    } catch (error) {
      debugPrint('No se pudo consultar la conectividad: $error');
      _estabaOffline = false;
    }

    _suscripcionConectividad = conectividad.onConnectivityChanged.listen((
      estados,
    ) {
      final online = !_sinConexion(estados);
      if (online) {
        final recupero = _estabaOffline;
        _estabaOffline = false;
        if (recupero) {
          unawaited(sincronizarTodo(notificar: true));
        }
      } else {
        _estabaOffline = true;
      }
    });

    if (!_estabaOffline) {
      unawaited(sincronizarTodo());
    }
  }

  /// Sube inmediatamente el formulario que se acaba de guardar en Hive.
  Future<ResultadoSync> sincronizarFormulario({
    required String fincaCodigo,
    required String templateId,
    required String templateTitulo,
    required Map<String, dynamic> respuestas,
    required DateTime timestamp,
  }) async {
    final disponible = await FirestoreService.instance.initialize();
    if (!disponible) return const ResultadoSync.noDisponible();

    final finca = FincaService.instance.getFincaPorCodigo(fincaCodigo);
    if (finca == null) {
      return const ResultadoSync(
        errores: 1,
        mensaje: 'No se encontró la finca del formulario.',
      );
    }

    final hash = SyncUtils.hashRespuestas(respuestas);

    try {
      await FirestoreService.instance.guardarDocumento(
        fincaId: finca.identificador,
        templateId: templateId,
        templateTitulo: templateTitulo,
        respuestas: respuestas,
        actualizadoLocalEn: timestamp,
        hashRespuestas: hash,
      );

      final registro = DatabaseService.instance.getRegistroFormResponse(
        fincaCodigo: fincaCodigo,
        templateId: templateId,
      );
      if (registro != null) {
        await DatabaseService.instance.marcarSincronizado(registro, hash: hash);
      }

      return const ResultadoSync(subidos: 1);
    } catch (error) {
      debugPrint('Error subiendo formulario: $error');
      return ResultadoSync(errores: 1, mensaje: error.toString());
    }
  }

  /// Sube inmediatamente los datos generales de una finca.
  Future<ResultadoSync> sincronizarFinca({required String fincaId}) async {
    final disponible = await FirestoreService.instance.initialize();
    if (!disponible) return const ResultadoSync.noDisponible();

    final finca = FincaService.instance.getFincaPorId(fincaId);
    if (finca == null) {
      return const ResultadoSync(
        errores: 1,
        mensaje: 'La finca no existe localmente.',
      );
    }

    try {
      await FirestoreService.instance.guardarFinca(
        fincaId: finca.identificador,
        codigo: finca.codigo,
        canton: finca.canton,
        prefijo: finca.prefijo,
        estado: finca.estado,
        nombreAgricultor: finca.nombreAgricultor,
        actualizadoLocalEn: finca.actualizadoLocalEn ?? DateTime.now(),
      );

      await FincaService.instance.marcarSincronizada(finca);
      return const ResultadoSync(subidos: 1);
    } catch (error) {
      debugPrint('Error sincronizando datos generales: $error');
      return ResultadoSync(errores: 1, mensaje: error.toString());
    }
  }

  /// Sube lo pendiente y descarga/mezcla los cambios hechos en Firestore.
  ///
  /// Si [notificar] es `true`, el resultado se publica en [resultados] para
  /// que la UI muestre un aviso (por ejemplo, al recuperar internet). Si ya
  /// hay una sincronización en curso, se notificará el resultado de esa.
  Future<ResultadoSync> sincronizarTodo({bool notificar = false}) async {
    if (_sincronizando) {
      if (notificar) _notificarAlTerminar = true;
      return const ResultadoSync.enCurso();
    }

    _sincronizando = true;
    if (notificar) _notificarAlTerminar = true;

    var subidos = 0;
    var descargados = 0;
    var sinCambios = 0;
    var errores = 0;
    ResultadoSync? resultado;

    try {
      final disponible = await FirestoreService.instance.initialize();
      if (!disponible) {
        resultado = const ResultadoSync.noDisponible();
        return resultado;
      }

      // Primero se reconcilian las fincas. Los formularios remotos ya no
      // guardan datos generales: solo referencian el ID estable de la finca.
      //
      // Si la colección `fincas` aún no está permitida por las reglas de
      // Firestore, no se debe impedir que los formularios sigan
      // sincronizándose.
      var remotasFincasData = <String, Map<String, dynamic>>{};
      try {
        remotasFincasData = await FirestoreService.instance.obtenerFincas();
      } catch (error) {
        debugPrint('No se pudieron leer las fincas de la nube: $error');
        errores++;
      }
      final remotasFincas = <String, _FincaRemota>{
        for (final entrada in remotasFincasData.entries)
          entrada.key: _FincaRemota.desde(entrada.key, entrada.value),
      };

      // Se guardan también los códigos anteriores como alias para poder
      // resolver documentos remotos legacy que solo tengan `fincaCodigo`.
      final fincaIdPorCodigo = <String, String>{};
      void registrarCodigosDeFincas() {
        for (final finca in FincaService.instance.getTodasLasFincas()) {
          fincaIdPorCodigo[finca.codigo] = finca.identificador;
          final anterior = finca.codigoAnteriorPendiente;
          if (anterior != null && anterior.isNotEmpty) {
            fincaIdPorCodigo[anterior] = finca.identificador;
          }
        }
      }

      registrarCodigosDeFincas();
      final resultadoFincas = await _sincronizarFincas(remotasFincas);
      subidos += resultadoFincas.subidos;
      descargados += resultadoFincas.descargados;
      sinCambios += resultadoFincas.sinCambios;
      errores += resultadoFincas.errores;

      registrarCodigosDeFincas();
      final remotosData = await FirestoreService.instance.obtenerFormulariosV2(
        fincaIdPorCodigo: fincaIdPorCodigo,
      );
      final remotos = <String, _DocumentoRemoto>{
        for (final entrada in remotosData.entries)
          entrada.key: _DocumentoRemoto.desde(entrada.key, entrada.value),
      };
      final locales = await DatabaseService.instance.getAllResponses();

      final remotosUsados = <String>{};
      final fincasPorCodigo = {
        for (final finca in FincaService.instance.getTodasLasFincas())
          finca.codigo: finca,
      };

      for (final local in locales) {
        final templateBase =
            local.templateBaseId ?? SyncUtils.templateBaseId(local.templateId);
        final fincaCodigo =
            local.fincaCodigo ?? _fincaPorHash(local.templateId);
        final finca = fincaCodigo == null ? null : fincasPorCodigo[fincaCodigo];

        if (finca == null) {
          debugPrint(
            'No se pudo determinar la finca del registro ${local.templateId}',
          );
          errores++;
          continue;
        }

        // Completar metadatos faltantes en registros heredados.
        if (local.fincaCodigo == null) {
          local.fincaCodigo = finca.codigo;
          local.templateBaseId = templateBase;
          local.hashRespuestas ??= SyncUtils.hashRespuestas(local.respuestas);
          await local.save();
        } else if (local.templateBaseId == null ||
            local.hashRespuestas == null) {
          local.templateBaseId = templateBase;
          local.hashRespuestas ??= SyncUtils.hashRespuestas(local.respuestas);
          await local.save();
        }

        final docIdRemoto = FirestoreService.docIdPara(
          finca.identificador,
          templateBase,
        );
        final remoto = remotos[docIdRemoto];

        if (remoto == null) {
          try {
            await _subirLocal(local, finca, templateBase);
            subidos++;
          } catch (error) {
            debugPrint('Error subiendo registro local: $error');
            errores++;
          }
          continue;
        }

        remotosUsados.add(remoto.docId);
        try {
          final accion = await _resolverConflicto(
            local,
            remoto,
            templateBase,
            finca,
          );
          switch (accion) {
            case _AccionSync.subir:
              subidos++;
            case _AccionSync.descargar:
              descargados++;
            case _AccionSync.sinCambios:
              sinCambios++;
          }
        } catch (error) {
          debugPrint('Error resolviendo conflicto: $error');
          errores++;
        }
      }

      // Documentos que existen en la nube pero no localmente.
      for (final remoto in remotos.values) {
        if (remotosUsados.contains(remoto.docId)) continue;

        try {
          await _descargarRemoto(remoto);
          descargados++;
        } catch (error) {
          debugPrint('Error descargando documento remoto: $error');
          errores++;
        }
      }

      resultado = ResultadoSync(
        subidos: subidos,
        descargados: descargados,
        sinCambios: sinCambios,
        errores: errores,
      );
      return resultado;
    } catch (error) {
      debugPrint('Error general de sincronización: $error');
      resultado = ResultadoSync(
        subidos: subidos,
        descargados: descargados,
        sinCambios: sinCambios,
        errores: errores + 1,
        mensaje: error.toString(),
      );
      return resultado;
    } finally {
      _sincronizando = false;
      final debiaNotificar = _notificarAlTerminar;
      _notificarAlTerminar = false;
      if (debiaNotificar && resultado != null && !resultado.enCurso) {
        _resultadosController.add(resultado);
      }
    }
  }

  Future<ResultadoSync> _sincronizarFincas(
    Map<String, _FincaRemota> remotas,
  ) async {
    var subidos = 0;
    var descargados = 0;
    var sinCambios = 0;
    var errores = 0;

    final locales = FincaService.instance.getTodasLasFincas().toList();
    final idsLocales = locales.map((f) => f.identificador).toSet();
    final remotasPorId = <String, _FincaRemota>{
      for (final remota in remotas.values) remota.fincaId: remota,
    };
    final usadas = <String>{};

    // Compatibilidad: una finca local creada antes de la colección `fincas`
    // puede tener un ID distinto al documento remoto con su mismo código.
    for (final local in locales) {
      if (remotasPorId.containsKey(local.identificador)) continue;

      final candidatas = remotas.values
          .where(
            (r) => r.codigo == local.codigo && !idsLocales.contains(r.fincaId),
          )
          .toList();
      if (candidatas.length != 1) continue;

      final remota = candidatas.first;
      try {
        final idAnterior = local.identificador;
        await FincaService.instance.adoptarIdRemoto(local, remota.fincaId);
        idsLocales.remove(idAnterior);
        idsLocales.add(remota.fincaId);
      } catch (error) {
        debugPrint('No se pudo vincular la finca ${local.codigo}: $error');
        errores++;
      }
    }

    for (final local in locales) {
      final remota = remotasPorId[local.identificador];
      if (remota == null) {
        try {
          await _subirFinca(local);
          subidos++;
        } catch (error) {
          debugPrint('Error subiendo finca ${local.codigo}: $error');
          errores++;
        }
        continue;
      }

      usadas.add(remota.docId);
      try {
        final accion = await _resolverConflictoFinca(local, remota);
        switch (accion) {
          case _AccionSync.subir:
            subidos++;
          case _AccionSync.descargar:
            descargados++;
          case _AccionSync.sinCambios:
            sinCambios++;
        }
      } catch (error) {
        debugPrint('Error resolviendo finca ${local.codigo}: $error');
        errores++;
      }
    }

    for (final remota in remotas.values) {
      if (usadas.contains(remota.docId)) continue;
      if (FincaService.instance.getFincaPorId(remota.fincaId) != null) continue;

      try {
        await _descargarFincaRemota(remota);
        descargados++;
      } catch (error) {
        debugPrint('Error descargando finca ${remota.codigo}: $error');
        errores++;
      }
    }

    return ResultadoSync(
      subidos: subidos,
      descargados: descargados,
      sinCambios: sinCambios,
      errores: errores,
    );
  }

  Future<_AccionSync> _resolverConflictoFinca(
    Finca local,
    _FincaRemota remota,
  ) async {
    final hashLocal = SyncUtils.hashFinca(
      codigo: local.codigo,
      canton: local.canton,
      prefijo: local.prefijo,
      estado: local.estado,
      nombreAgricultor: local.nombreAgricultor,
    );

    if (hashLocal == remota.hash) {
      await FincaService.instance.marcarSincronizada(local);
      await FincaService.instance.limpiarCodigoAnteriorPendiente(local);
      return _AccionSync.sinCambios;
    }

    final fechaLocal = local.actualizadoLocalEn;
    final fechaRemota = remota.fecha;
    final localGana = fechaRemota == null
        ? local.sincronizado != true
        : fechaLocal != null &&
              (fechaLocal.toUtc().isAfter(fechaRemota) ||
                  (fechaLocal.toUtc().isAtSameMomentAs(fechaRemota) &&
                      local.sincronizado != true));

    if (localGana) {
      await _subirFinca(local);
      await FincaService.instance.limpiarCodigoAnteriorPendiente(local);
      return _AccionSync.subir;
    }

    await FincaService.instance.aplicarDatosDesdeNube(
      fincaId: local.identificador,
      codigo: remota.codigo,
      canton: remota.canton,
      prefijo: remota.prefijo,
      nombreAgricultor: remota.nombreAgricultor,
      estado: remota.estado,
      actualizadoLocalEn: remota.fecha ?? DateTime.now(),
    );
    await FincaService.instance.limpiarCodigoAnteriorPendiente(local);
    return _AccionSync.descargar;
  }

  Future<void> _subirFinca(Finca finca) async {
    await FirestoreService.instance.guardarFinca(
      fincaId: finca.identificador,
      codigo: finca.codigo,
      canton: finca.canton,
      prefijo: finca.prefijo,
      estado: finca.estado,
      nombreAgricultor: finca.nombreAgricultor,
      actualizadoLocalEn: finca.actualizadoLocalEn ?? DateTime.now(),
    );
    await FincaService.instance.marcarSincronizada(finca);
  }

  Future<void> _descargarFincaRemota(_FincaRemota remota) async {
    await FincaService.instance.aplicarDatosDesdeNube(
      fincaId: remota.fincaId,
      codigo: remota.codigo,
      canton: remota.canton,
      prefijo: remota.prefijo,
      nombreAgricultor: remota.nombreAgricultor,
      estado: remota.estado,
      actualizadoLocalEn: remota.fecha ?? DateTime.now(),
    );

    final local = FincaService.instance.getFincaPorId(remota.fincaId);
    if (local != null) {
      await FincaService.instance.limpiarCodigoAnteriorPendiente(local);
    }
  }

  Future<_AccionSync> _resolverConflicto(
    FormResponse local,
    _DocumentoRemoto remoto,
    String templateBase,
    Finca finca,
  ) async {
    final hashLocal =
        local.hashRespuestas ?? SyncUtils.hashRespuestas(local.respuestas);

    if (hashLocal == remoto.hash) {
      await DatabaseService.instance.marcarSincronizado(
        local,
        hash: hashLocal,
        actualizadoEnNube: remoto.fecha,
      );
      return _AccionSync.sinCambios;
    }

    final fechaLocal = local.timestamp.toUtc();
    final fechaRemota = remoto.fecha;

    final localGana = fechaRemota == null
        ? local.sincronizado != true
        : fechaLocal.isAfter(fechaRemota) ||
              (fechaLocal.isAtSameMomentAs(fechaRemota) &&
                  local.sincronizado != true);

    if (localGana) {
      await _subirLocal(local, finca, templateBase);
      return _AccionSync.subir;
    }

    await _descargarRemoto(remoto);
    return _AccionSync.descargar;
  }

  Future<void> _subirLocal(
    FormResponse local,
    Finca finca,
    String templateBase,
  ) async {
    final titulo = await _tituloTemplate(templateBase);
    final hash =
        local.hashRespuestas ?? SyncUtils.hashRespuestas(local.respuestas);

    await FirestoreService.instance.guardarDocumento(
      fincaId: finca.identificador,
      templateId: templateBase,
      templateTitulo: titulo,
      respuestas: local.respuestas,
      actualizadoLocalEn: local.timestamp,
      hashRespuestas: hash,
    );

    local.fincaCodigo = finca.codigo;
    local.templateBaseId = templateBase;
    await DatabaseService.instance.marcarSincronizado(local, hash: hash);
  }

  Future<void> _descargarRemoto(_DocumentoRemoto remoto) async {
    final finca = await _asegurarFincaLocal(remoto.fincaId);
    if (finca == null) {
      throw StateError('No se encontró la finca ${remoto.fincaId}.');
    }

    await DatabaseService.instance.guardarRespuestaDesdeNube(
      fincaCodigo: finca.codigo,
      templateId: remoto.templateId,
      respuestas: remoto.respuestas,
      timestamp: remoto.fecha ?? DateTime.now(),
      hashRespuestas: remoto.hash,
      actualizadoEnNube: remoto.fecha,
    );
  }

  Future<Finca?> _asegurarFincaLocal(String fincaId) async {
    final local = FincaService.instance.getFincaPorId(fincaId);
    if (local != null) return local;

    try {
      final data = await FirestoreService.instance.obtenerFinca(fincaId);
      if (data == null) return null;

      final remota = _FincaRemota.desde(fincaId, data);
      await _descargarFincaRemota(remota);
      return FincaService.instance.getFincaPorId(fincaId);
    } catch (error) {
      debugPrint('No se pudo recuperar la finca $fincaId: $error');
      return null;
    }
  }

  Future<String> _tituloTemplate(String templateBase) async {
    final cacheado = _cacheTitulos[templateBase];
    if (cacheado != null) return cacheado;

    try {
      final template = await TemplateService.instance.loadTemplate(
        templateBase,
      );
      final titulo = template['titulo'] as String? ?? templateBase;
      _cacheTitulos[templateBase] = titulo;
      return titulo;
    } catch (_) {
      return templateBase;
    }
  }

  String? _fincaPorHash(String templateId) {
    final indice = templateId.lastIndexOf(':');
    if (indice == -1) return null;

    final hash = templateId.substring(indice + 1);
    for (final finca in FincaService.instance.getTodasLasFincas()) {
      if (finca.codigo.hashCode.toString() == hash) return finca.codigo;
    }
    return null;
  }

  bool _sinConexion(List<ConnectivityResult> estados) {
    return estados.isEmpty ||
        estados.every((estado) => estado == ConnectivityResult.none);
  }

  void dispose() {
    _suscripcionConectividad?.cancel();
    _suscripcionConectividad = null;
  }
}
