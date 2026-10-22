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

  /// Código de la finca a la que pertenece la respuesta (ej. NJL-001).
  @HiveField(3)
  String? fincaCodigo;

  /// ID base de la plantilla (ej. registro_cosecha), sin la clave compuesta.
  @HiveField(4)
  String? templateBaseId;

  /// Indica si el contenido actual ya fue aceptado por Firestore.
  /// Es nulo en registros creados antes de habilitar la sincronización.
  @HiveField(5)
  bool? sincronizado;

  /// Hash del contenido de [respuestas] para detectar cambios sin escribir.
  @HiveField(6)
  String? hashRespuestas;

  /// Última marca de tiempo conocida de la nube (auditoría).
  @HiveField(7)
  DateTime? actualizadoEnNube;
}
