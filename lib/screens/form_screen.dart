import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:intl/intl.dart';

import '../models/finca.dart';
import '../services/database_service.dart';
import '../services/finca_service.dart';
import '../services/sync_service.dart';
import '../services/template_service.dart';
import '../widgets/firma_pad.dart';
import '../widgets/form_field_label.dart';

class FormScreen extends StatefulWidget {
  final String? fincaId;
  final String? fincaCodigo;
  final String? templateId;

  const FormScreen({
    super.key,
    this.fincaId,
    this.fincaCodigo,
    this.templateId,
  });

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  Map<String, dynamic>? _template;
  Map<String, dynamic>? _respuestasGuardadas;
  int _resetVersion = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  /// Finca actual resuelta por ID estable. Si el código cambió mientras el
  /// formulario estaba abierto, se usa el código nuevo al guardar.
  Finca? get _fincaActual {
    final fincaId = widget.fincaId;
    if (fincaId != null) {
      final finca = FincaService.instance.getFincaPorId(fincaId);
      if (finca != null) return finca;
    }
    final codigo = widget.fincaCodigo;
    return codigo == null
        ? null
        : FincaService.instance.getFincaPorCodigo(codigo);
  }

  String? get _codigoFincaActual {
    final finca = _fincaActual;
    if (finca != null) return finca.codigo;
    return widget.fincaCodigo;
  }

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    try {
      final templateId = widget.templateId ?? 'ficha_agricultor';
      final template = await TemplateService.instance.loadTemplate(templateId);

      Map<String, dynamic>? guardadas;
      final codigoFinca = _codigoFincaActual;
      if (codigoFinca != null) {
        guardadas = await DatabaseService.instance.getFormResponseForFinca(
          fincaCodigo: codigoFinca,
          templateId: templateId,
        );
      }

      if (mounted) {
        setState(() {
          _template = template;
          _respuestasGuardadas = guardadas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando plantilla: $e')));
      }
    }
  }

  /// Resuelve el valor de los campos de tipo `fixed` a partir de la finca.
  String _valorFijo(Map<String, dynamic> field) {
    final finca = _fincaActual;
    switch (field['source']) {
      case 'finca_codigo':
        return finca?.codigo ?? widget.fincaCodigo ?? '';
      case 'finca_nombre_agricultor':
        return finca?.nombreAgricultor?.trim() ?? '';
      default:
        return '';
    }
  }

  String? Function(dynamic)? _validatorFor(Map<String, dynamic> field) {
    final type = field['type'] as String;
    final isRequired = field['required'] as bool? ?? false;
    final positive = field['positive'] == true;

    return (dynamic value) {
      final texto = value?.toString().trim() ?? '';
      if (texto.isEmpty) {
        return isRequired ? 'Campo obligatorio' : null;
      }
      if (type == 'number') {
        final numero = double.tryParse(texto.replaceAll(',', '.'));
        if (numero == null) return 'Ingrese un número válido';
        if (positive && numero <= 0) return 'Ingrese un número mayor a 0';
      }
      return null;
    };
  }

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete los campos obligatorios antes de guardar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final responses = Map<String, dynamic>.from(_formKey.currentState!.value);

    // Los campos fijos no se editan, pero se guardan con su valor actual.
    final campos = (_template!['campos'] as List).cast<Map<String, dynamic>>();
    for (final campo in campos) {
      if (campo['type'] == 'fixed') {
        responses[campo['key'] as String] = _valorFijo(campo);
      }
    }

    responses.forEach((key, value) {
      if (value is DateTime) {
        responses[key] = value.toIso8601String();
      }
    });

    final templateId = _template!['id'] as String;
    final marcaLocal = DateTime.now();
    final codigoFinca = _codigoFincaActual;
    await DatabaseService.instance.saveFormResponse(
      templateId: templateId,
      respuestas: responses,
      fincaCodigo: codigoFinca,
    );

    if (!mounted) return;

    setState(() => _isSaving = false);
    setState(() {
      _respuestasGuardadas = responses;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Formulario guardado localmente'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );

    if (codigoFinca != null) {
      unawaited(_sincronizarEnNube(responses, marcaLocal, codigoFinca));
    }
  }

  /// Intenta subir el formulario recién guardado. No bloquea el guardado local.
  Future<void> _sincronizarEnNube(
    Map<String, dynamic> respuestas,
    DateTime timestamp,
    String fincaCodigo,
  ) async {
    final resultado = await SyncService.instance.sincronizarFormulario(
      fincaCodigo: fincaCodigo,
      templateId: _template!['id'] as String,
      templateTitulo: _template!['titulo'] as String? ?? '',
      respuestas: respuestas,
      timestamp: timestamp,
    );

    if (!mounted) return;

    final String mensaje;
    final Color color;
    if (!resultado.disponible) {
      mensaje =
          'Guardado localmente. La nube no está disponible en esta plataforma.';
      color = Colors.orange;
    } else if (resultado.errores > 0) {
      mensaje = 'Guardado localmente. No se pudo subir ahora; se reintentará al recuperar la conexión.';
      color = Colors.orange;
    } else {
      mensaje = 'Formulario sincronizado en la nube';
      color = Colors.green;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmarLimpiar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpiar formulario'),
        content: const Text(
          'Se borrarán todos los datos ingresados en este formulario. '
          'Los datos guardados previamente no se modifican.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    _formKey.currentState?.reset();
    setState(() => _resetVersion++);
  }

  InputDecoration _decoration({String? hint, String? suffixText}) {
    return InputDecoration(
      hintText: hint,
      suffixText: suffixText,
      border: const OutlineInputBorder(),
    );
  }

  /// Coloca la etiqueta del campo encima del control para que las etiquetas
  /// largas se lean completas (el `labelText` de Material las recorta).
  Widget _withLabel(Map<String, dynamic> field, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormFieldLabel(
          label: field['label'] as String,
          isRequired: field['required'] as bool? ?? false,
        ),
        child,
      ],
    );
  }

  Widget _buildField(Map<String, dynamic> field) {
    final key = field['key'] as String;
    final label = field['label'] as String;
    final type = field['type'] as String;
    final isRequired = field['required'] as bool? ?? false;
    final hint = field['hint'] as String?;

    // Usar valor guardado si existe
    final valorInicial = _respuestasGuardadas?[key];
    final validator = _validatorFor(field);

    switch (type) {
      case 'fixed':
        final valorFijo = _valorFijo(field);
        return _withLabel(
          field,
          FormBuilderTextField(
            name: key,
            initialValue: valorFijo,
            readOnly: true,
            enabled: false,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              filled: true,
              suffixIcon: const Icon(Icons.lock_outline, size: 18),
              hintText: valorFijo.isEmpty ? 'Sin dato registrado' : null,
            ),
          ),
        );

      case 'text':
        return _withLabel(
          field,
          FormBuilderTextField(
            name: key,
            initialValue: valorInicial?.toString() ?? '',
            maxLength: field['maxLength'] as int?,
            decoration: _decoration(hint: hint),
            validator: validator,
          ),
        );

      case 'number':
        return _withLabel(
          field,
          FormBuilderTextField(
            name: key,
            initialValue: valorInicial?.toString() ?? '',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoration(
              hint: hint,
              suffixText: field['suffix'] as String?,
            ),
            validator: validator,
          ),
        );

      case 'number_unit':
        final units = (field['units'] as List).cast<String>();
        final unitKey = field['unitKey'] as String? ?? '${key}_unidad';
        final unidadGuardada = _respuestasGuardadas?[unitKey]?.toString();
        return _withLabel(
          field,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: FormBuilderTextField(
                  name: key,
                  initialValue: valorInicial?.toString() ?? '',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _decoration(hint: hint),
                  validator: validator,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FormBuilderDropdown<String>(
                  name: unitKey,
                  initialValue: units.contains(unidadGuardada)
                      ? unidadGuardada
                      : units.first,
                  decoration: InputDecoration(
                    labelText: field['unitLabel'] as String? ?? 'Unidad',
                    border: const OutlineInputBorder(),
                  ),
                  items: units
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Seleccione una unidad'
                      : null,
                ),
              ),
            ],
          ),
        );

      case 'month_year':
        final meses = (field['meses'] as List).cast<String>();
        final anios = (field['anios'] as List).cast<String>();
        final anioKey = field['anioKey'] as String? ?? '${key}_anio';
        final mesGuardado = _respuestasGuardadas?[key]?.toString();
        final anioGuardado = _respuestasGuardadas?[anioKey]?.toString();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormFieldLabel(label: label, isRequired: isRequired),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FormBuilderDropdown<String>(
                    name: key,
                    initialValue: meses.contains(mesGuardado)
                        ? mesGuardado
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Mes',
                      border: OutlineInputBorder(),
                    ),
                    items: meses
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    validator: validator,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FormBuilderDropdown<String>(
                    name: anioKey,
                    initialValue: anios.contains(anioGuardado)
                        ? anioGuardado
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Año',
                      border: OutlineInputBorder(),
                    ),
                    items: anios
                        .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                        .toList(),
                    validator: validator,
                  ),
                ),
              ],
            ),
          ],
        );

      case 'date':
        return _withLabel(
          field,
          FormBuilderDateTimePicker(
            name: key,
            initialValue: valorInicial != null
                ? DateTime.tryParse(valorInicial.toString())
                : null,
            inputType: InputType.date,
            format: DateFormat('dd/MM/yyyy'),
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.calendar_today),
              border: OutlineInputBorder(),
            ),
            validator: validator,
          ),
        );

      case 'dropdown':
        final options = (field['options'] as List).cast<String>();
        return _withLabel(
          field,
          FormBuilderDropdown<String>(
            name: key,
            initialValue: valorInicial?.toString(),
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: options
                .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                .toList(),
            validator: validator,
          ),
        );

      case 'signature':
        return FormBuilderField<String>(
          name: key,
          initialValue: valorInicial?.toString(),
          validator: validator,
          builder: (field) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FormFieldLabel(label: label, isRequired: isRequired),
                FirmaPad(
                  key: ValueKey('firma_${key}_$_resetVersion'),
                  initialValue: _respuestasGuardadas?[key]?.toString(),
                  onChanged: (valor) => field.didChange(valor),
                ),
                if (field.hasError)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Text(
                      field.errorText ?? '',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        );

      case 'switch':
        return FormBuilderSwitch(
          name: key,
          title: Text(label),
          initialValue: valorInicial == true || valorInicial == 'true',
          contentPadding: EdgeInsets.zero,
          decoration: const InputDecoration(border: InputBorder.none),
        );

      default:
        return _withLabel(
          field,
          FormBuilderTextField(
            name: key,
            initialValue: valorInicial?.toString() ?? '',
            decoration: const InputDecoration(border: OutlineInputBorder()),
            validator: validator,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_template == null) {
      return const Scaffold(
        body: Center(child: Text('Error al cargar la plantilla')),
      );
    }

    final campos = (_template!['campos'] as List).cast<Map<String, dynamic>>();
    final codigoFinca = _codigoFincaActual;
    final titulo = codigoFinca != null
        ? '${_template!['titulo']} - $codigoFinca'
        : _template!['titulo'] as String;

    return Scaffold(
      appBar: AppBar(title: Text(titulo), centerTitle: true),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: FormBuilder(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_template!['descripcion'] != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _template!['descripcion'] as String,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ...campos.map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildField(field),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _onSave,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Guardar Localmente',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _confirmarLimpiar,
                  child: const Text('Limpiar formulario'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
