import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:intl/intl.dart';

import '../services/database_service.dart';
import '../services/template_service.dart';

class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  Map<String, dynamic>? _template;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    try {
      final template = await TemplateService.instance.loadTemplate('ficha_agricultor');
      if (mounted) {
        setState(() {
          _template = template;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando plantilla: $e')),
        );
      }
    }
  }

  String? _requiredValidator(dynamic value) {
    if (value == null || (value is String && value.trim().isEmpty)) {
      return 'Campo obligatorio';
    }
    return null;
  }

  String? _numberValidator(dynamic value) {
    if (value == null || (value is String && value.trim().isEmpty)) {
      return 'Campo obligatorio';
    }
    if (double.tryParse(value.toString()) == null) {
      return 'Ingrese un número válido';
    }
    return null;
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

    responses.forEach((key, value) {
      if (value is DateTime) {
        responses[key] = value.toIso8601String();
      }
    });

    final templateId = _template!['id'] as String;
    final newId = await DatabaseService.instance.saveFormResponse(
      templateId: templateId,
      respuestas: responses,
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ficha guardada localmente con ID #$newId'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );

    _formKey.currentState?.reset();
  }

  Widget _buildField(Map<String, dynamic> field) {
    final key = field['key'] as String;
    final label = field['label'] as String;
    final type = field['type'] as String;
    final isRequired = field['required'] as bool? ?? false;
    final hint = field['hint'] as String?;

    final String? Function(dynamic)? validator = isRequired
        ? (type == 'number' ? _numberValidator : _requiredValidator)
        : (type == 'number'
            ? (value) => (value != null && value.toString().isNotEmpty && double.tryParse(value.toString()) == null)
                ? 'Ingrese un número válido'
                : null
            : null);

    switch (type) {
      case 'text':
        return FormBuilderTextField(
          name: key,
          maxLength: field['maxLength'] as int?,
          decoration: InputDecoration(
            labelText: isRequired ? '$label *' : label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          validator: validator,
        );

      case 'number':
        return FormBuilderTextField(
          name: key,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: isRequired ? '$label *' : label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          validator: validator,
        );

      case 'date':
        return FormBuilderDateTimePicker(
          name: key,
          inputType: InputType.date,
          format: DateFormat('dd/MM/yyyy'),
          decoration: InputDecoration(
            labelText: isRequired ? '$label *' : label,
            suffixIcon: const Icon(Icons.calendar_today),
            border: const OutlineInputBorder(),
          ),
          validator: validator,
        );

      case 'dropdown':
        final options = (field['options'] as List).cast<String>();
        return FormBuilderDropdown<String>(
          name: key,
          decoration: InputDecoration(
            labelText: isRequired ? '$label *' : label,
            border: const OutlineInputBorder(),
          ),
          items: options
              .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
              .toList(),
          validator: validator,
        );

      case 'switch':
        return FormBuilderSwitch(
          name: key,
          title: Text(label),
          initialValue: false,
          contentPadding: EdgeInsets.zero,
          decoration: const InputDecoration(
            border: InputBorder.none,
          ),
        );

      default:
        return FormBuilderTextField(
          name: key,
          decoration: InputDecoration(
            labelText: isRequired ? '$label *' : label,
            border: const OutlineInputBorder(),
          ),
          validator: validator,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_template == null) {
      return const Scaffold(
        body: Center(child: Text('Error al cargar la plantilla')),
      );
    }

    final campos = (_template!['campos'] as List).cast<Map<String, dynamic>>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_template!['titulo'] as String),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
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
              ...campos.map((field) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildField(field),
                  )),
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
                label: Text(_isSaving ? 'Guardando...' : 'Guardar Localmente'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _formKey.currentState?.reset(),
                child: const Text('Limpiar formulario'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
