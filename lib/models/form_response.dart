import 'package:hive/hive.dart';

part 'form_response.g.dart';

@HiveType(typeId: 0)
class FormResponse extends HiveObject {
  @HiveField(0)
  late String templateId;

  @HiveField(1)
  late Map<String, dynamic> respuestas;

  @HiveField(2)
  late DateTime timestamp;
}
