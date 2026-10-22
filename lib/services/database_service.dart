import 'package:hive_flutter/hive_flutter.dart';

import '../models/finca.dart';
import '../models/form_response.dart';
import 'sync_utils.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const String _formBoxName = 'form_responses';
  static const String _fincaBoxName = 'fincas';

  Future<void> initialize() async {
    await Hive.initFlutter();
    Hive.registerAdapter(FormResponseAdapter());
    Hive.registerAdapter(FincaAdapter());
    await Hive.openBox<FormResponse>(_formBoxName);
    await Hive.openBox<Finca>(_fincaBoxName);
  }

  Box<FormResponse> get _formBox => Hive.box<FormResponse>(_formBoxName);

  FormResponse? _buscarRegistro(String templateIdCompuesto) {
    for (final registro in _formBox.values) {
      if (registro.templateId == templateIdCompuesto) return registro;
    }
    return null;
  }

  Future<int> saveFormResponse({
    required String templateId,
    required Map<String, dynamic> respuestas,
    String? fincaCodigo,
  }) async {
    final box = _formBox;
    final compositeKey = fincaCodigo != null
        ? '$templateId:${fincaCodigo.hashCode}'
        : templateId;
    final ahora = DateTime.now();
    final hash = SyncUtils.hashRespuestas(respuestas);

    final existente = _buscarRegistro(compositeKey);

    if (existente != null) {
      // Actualizar el registro existente
      existente.respuestas = respuestas;
      existente.timestamp = ahora;
      existente.fincaCodigo = fincaCodigo ?? existente.fincaCodigo;
      existente.templateBaseId = templateId;
      existente.hashRespuestas = hash;
      existente.sincronizado = false;
      await existente.save();
      return box.values.toList().indexOf(existente);
    }

    // Crear nuevo registro
    final response = FormResponse()
      ..templateId = compositeKey
      ..respuestas = respuestas
      ..timestamp = ahora
      ..fincaCodigo = fincaCodigo
      ..templateBaseId = templateId
      ..hashRespuestas = hash
      ..sincronizado = false;

    return await box.add(response);
  }

  Future<List<FormResponse>> getAllResponses() async {
    return _formBox.values.toList();
  }

  /// Devuelve el registro local (con su estado de sincronización) para una
  /// finca y plantilla, o `null` si aún no existe.
  FormResponse? getRegistroFormResponse({
    required String fincaCodigo,
    required String templateId,
  }) {
    return _buscarRegistro('$templateId:${fincaCodigo.hashCode}');
  }

  Future<Map<String, dynamic>?> getFormResponseForFinca({
    required String fincaCodigo,
    required String templateId,
  }) async {
    final matches = _formBox.values
        .where((r) => r.templateId == '$templateId:${fincaCodigo.hashCode}')
        .toList();

    if (matches.isEmpty) return null;

    // Ordenar por timestamp descendente para obtener el más reciente
    matches.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return matches.first.respuestas;
  }

  /// Actualiza las claves locales de todas las respuestas de una finca
  /// cuando cambia su código.
  ///
  /// La clave de Hive es `templateId:hashCode(fincaCodigo)`, por lo que no
  /// basta con cambiar `fincaCodigo`: también hay que reconstruir la clave
  /// compuesta para que la búsqueda siga funcionando.
  Future<void> migrarCodigoFinca({
    required String codigoAnterior,
    required String codigoNuevo,
  }) async {
    if (codigoAnterior == codigoNuevo) return;

    for (final registro in _formBox.values.toList()) {
      final templateBase =
          registro.templateBaseId ??
          SyncUtils.templateBaseId(registro.templateId);
      final claveAnterior = '$templateBase:${codigoAnterior.hashCode}';
      final pertenece =
          registro.fincaCodigo == codigoAnterior ||
          (registro.fincaCodigo == null &&
              registro.templateId == claveAnterior);
      if (!pertenece) continue;

      registro.fincaCodigo = codigoNuevo;
      registro.templateBaseId = templateBase;
      registro.templateId = '$templateBase:${codigoNuevo.hashCode}';
      // El documento remoto aún puede estar con el código anterior; una
      // sincronización posterior lo migrará y marcará este registro.
      registro.sincronizado = false;
      await registro.save();
    }
  }

  /// Marca un registro local como sincronizado con la nube.
  Future<void> marcarSincronizado(
    FormResponse registro, {
    String? hash,
    DateTime? actualizadoEnNube,
  }) async {
    registro.sincronizado = true;
    if (hash != null) registro.hashRespuestas = hash;
    if (actualizadoEnNube != null) {
      registro.actualizadoEnNube = actualizadoEnNube;
    }
    await registro.save();
  }

  /// Inserta o actualiza en Hive una respuesta descargada de Firestore.
  Future<FormResponse> guardarRespuestaDesdeNube({
    required String fincaCodigo,
    required String templateId,
    required Map<String, dynamic> respuestas,
    required DateTime timestamp,
    required String hashRespuestas,
    DateTime? actualizadoEnNube,
  }) async {
    final compositeKey = '$templateId:${fincaCodigo.hashCode}';
    final existente = _buscarRegistro(compositeKey);

    if (existente != null) {
      existente.respuestas = respuestas;
      existente.timestamp = timestamp;
      existente.fincaCodigo = fincaCodigo;
      existente.templateBaseId = templateId;
      existente.hashRespuestas = hashRespuestas;
      existente.sincronizado = true;
      existente.actualizadoEnNube = actualizadoEnNube;
      await existente.save();
      return existente;
    }

    final response = FormResponse()
      ..templateId = compositeKey
      ..respuestas = respuestas
      ..timestamp = timestamp
      ..fincaCodigo = fincaCodigo
      ..templateBaseId = templateId
      ..hashRespuestas = hashRespuestas
      ..sincronizado = true
      ..actualizadoEnNube = actualizadoEnNube;

    await _formBox.add(response);
    return response;
  }

  Future<void> close() async {
    await Hive.close();
  }
}
