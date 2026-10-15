import 'package:hive_flutter/hive_flutter.dart';

import '../models/form_response.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const String _boxName = 'form_responses';

  Future<void> initialize() async {
    await Hive.initFlutter();
    Hive.registerAdapter(FormResponseAdapter());
    await Hive.openBox<FormResponse>(_boxName);
  }

  Future<int> saveFormResponse({
    required String templateId,
    required Map<String, dynamic> respuestas,
  }) async {
    final box = Hive.box<FormResponse>(_boxName);
    final response = FormResponse()
      ..templateId = templateId
      ..respuestas = respuestas
      ..timestamp = DateTime.now();

    return await box.add(response);
  }

  Future<List<FormResponse>> getAllResponses() async {
    final box = Hive.box<FormResponse>(_boxName);
    return box.values.toList();
  }

  Future<void> close() async {
    await Hive.close();
  }
}
