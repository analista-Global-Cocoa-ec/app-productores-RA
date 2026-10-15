import '../templates/ficha_agricultor.dart';
import '../templates/registro_agroquimicos.dart';
import '../templates/registro_cosecha.dart';
import '../templates/registro_fertilizantes.dart';

class TemplateService {
  TemplateService._();
  static final TemplateService instance = TemplateService._();

  /// Carga una plantilla de formulario por su ID.
  /// Simula latencia de red para emular una respuesta de servidor.
  Future<Map<String, dynamic>> loadTemplate(String templateId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final template = _templates[templateId];
    if (template == null) {
      throw ArgumentError('Plantilla no encontrada: $templateId');
    }
    return Map<String, dynamic>.from(template);
  }

  static final Map<String, Map<String, dynamic>> _templates = {
    'ficha_agricultor': fichaAgricultorTemplate,
    'registro_cosecha': registroCosechaTemplate,
    'registro_agroquimicos': registroAgroquimicosTemplate,
    'registro_fertilizantes': registroFertilizantesTemplate,
  };
}
