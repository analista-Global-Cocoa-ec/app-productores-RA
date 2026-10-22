import 'package:flutter/material.dart';

import '../services/finca_service.dart';
import '../widgets/numero_selector.dart';

class RegistrarFincaScreen extends StatefulWidget {
  const RegistrarFincaScreen({super.key});

  @override
  State<RegistrarFincaScreen> createState() => _RegistrarFincaScreenState();
}

class _RegistrarFincaScreenState extends State<RegistrarFincaScreen> {
  final TextEditingController _nombreAgricultorController =
      TextEditingController();
  String? _cantonSeleccionado;
  String? _prefijoSeleccionado;
  int? _numeroSeleccionado;
  bool _isSaving = false;

  @override
  void dispose() {
    _nombreAgricultorController.dispose();
    super.dispose();
  }

  String get _codigoFinca {
    if (_prefijoSeleccionado == null || _numeroSeleccionado == null) {
      return '---';
    }
    return '$_prefijoSeleccionado-${_numeroSeleccionado.toString().padLeft(3, '0')}';
  }

  Future<void> _onRegistrar() async {
    if (_nombreAgricultorController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese el nombre del agricultor'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_cantonSeleccionado == null ||
        _prefijoSeleccionado == null ||
        _numeroSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete todos los campos antes de registrar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    await FincaService.instance.registrarFinca(
      codigo: _codigoFinca,
      canton: _cantonSeleccionado!,
      prefijo: _prefijoSeleccionado!,
      nombreAgricultor: _nombreAgricultorController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Finca $_codigoFinca registrada exitosamente'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cantones = FincaService.cantonesPrefijos.keys.toList();
    final prefijos = _cantonSeleccionado != null
        ? FincaService.cantonesPrefijos[_cantonSeleccionado]!
        : <String>[];
    final numeros = _prefijoSeleccionado != null
        ? FincaService.instance.getNumerosDisponibles(_prefijoSeleccionado!)
        : <int>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Finca'), centerTitle: true),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nombre del agricultor
              TextField(
                controller: _nombreAgricultorController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre del agricultor',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                  hintText: 'Ej: Juan Pérez García',
                ),
              ),
              const SizedBox(height: 16),

              // Selector de Cantón
              DropdownButtonFormField<String>(
                key: const ValueKey('canton_dropdown'),
                initialValue: _cantonSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Cantón',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
                items: cantones
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _cantonSeleccionado = value;
                    _prefijoSeleccionado = null;
                    _numeroSeleccionado = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Selector de Prefijo
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'prefijo_dropdown_${_cantonSeleccionado ?? "none"}',
                ),
                initialValue: _prefijoSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Prefijo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                ),
                items: prefijos
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: _cantonSeleccionado == null
                    ? null
                    : (value) {
                        setState(() {
                          _prefijoSeleccionado = value;
                          _numeroSeleccionado = null;
                        });
                      },
              ),
              const SizedBox(height: 16),

              // Selector de Número — PopupMenuButton para evitar bug de DropdownButtonFormField
              if (_prefijoSeleccionado != null)
                NumeroSelector(
                  key: ValueKey(
                    'numero_selector_${_prefijoSeleccionado}_${numeros.join(",")}',
                  ),
                  numeros: numeros,
                  valorSeleccionado: _numeroSeleccionado,
                  onChanged: (value) {
                    setState(() {
                      _numeroSeleccionado = value;
                    });
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.numbers, color: Colors.grey),
                      const SizedBox(width: 12),
                      Text(
                        'Seleccione un prefijo primero',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Código asignado
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Código de Finca asignado:',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _codigoFinca,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _isSaving ? null : _onRegistrar,
                icon: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Registrando...' : 'Registrar Finca'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
