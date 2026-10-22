import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/finca.dart';
import 'database_service.dart';

class FincaService {
  FincaService._();
  static final FincaService instance = FincaService._();

  static const String _boxName = 'fincas';
  static const Uuid _uuid = Uuid();

  Box<Finca> get _box => Hive.box<Finca>(_boxName);

  Future<void> initialize() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<Finca>(_boxName);
    }
    await _migrarDatosExistentes();
  }

  /// Asigna un identificador estable y marcas de sincronización a las fincas
  /// creadas antes de que existiera la colección `fincas` en Firestore.
  Future<void> _migrarDatosExistentes() async {
    final ahora = DateTime.now();
    for (final finca in _box.values.toList()) {
      var cambio = false;

      if (finca.id == null || finca.id!.trim().isEmpty) {
        finca.id = _uuid.v4();
        cambio = true;
      }
      if (finca.actualizadoLocalEn == null) {
        finca.actualizadoLocalEn = ahora;
        cambio = true;
      }
      if (finca.sincronizado == null) {
        // Las fincas heredadas aún no existen en la colección de la nube.
        finca.sincronizado = false;
        cambio = true;
      }

      if (cambio) await finca.save();
    }
  }

  int? _numeroDeCodigo(String codigo) {
    final partes = codigo.split('-');
    if (partes.length < 2) return null;
    return int.tryParse(partes.last);
  }

  /// Mapa de cantones y sus prefijos disponibles
  static const Map<String, List<String>> cantonesPrefijos = {
    'Babahoyo': ['BAB', 'BABS', 'BABN'],
    'Naranjal': ['NJL', 'NJL1', 'NJL2'],
    'La Troncal': ['TCL', 'TCLA', 'TCLC'],
  };

  /// Obtiene los números disponibles para un prefijo específico.
  /// Incluye números liberados por fincas inactivas.
  ///
  /// [excluirCodigo] permite calcular la disponibilidad para una finca que
  /// ya existe, sin considerar su propio código como ocupado.
  List<int> getNumerosDisponibles(String prefijo, {String? excluirCodigo}) {
    final fincasConPrefijo = _box.values
        .where((f) => f.prefijo == prefijo && f.codigo != excluirCodigo)
        .toList();

    // Números en uso por fincas activas
    final numerosActivos = <int>{};
    // Números liberados (inactivos)
    final numerosLiberados = <int>{};
    int maxNumero = 0;

    for (final finca in fincasConPrefijo) {
      final numero = _numeroDeCodigo(finca.codigo);
      if (numero == null) continue;
      if (numero > maxNumero) maxNumero = numero;

      if (finca.estado == 'Activa') {
        numerosActivos.add(numero);
      } else {
        numerosLiberados.add(numero);
      }
    }

    final disponibles = <int>[];
    final vistos = <int>{};

    // Agregar números liberados primero (más primero para reutilizar)
    final liberadosOrdenados = numerosLiberados.toList()..sort();
    for (final n in liberadosOrdenados) {
      if (vistos.add(n)) disponibles.add(n);
    }

    // Agregar el siguiente número consecutivo después del máximo
    for (int i = 1; i <= maxNumero + 1; i++) {
      if (!numerosActivos.contains(i) && !numerosLiberados.contains(i)) {
        if (vistos.add(i)) disponibles.add(i);
      }
    }

    // Si no hay fincas, empezar desde 001
    if (disponibles.isEmpty) {
      disponibles.add(1);
    }

    // Al editar una finca, su código actual también debe poder seleccionarse.
    final numeroActual = excluirCodigo?.startsWith('$prefijo-') ?? false
        ? _numeroDeCodigo(excluirCodigo!)
        : null;
    if (numeroActual != null && !disponibles.contains(numeroActual)) {
      disponibles.insert(0, numeroActual);
    }

    return disponibles;
  }

  /// Números seleccionables al cambiar el código de una finca existente.
  ///
  /// Además de excluir el código actual, se descartan los códigos que ya
  /// pertenecen a otra finca (aunque esté inactiva) para no crear dos fincas
  /// con el mismo código.
  List<int> getNumerosDisponiblesParaFinca({
    required String prefijo,
    required String codigoActual,
  }) {
    final base = getNumerosDisponibles(prefijo, excluirCodigo: codigoActual);

    final ocupadosPorOtras = <int>{};
    for (final finca in _box.values) {
      if (finca.codigo == codigoActual || finca.prefijo != prefijo) continue;
      final numero = _numeroDeCodigo(finca.codigo);
      if (numero != null) ocupadosPorOtras.add(numero);
    }

    final resultado = base
        .where((numero) => !ocupadosPorOtras.contains(numero))
        .toList();

    // Si el código actual pertenece a este prefijo, mantenerlo disponible.
    final numeroActual = codigoActual.startsWith('$prefijo-')
        ? _numeroDeCodigo(codigoActual)
        : null;
    if (numeroActual != null && !resultado.contains(numeroActual)) {
      resultado.insert(0, numeroActual);
    }

    return resultado.isEmpty ? [1] : resultado;
  }

  /// Indica si un código puede usarse por la finca indicada.
  bool codigoDisponible(String codigo, {String? excluirFincaId}) {
    return !_box.values.any(
      (finca) =>
          finca.codigo == codigo &&
          (excluirFincaId == null || finca.identificador != excluirFincaId),
    );
  }

  /// Genera el siguiente código disponible para un prefijo
  String generarSiguienteCodigo(String prefijo) {
    final disponibles = getNumerosDisponibles(prefijo);
    final numero = disponibles.first;
    return '$prefijo-${numero.toString().padLeft(3, '0')}';
  }

  Future<Finca> registrarFinca({
    required String codigo,
    required String canton,
    required String prefijo,
    String? nombreAgricultor,
  }) async {
    final finca = Finca()
      ..id = _uuid.v4()
      ..codigo = codigo
      ..canton = canton
      ..prefijo = prefijo
      ..estado = 'Activa'
      ..nombreAgricultor = nombreAgricultor?.trim()
      ..actualizadoLocalEn = DateTime.now()
      ..sincronizado = false;

    await _box.add(finca);
    return finca;
  }

  List<Finca> getTodasLasFincas() {
    return _box.values.toList();
  }

  Finca? getFincaPorCodigo(String codigo) {
    try {
      return _box.values.firstWhere((f) => f.codigo == codigo);
    } catch (_) {
      return null;
    }
  }

  Finca? getFincaPorId(String fincaId) {
    try {
      return _box.values.firstWhere((f) => f.identificador == fincaId);
    } catch (_) {
      return null;
    }
  }

  Future<void> actualizarNombreAgricultor({
    required String codigo,
    required String nombreAgricultor,
  }) async {
    final finca = getFincaPorCodigo(codigo);
    if (finca == null) return;

    finca.nombreAgricultor = nombreAgricultor.trim();
    finca.actualizadoLocalEn = DateTime.now();
    finca.sincronizado = false;
    await finca.save();
  }

  Future<void> inactivarFinca(String codigo) async {
    final finca = getFincaPorCodigo(codigo);
    if (finca == null) return;

    finca.estado = 'Inactiva';
    finca.actualizadoLocalEn = DateTime.now();
    finca.sincronizado = false;
    await finca.save();
  }

  Future<void> activarFinca(String codigo) async {
    final finca = getFincaPorCodigo(codigo);
    if (finca == null) return;

    finca.estado = 'Activa';
    finca.actualizadoLocalEn = DateTime.now();
    finca.sincronizado = false;
    await finca.save();
  }

  /// Actualiza código, agricultor, cantón y estado desde el formulario de
  /// datos generales. Si el código cambia, migra las respuestas locales.
  Future<Finca> actualizarDatosGenerales({
    required String fincaId,
    required String codigo,
    required String canton,
    required String prefijo,
    required String nombreAgricultor,
    required String estado,
  }) async {
    final finca = getFincaPorId(fincaId);
    if (finca == null) {
      throw StateError('La finca ya no existe localmente.');
    }
    if (!codigoDisponible(codigo, excluirFincaId: fincaId)) {
      throw StateError('El código $codigo ya está asignado a otra finca.');
    }

    final codigoAnterior = finca.codigo;
    finca.codigo = codigo;
    finca.canton = canton;
    finca.prefijo = prefijo;
    finca.nombreAgricultor = nombreAgricultor.trim();
    finca.estado = estado;
    finca.actualizadoLocalEn = DateTime.now();
    finca.sincronizado = false;
    if (codigoAnterior != codigo) {
      finca.codigoAnteriorPendiente = codigoAnterior;
    }
    await finca.save();

    if (codigoAnterior != codigo) {
      await DatabaseService.instance.migrarCodigoFinca(
        codigoAnterior: codigoAnterior,
        codigoNuevo: codigo,
      );
    }

    return finca;
  }

  /// Aplica en Hive los datos generales descargados de la nube.
  Future<Finca> aplicarDatosDesdeNube({
    required String fincaId,
    required String codigo,
    required String canton,
    required String prefijo,
    required String? nombreAgricultor,
    required String estado,
    required DateTime actualizadoLocalEn,
  }) async {
    final finca = getFincaPorId(fincaId);
    if (finca == null) {
      final nueva = Finca()
        ..id = fincaId
        ..codigo = codigo
        ..canton = canton
        ..prefijo = prefijo
        ..estado = estado
        ..nombreAgricultor = nombreAgricultor?.trim()
        ..actualizadoLocalEn = actualizadoLocalEn
        ..sincronizado = true;
      await _box.add(nueva);
      return nueva;
    }

    final codigoAnterior = finca.codigo;
    finca.codigo = codigo;
    finca.canton = canton;
    finca.prefijo = prefijo;
    finca.estado = estado;
    finca.nombreAgricultor = nombreAgricultor?.trim();
    finca.actualizadoLocalEn = actualizadoLocalEn;
    finca.sincronizado = true;
    if (codigoAnterior != codigo) {
      finca.codigoAnteriorPendiente = codigoAnterior;
    }
    await finca.save();

    if (codigoAnterior != codigo) {
      await DatabaseService.instance.migrarCodigoFinca(
        codigoAnterior: codigoAnterior,
        codigoNuevo: codigo,
      );
    }

    return finca;
  }

  /// Vincula una finca local con el ID estable que ya existe en la nube.
  Future<void> adoptarIdRemoto(Finca finca, String fincaId) async {
    finca.id = fincaId;
    finca.sincronizado = false;
    await finca.save();
  }

  /// Marca los datos generales como sincronizados sin modificar la fecha de
  /// edición local.
  Future<void> marcarSincronizada(Finca finca) async {
    finca.sincronizado = true;
    await finca.save();
  }

  /// Indica que ya no quedan formularios remotos con el código anterior.
  Future<void> limpiarCodigoAnteriorPendiente(Finca finca) async {
    if (finca.codigoAnteriorPendiente == null) return;
    finca.codigoAnteriorPendiente = null;
    await finca.save();
  }
}
