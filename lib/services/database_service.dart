import 'package:hive_flutter/hive_flutter.dart';

import '../models/finca.dart';
import '../models/form_response.dart';

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

  Future<int> saveFormResponse({
    required String templateId,
    required Map<String, dynamic> respuestas,
    String? fincaCodigo,
  }) async {
    final box = Hive.box<FormResponse>(_formBoxName);
    final compositeKey = fincaCodigo != null ? '$templateId:${fincaCodigo.hashCode}' : templateId;

    // Buscar si ya existe un registro para esta finca + template
    FormResponse? existente;
    try {
      existente = box.values.firstWhere(
        (r) => r.templateId == compositeKey,
      );
    } catch (_) {
      existente = null;
    }

    if (existente != null) {
      // Actualizar el registro existente
      existente.respuestas = respuestas;
      existente.timestamp = DateTime.now();
      await existente.save();
      return box.values.toList().indexOf(existente);
    } else {
      // Crear nuevo registro
      final response = FormResponse()
        ..templateId = compositeKey
        ..respuestas = respuestas
        ..timestamp = DateTime.now();

      return await box.add(response);
    }
  }

  Future<List<FormResponse>> getAllResponses() async {
    final box = Hive.box<FormResponse>(_formBoxName);
    return box.values.toList();
  }

  Future<Map<String, dynamic>?> getFormResponseForFinca({
    required String fincaCodigo,
    required String templateId,
  }) async {
    final box = Hive.box<FormResponse>(_formBoxName);
    final compositeKey = '$templateId:${fincaCodigo.hashCode}';

    final matches = box.values.where(
      (r) => r.templateId == compositeKey,
    ).toList();

    if (matches.isEmpty) return null;

    // Ordenar por timestamp descendente para obtener el más reciente
    matches.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return matches.first.respuestas;
  }

  Future<void> close() async {
    await Hive.close();
  }
}
