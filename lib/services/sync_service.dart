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
  final String fincaCodigo;
  final String templateId;
  final String templateTitulo;
  final String nombreAgricultor;
  final String canton;
  final Map<String, dynamic> respuestas;
  final String hash;
  final DateTime? fecha;

  _DocumentoRemoto({
    required this.docId,
    required this.fincaCodigo,
    required this.templateId,
    required this.templateTitulo,
    required this.nombreAgricultor,
    required this.canton,
    required this.respuestas,
    required this.hash,
    required this.fecha,
  });

  factory _DocumentoRemoto.desde(String docId, Map<String, dynamic> data) {
    final respuestas = Map<String, dynamic>.from(data['respuestas'] as Map);
    final hash = data['hashRespuestas'];
    return _DocumentoRemoto(
      docId: docId,
      fincaCodigo: data['fincaCodigo'] as String,
      templateId: data['templateId'] as String,
      templateTitulo: data['templateTitulo'] as String? ?? '',
      nombreAgricultor: data['nombreAgricultor'] as String? ?? '',
      canton: data['canton'] as String? ?? '',
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
    final hash = SyncUtils.hashRespuestas(respuestas);

    try {
      await FirestoreService.instance.guardarDocumento(
        fincaCodigo: fincaCodigo,
        templateId: templateId,
        templateTitulo: templateTitulo,
        respuestas: respuestas,
        actualizadoLocalEn: timestamp,
        hashRespuestas: hash,
        fincaId: finca?.identificador,
        nombreAgricultor: finca?.nombreAgricultor,
        canton: finca?.canton,
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
  ///
  /// [codigoAnterior] permite migrar los formularios remotos cuando el código
  /// cambió localmente. Si no se indica, se detecta comparando con el
  /// documento de la finca que ya esté en la nube.
  Future<ResultadoSync> sincronizarFinca({
    required String fincaId,
    String? codigoAnterior,
  }) async {
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
      final remotaData = await FirestoreService.instance.obtenerFinca(fincaId);
      final remota = remotaData == null
          ? null
          : _FincaRemota.desde(fincaId, remotaData);

      // Migrar primero los formularios remotos permite reintentar con
      // seguridad si la escritura de la finca fallara después.
      final codigosAnteriores = <String>{
        if (finca.codigoAnteriorPendiente != null &&
            finca.codigoAnteriorPendiente!.isNotEmpty)
          finca.codigoAnteriorPendiente!,
        if (codigoAnterior != null && codigoAnterior.isNotEmpty) codigoAnterior,
        if (remota != null && remota.codigo.isNotEmpty) remota.codigo,
      };
      for (final anterior in codigosAnteriores) {
        await _migrarFormulariosSiCambioCodigo(
          codigoAnterior: anterior,
          finca: finca,
        );
      }

      await FirestoreService.instance.guardarFinca(
        fincaId: finca.identificador,
        codigo: finca.codigo,
        canton: finca.canton,
        prefijo: finca.prefijo,
        estado: finca.estado,
        nombreAgricultor: finca.nombreAgricultor,
        actualizadoLocalEn: finca.actualizadoLocalEn ?? DateTime.now(),
      );

      await FirestoreService.instance.actualizarMetadatosFormularios(
        fincaCodigo: finca.codigo,
        fincaId: finca.identificador,
        nombreAgricultor: finca.nombreAgricultor,
        canton: finca.canton,
      );

      await FincaService.instance.limpiarCodigoAnteriorPendiente(finca);
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

      // Primero se reconcilian las fincas. Si alguna cambió de código, esta
      // fase migra también sus documentos de formularios en la nube.
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
      final resultadoFincas = await _sincronizarFincas(remotasFincas);
      subidos += resultadoFincas.subidos;
      descargados += resultadoFincas.descargados;
      sinCambios += resultadoFincas.sinCambios;
      errores += resultadoFincas.errores;

      final remotosData = await FirestoreService.instance.obtenerTodos();
      final remotos = <String, _DocumentoRemoto>{
        for (final entrada in remotosData.entries)
          entrada.key: _DocumentoRemoto.desde(entrada.key, entrada.value),
      };
      final locales = await DatabaseService.instance.getAllResponses();

      final remotosUsados = <String>{};
      final remotosPorClaveCompuesta = <String, String>{
        for (final remoto in remotos.values)
          '${remoto.templateId}:${remoto.fincaCodigo.hashCode}': remoto.docId,
      };

      for (final local in locales) {
        final templateBase =
            local.templateBaseId ?? SyncUtils.templateBaseId(local.templateId);
        final fincaCodigo =
            local.fincaCodigo ?? _fincaPorHash(local.templateId);

        final docIdDeterminista = fincaCodigo != null
            ? FirestoreService.docIdPara(fincaCodigo, templateBase)
            : null;
        // Preferir el ID determinista; si el documento remoto fue creado con
        // otro ID, se localiza por la clave compuesta para no duplicarlo.
        final docIdRemoto =
            docIdDeterminista != null && remotos.containsKey(docIdDeterminista)
            ? docIdDeterminista
            : remotosPorClaveCompuesta[local.templateId];

        final remoto = docIdRemoto != null ? remotos[docIdRemoto] : null;

        // Completar metadatos faltantes en registros heredados.
        if (local.fincaCodigo == null && fincaCodigo != null) {
          local.fincaCodigo = fincaCodigo;
          local.templateBaseId = templateBase;
          local.hashRespuestas ??= SyncUtils.hashRespuestas(local.respuestas);
          await local.save();
        } else if (local.templateBaseId == null ||
            local.hashRespuestas == null) {
          local.templateBaseId = templateBase;
          local.hashRespuestas ??= SyncUtils.hashRespuestas(local.respuestas);
          await local.save();
        }

        if (remoto == null) {
          if (fincaCodigo == null) {
            debugPrint(
              'No se pudo determinar la finca del registro ${local.templateId}',
            );
            errores++;
            continue;
          }

          try {
            await _subirLocal(local, fincaCodigo, templateBase);
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
            fincaCodigo,
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
    // Primero se intenta completar cualquier migración pendiente de código.
    // Así, aunque el contenido de la finca ya coincida, los formularios
    // remotos no quedan huérfanos si una sincronización anterior falló.
    final pendiente = local.codigoAnteriorPendiente;
    if (pendiente != null &&
        pendiente.isNotEmpty &&
        pendiente != local.codigo) {
      await _migrarFormulariosSiCambioCodigo(
        codigoAnterior: pendiente,
        finca: local,
      );
      await FincaService.instance.limpiarCodigoAnteriorPendiente(local);
    }

    final hashLocal = SyncUtils.hashFinca(
      codigo: local.codigo,
      canton: local.canton,
      prefijo: local.prefijo,
      estado: local.estado,
      nombreAgricultor: local.nombreAgricultor,
    );

    if (hashLocal == remota.hash) {
      await FincaService.instance.marcarSincronizada(local);
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
      final codigoAnteriorRemoto = remota.codigo;
      final nombreRemoto = remota.nombreAgricultor;
      final cantonRemoto = remota.canton;

      if (codigoAnteriorRemoto != local.codigo) {
        await _migrarFormulariosSiCambioCodigo(
          codigoAnterior: codigoAnteriorRemoto,
          finca: local,
        );
      }
      await _subirFinca(local);
      if (codigoAnteriorRemoto == local.codigo &&
          (nombreRemoto != (local.nombreAgricultor?.trim() ?? '') ||
              cantonRemoto != local.canton)) {
        await FirestoreService.instance.actualizarMetadatosFormularios(
          fincaCodigo: local.codigo,
          fincaId: local.identificador,
          nombreAgricultor: local.nombreAgricultor,
          canton: local.canton,
        );
      }
      await FincaService.instance.limpiarCodigoAnteriorPendiente(local);
      return _AccionSync.subir;
    }

    final codigoAnteriorLocal = local.codigo;
    final nombreRemoto = remota.nombreAgricultor;
    final cantonRemoto = remota.canton;

    await FincaService.instance.aplicarDatosDesdeNube(
      fincaId: local.identificador,
      codigo: remota.codigo,
      canton: remota.canton,
      prefijo: remota.prefijo,
      nombreAgricultor: remota.nombreAgricultor,
      estado: remota.estado,
      actualizadoLocalEn: remota.fecha ?? DateTime.now(),
    );

    if (codigoAnteriorLocal != remota.codigo) {
      await _migrarFormulariosSiCambioCodigo(
        codigoAnterior: codigoAnteriorLocal,
        finca: local,
      );
    } else if (nombreRemoto != (local.nombreAgricultor?.trim() ?? '') ||
        cantonRemoto != local.canton) {
      await FirestoreService.instance.actualizarMetadatosFormularios(
        fincaCodigo: local.codigo,
        fincaId: local.identificador,
        nombreAgricultor: local.nombreAgricultor,
        canton: local.canton,
      );
    }
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

  Future<void> _migrarFormulariosSiCambioCodigo({
    required String codigoAnterior,
    required Finca finca,
  }) async {
    if (codigoAnterior.isEmpty || codigoAnterior == finca.codigo) return;

    await FirestoreService.instance.migrarDocumentosFormulario(
      codigoAnterior: codigoAnterior,
      codigoNuevo: finca.codigo,
      fincaId: finca.identificador,
      nombreAgricultor: finca.nombreAgricultor,
      canton: finca.canton,
    );
  }

  Future<_AccionSync> _resolverConflicto(
    FormResponse local,
    _DocumentoRemoto remoto,
    String templateBase,
    String? fincaCodigo,
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
      await _subirLocal(local, fincaCodigo ?? remoto.fincaCodigo, templateBase);
      return _AccionSync.subir;
    }

    await _descargarRemoto(remoto);
    return _AccionSync.descargar;
  }

  Future<void> _subirLocal(
    FormResponse local,
    String fincaCodigo,
    String templateBase,
  ) async {
    final finca = FincaService.instance.getFincaPorCodigo(fincaCodigo);
    final titulo = await _tituloTemplate(templateBase);
    final hash =
        local.hashRespuestas ?? SyncUtils.hashRespuestas(local.respuestas);

    await FirestoreService.instance.guardarDocumento(
      fincaCodigo: fincaCodigo,
      templateId: templateBase,
      templateTitulo: titulo,
      respuestas: local.respuestas,
      actualizadoLocalEn: local.timestamp,
      hashRespuestas: hash,
      fincaId: finca?.identificador,
      nombreAgricultor: finca?.nombreAgricultor,
      canton: finca?.canton,
    );

    local.fincaCodigo = fincaCodigo;
    local.templateBaseId = templateBase;
    await DatabaseService.instance.marcarSincronizado(local, hash: hash);
  }

  Future<void> _descargarRemoto(_DocumentoRemoto remoto) async {
    await _asegurarFincaLocal(remoto);

    await DatabaseService.instance.guardarRespuestaDesdeNube(
      fincaCodigo: remoto.fincaCodigo,
      templateId: remoto.templateId,
      respuestas: remoto.respuestas,
      timestamp: remoto.fecha ?? DateTime.now(),
      hashRespuestas: remoto.hash,
      actualizadoEnNube: remoto.fecha,
    );
  }

  Future<void> _asegurarFincaLocal(_DocumentoRemoto remoto) async {
    if (FincaService.instance.getFincaPorCodigo(remoto.fincaCodigo) != null) {
      return;
    }

    final partes = remoto.fincaCodigo.split('-');
    final prefijo = partes.length > 1 ? partes.first : 'REM';
    final canton = remoto.canton.isNotEmpty ? remoto.canton : 'Sin cantón';

    await FincaService.instance.registrarFinca(
      codigo: remoto.fincaCodigo,
      canton: canton,
      prefijo: prefijo,
      nombreAgricultor: remoto.nombreAgricultor.isNotEmpty
          ? remoto.nombreAgricultor
          : null,
    );

    debugPrint(
      'Finca ${remoto.fincaCodigo} creada desde Firestore (no existía localmente).',
    );
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
