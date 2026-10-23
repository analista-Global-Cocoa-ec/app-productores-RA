import 'dart:async';

import 'package:flutter/material.dart';

import '../models/finca.dart';
import '../services/database_service.dart';
import '../services/finca_service.dart';
import '../services/form_completion.dart';
import '../services/sync_service.dart';
import '../services/template_service.dart';
import 'finca_datos_generales_screen.dart';
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
  late Finca _finca;
  bool _isLoading = true;
  bool _isSyncing = false;
  StreamSubscription<ResultadoSync>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _finca =
        FincaService.instance.getFincaPorId(widget.finca.identificador) ??
        widget.finca;
    _loadData();

    // Refrescar los estados de los formularios cuando una sincronización
    // automática descargue cambios desde la nube.
    _syncSubscription = SyncService.instance.resultados.listen((resultado) {
      if (!mounted || resultado.enCurso) return;
      _loadData();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final fincaActual =
        FincaService.instance.getFincaPorId(_finca.identificador) ?? _finca;
    final formularios = _getFormulariosDisponibles();
    final respuestas = <String, Map<String, dynamic>?>{};
    final templates = <String, Map<String, dynamic>?>{};

    for (final formulario in formularios) {
      final id = formulario['id'] as String;

      // Cargar respuestas guardadas
      final resp = await DatabaseService.instance.getFormResponseForFinca(
        fincaCodigo: fincaActual.codigo,
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
        _finca = fincaActual;
        _respuestasPorFormulario = respuestas;
        _templates = templates;
        _isLoading = false;
      });
    }
  }

  Future<void> _sincronizarAhora() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    final resultado = await SyncService.instance.sincronizarTodo();

    if (!mounted) return;

    // Recargar para mostrar cambios descargados desde la nube.
    await _loadData();

    if (!mounted) return;
    setState(() => _isSyncing = false);

    final color = !resultado.disponible || resultado.errores > 0
        ? Colors.orange
        : Colors.green;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resultado.resumen),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    return FormCompletion.estado(
      template: _templates[templateId],
      respuestas: _respuestasPorFormulario[templateId],
    );
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
          title: Text('Finca ${_finca.codigo}'),
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
        title: Text('Finca ${_finca.codigo}'),
        centerTitle: true,
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.cloud_sync_outlined),
              tooltip: 'Sincronizar con la nube',
              onPressed: _sincronizarAhora,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: formularios.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              final color = Theme.of(context).colorScheme.primary;
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
                    child: Icon(Icons.badge_outlined, color: color),
                  ),
                  title: const Text(
                    'Datos generales',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Código ${_finca.codigo} · ${_finca.estado}',
                    style: TextStyle(color: color),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            FincaDatosGeneralesScreen(finca: _finca),
                      ),
                    );
                    await _loadData();
                  },
                ),
              );
            }

            final formulario = formularios[index - 1];
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
                        fincaId: _finca.identificador,
                        fincaCodigo: _finca.codigo,
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
