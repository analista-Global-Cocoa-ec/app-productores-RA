import 'package:hive_flutter/hive_flutter.dart';

import '../models/finca.dart';

class FincaService {
  FincaService._();
  static final FincaService instance = FincaService._();

  static const String _boxName = 'fincas';

  Box<Finca> get _box => Hive.box<Finca>(_boxName);

  Future<void> initialize() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<Finca>(_boxName);
    }
  }

  /// Mapa de cantones y sus prefijos disponibles
  static const Map<String, List<String>> cantonesPrefijos = {
    'Babahoyo': ['BAB', 'BABS', 'BABN'],
    'Naranjal': ['NJL', 'NJL1', 'NJL2'],
    'La Troncal': ['TCL', 'TCLA', 'TCLC'],
  };

  /// Obtiene los números disponibles para un prefijo específico.
  /// Incluye números liberados por fincas inactivas.
  List<int> getNumerosDisponibles(String prefijo) {
    final todasLasFincas = _box.values.toList();
    final fincasConPrefijo = todasLasFincas.where((f) => f.prefijo == prefijo).toList();

    // Números en uso por fincas activas
    final numerosActivos = <int>{};
    // Números liberados (inactivos)
    final numerosLiberados = <int>{};
    int maxNumero = 0;

    for (final finca in fincasConPrefijo) {
      final numero = int.parse(finca.codigo.split('-').last);
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

    return disponibles;
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
  }) async {
    final finca = Finca()
      ..codigo = codigo
      ..canton = canton
      ..prefijo = prefijo
      ..estado = 'Activa';

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

  Future<void> inactivarFinca(String codigo) async {
    final finca = getFincaPorCodigo(codigo);
    if (finca != null) {
      finca.estado = 'Inactiva';
      await finca.save();
    }
  }

  Future<void> activarFinca(String codigo) async {
    final finca = getFincaPorCodigo(codigo);
    if (finca != null) {
      finca.estado = 'Activa';
      await finca.save();
    }
  }
}
