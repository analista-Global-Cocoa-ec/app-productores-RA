import 'package:flutter/material.dart';

import '../models/finca.dart';
import '../services/database_service.dart';
import '../services/template_service.dart';
import 'form_screen.dart';

/// Pantalla que muestra los formularios disponibles para una finca
/// con alertas de color según el estado de completitud.
class FincaFormulariosScreen extends StatefulWidget {
  final Finca finca;

  const FincaFormulariosScreen({super.key, required this.finca});

  @override
  State<FincaFormulariosScreen> createState() => _FincaFormulariosScreenState();
}

class _FincaFormulariosScreenState extends State<FincaFormulariosScreen> {
  Map<String, Map<String, dynamic>?> _respuestasPorFormulario = {};
  Map<String, Map<String, dynamic>?> _templates = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final formularios = _getFormulariosDisponibles();
    final respuestas = <String, Map<String, dynamic>?>{};
    final templates = <String, Map<String, dynamic>?>{};

    for (final formulario in formularios) {
      final id = formulario['id'] as String;

      // Cargar respuestas guardadas
      final resp = await DatabaseService.instance.getFormResponseForFinca(
        fincaCodigo: widget.finca.codigo,
        templateId: id,
      );
      respuestas[id] = resp;

      // Cargar template para conocer los campos
      try {
        final template = await TemplateService.instance.loadTemplate(id);
        templates[id] = template;
      } catch (_) {
        templates[id] = null;
      }
    }

    if (mounted) {
      setState(() {
        _respuestasPorFormulario = respuestas;
        _templates = templates;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFormulariosDisponibles() {
    return [
      {
        'id': 'registro_cosecha',
        'nombre': 'Registro manual de cosecha',
        'icon': Icons.agriculture_outlined,
      },
      {
        'id': 'registro_agroquimicos',
        'nombre': 'Registro de agroquimicos',
        'icon': Icons.science_outlined,
      },
      {
        'id': 'registro_fertilizantes',
        'nombre': 'Registro de fertilizantes',
        'icon': Icons.eco_outlined,
      },
      {
        'id': 'ficha_agricultor',
        'nombre': 'Ficha del agricultor',
        'icon': Icons.person_outline,
      },
    ];
  }

  /// Calcula el estado de completitud de un formulario
  /// Retorna: 'empty', 'partial', o 'complete'
  String _getEstadoFormulario(String templateId) {
    final respuestas = _respuestasPorFormulario[templateId];
    final template = _templates[templateId];

    if (respuestas == null || template == null) return 'empty';

    final campos =
        (template['campos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (campos.isEmpty) return 'empty';

    int camposLlenos = 0;
    int totalCampos = 0;
    for (final campo in campos) {
      // Un campo puede guardar su valor en varias claves (número + unidad,
      // mes + año).
      final claves = <String>[campo['key'] as String];
      for (final extra in ['unitKey', 'anioKey']) {
        final claveExtra = campo[extra];
        if (claveExtra is String && claveExtra.isNotEmpty) {
          claves.add(claveExtra);
        }
      }

      for (final clave in claves) {
        totalCampos++;
        final valor = respuestas[clave];
        if (valor != null && valor.toString().isNotEmpty) {
          camposLlenos++;
        }
      }
    }

    if (totalCampos == 0) return 'empty';
    if (camposLlenos == 0) return 'empty';
    if (camposLlenos == totalCampos) return 'complete';
    return 'partial';
  }

  Color _getColorForEstado(String estado) {
    switch (estado) {
      case 'empty':
        return Colors.red;
      case 'partial':
        return Colors.amber;
      case 'complete':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForEstado(String estado) {
    switch (estado) {
      case 'empty':
        return Icons.error_outline;
      case 'partial':
        return Icons.warning_amber_outlined;
      case 'complete':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Finca ${widget.finca.codigo}'),
          centerTitle: true,
        ),
        body: const SafeArea(
          top: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final formularios = _getFormulariosDisponibles();

    return Scaffold(
      appBar: AppBar(
        title: Text('Finca ${widget.finca.codigo}'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: formularios.length,
          itemBuilder: (context, index) {
            final formulario = formularios[index];
            final estado = _getEstadoFormulario(formulario['id'] as String);
            final color = _getColorForEstado(estado);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: color.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(_getIconForEstado(estado), color: color),
                ),
                title: Text(
                  formulario['nombre'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  estado == 'empty'
                      ? 'Formulario vacío'
                      : estado == 'partial'
                      ? 'Formulario parcialmente completado'
                      : 'Formulario completo',
                  style: TextStyle(color: color),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FormScreen(
                        fincaCodigo: widget.finca.codigo,
                        templateId: formulario['id'] as String,
                      ),
                    ),
                  );
                  // Recargar datos al volver
                  _loadData();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
