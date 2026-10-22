import 'dart:async';

import 'package:flutter/material.dart';

import '../models/finca.dart';
import '../services/finca_service.dart';
import '../services/sync_service.dart';
import '../widgets/numero_selector.dart';

/// Formulario de datos generales de una finca.
///
/// Permite cambiar el código (respetando la disponibilidad), el nombre del
/// agricultor y el estado Activa/Inactiva. Los cambios se guardan en Hive y
/// se intentan subir a Firestore inmediatamente.
class FincaDatosGeneralesScreen extends StatefulWidget {
  final Finca finca;

  const FincaDatosGeneralesScreen({super.key, required this.finca});

  @override
  State<FincaDatosGeneralesScreen> createState() =>
      _FincaDatosGeneralesScreenState();
}

class _FincaDatosGeneralesScreenState extends State<FincaDatosGeneralesScreen> {
  late Finca _finca;
  late final TextEditingController _nombreController;

  String? _cantonSeleccionado;
  String? _prefijoSeleccionado;
  int? _numeroSeleccionado;
  bool _cambiarCodigo = false;
  late bool _estaActiva;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _finca =
        FincaService.instance.getFincaPorId(widget.finca.identificador) ??
        widget.finca;
    _nombreController = TextEditingController(
      text: _finca.nombreAgricultor ?? '',
    );
    _estaActiva = _finca.estado == 'Activa';
    _inicializarSeleccionCodigo();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  int? _numeroDeCodigo(String codigo) {
    final partes = codigo.split('-');
    if (partes.length < 2) return null;
    return int.tryParse(partes.last);
  }

  void _inicializarSeleccionCodigo() {
    final cantones = FincaService.cantonesPrefijos.keys.toList();
    _cantonSeleccionado = cantones.contains(_finca.canton)
        ? _finca.canton
        : null;

    final prefijos = _cantonSeleccionado == null
        ? <String>[]
        : FincaService.cantonesPrefijos[_cantonSeleccionado]!;
    _prefijoSeleccionado = prefijos.contains(_finca.prefijo)
        ? _finca.prefijo
        : null;
    _numeroSeleccionado = _prefijoSeleccionado == null
        ? null
        : _numeroDeCodigo(_finca.codigo);
  }

  String get _codigoSeleccionado {
    if (_prefijoSeleccionado == null || _numeroSeleccionado == null) {
      return '---';
    }
    final numero = _numeroSeleccionado!.toString().padLeft(3, '0');
    return '$_prefijoSeleccionado-$numero';
  }

  void _toggleCambiarCodigo(bool value) {
    setState(() {
      _cambiarCodigo = value;
      _inicializarSeleccionCodigo();
    });
  }

  void _onCantonChanged(String? value) {
    setState(() {
      _cantonSeleccionado = value;
      final prefijos = value == null
          ? <String>[]
          : FincaService.cantonesPrefijos[value]!;

      if (value == _finca.canton && prefijos.contains(_finca.prefijo)) {
        _prefijoSeleccionado = _finca.prefijo;
        _numeroSeleccionado = _numeroDeCodigo(_finca.codigo);
      } else {
        _prefijoSeleccionado = null;
        _numeroSeleccionado = null;
      }
    });
  }

  void _onPrefijoChanged(String? value) {
    setState(() {
      _prefijoSeleccionado = value;
      _numeroSeleccionado = value == _finca.prefijo
          ? _numeroDeCodigo(_finca.codigo)
          : null;
    });
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      _mostrarAviso(
        'Ingrese el nombre del agricultor',
        backgroundColor: Colors.orange,
      );
      return;
    }

    final String codigo;
    final String canton;
    final String prefijo;

    if (_cambiarCodigo) {
      if (_cantonSeleccionado == null ||
          _prefijoSeleccionado == null ||
          _numeroSeleccionado == null) {
        _mostrarAviso(
          'Seleccione cantón, prefijo y número para el nuevo código',
          backgroundColor: Colors.orange,
        );
        return;
      }
      codigo = _codigoSeleccionado;
      canton = _cantonSeleccionado!;
      prefijo = _prefijoSeleccionado!;
    } else {
      codigo = _finca.codigo;
      canton = _finca.canton;
      prefijo = _finca.prefijo;
    }

    if (!FincaService.instance.codigoDisponible(
      codigo,
      excluirFincaId: _finca.identificador,
    )) {
      _mostrarAviso(
        'El código $codigo ya está asignado a otra finca',
        backgroundColor: Colors.orange,
      );
      return;
    }

    if (!_estaActiva && _finca.estado == 'Activa') {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Inactivar finca'),
          content: Text(
            'La finca $codigo pasará a estado Inactiva. '
            'Su número quedará disponible para reutilizarse en otra finca.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Inactivar'),
            ),
          ],
        ),
      );

      if (confirmar != true) {
        if (mounted) setState(() => _estaActiva = true);
        return;
      }
    }

    if (!mounted) return;

    setState(() => _isSaving = true);
    final codigoAnterior = _finca.codigo;

    try {
      final actualizada = await FincaService.instance.actualizarDatosGenerales(
        fincaId: _finca.identificador,
        codigo: codigo,
        canton: canton,
        prefijo: prefijo,
        nombreAgricultor: nombre,
        estado: _estaActiva ? 'Activa' : 'Inactiva',
      );

      if (!mounted) return;

      setState(() {
        _finca = actualizada;
        _estaActiva = actualizada.estado == 'Activa';
        _cambiarCodigo = false;
        _inicializarSeleccionCodigo();
        _isSaving = false;
      });

      _mostrarAviso(
        'Datos generales guardados localmente',
        backgroundColor: Colors.green,
      );

      unawaited(_sincronizarEnNube(codigoAnterior));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _mostrarAviso(
        'No se pudieron guardar los datos generales: $error',
        backgroundColor: Colors.orange,
      );
    }
  }

  Future<void> _sincronizarEnNube(String codigoAnterior) async {
    final resultado = await SyncService.instance.sincronizarFinca(
      fincaId: _finca.identificador,
      codigoAnterior: codigoAnterior,
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
      mensaje = 'Datos generales sincronizados en la nube';
      color = Colors.green;
    }

    _mostrarAviso(mensaje, backgroundColor: color);
  }

  void _mostrarAviso(String mensaje, {required Color backgroundColor}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final cantones = FincaService.cantonesPrefijos.keys.toList();
    final prefijos = _cantonSeleccionado == null
        ? <String>[]
        : FincaService.cantonesPrefijos[_cantonSeleccionado]!;
    final numeros = _prefijoSeleccionado == null
        ? <int>[]
        : FincaService.instance.getNumerosDisponiblesParaFinca(
            prefijo: _prefijoSeleccionado!,
            codigoActual: _finca.codigo,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Datos generales'), centerTitle: true),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Finca ${_finca.codigo}',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Actualiza el código, el agricultor y el estado de la finca.',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),

              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _cambiarCodigo,
                      onChanged: _isSaving ? null : _toggleCambiarCodigo,
                      secondary: const Icon(Icons.qr_code_2),
                      title: const Text('Modificar código de finca'),
                      subtitle: Text(
                        _cambiarCodigo
                            ? 'Selecciona el nuevo cantón, prefijo y número.'
                            : 'Código actual: ${_finca.codigo}',
                      ),
                    ),
                    if (!_cambiarCodigo)
                      ListTile(
                        leading: const Icon(Icons.tag),
                        title: Text(
                          _finca.codigo,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text('Código actual'),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'datos_canton_${_finca.identificador}_$_cambiarCodigo',
                              ),
                              initialValue: _cantonSeleccionado,
                              decoration: const InputDecoration(
                                labelText: 'Cantón',
                                prefixIcon: Icon(Icons.location_city),
                              ),
                              items: cantones
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _isSaving ? null : _onCantonChanged,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'datos_prefijo_${_cantonSeleccionado ?? "none"}',
                              ),
                              initialValue: _prefijoSeleccionado,
                              decoration: const InputDecoration(
                                labelText: 'Prefijo',
                                prefixIcon: Icon(Icons.tag),
                              ),
                              items: prefijos
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p),
                                    ),
                                  )
                                  .toList(),
                              onChanged:
                                  _cantonSeleccionado == null || _isSaving
                                  ? null
                                  : _onPrefijoChanged,
                            ),
                            const SizedBox(height: 12),
                            if (_prefijoSeleccionado != null)
                              NumeroSelector(
                                key: ValueKey(
                                  'datos_numero_${_prefijoSeleccionado}_${numeros.join(",")}',
                                ),
                                numeros: numeros,
                                valorSeleccionado: _numeroSeleccionado,
                                onChanged: (value) {
                                  setState(() => _numeroSeleccionado = value);
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
                                    const Icon(
                                      Icons.numbers,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Seleccione un prefijo primero',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            Card(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Text(
                                      'Nuevo código',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _codigoSeleccionado,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _nombreController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Nombre del agricultor',
                  prefixIcon: Icon(Icons.person_outline),
                  hintText: 'Ej: Juan Pérez García',
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: SwitchListTile(
                  value: _estaActiva,
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() => _estaActiva = value),
                  secondary: Icon(
                    _estaActiva
                        ? Icons.check_circle_outline
                        : Icons.pause_circle_outline,
                    color: _estaActiva ? Colors.green : Colors.red,
                  ),
                  title: Text(_estaActiva ? 'Finca activa' : 'Finca inactiva'),
                  subtitle: Text(
                    _estaActiva
                        ? 'La finca está habilitada para registrar formularios.'
                        : 'Su número podrá reutilizarse en otra finca.',
                  ),
                ),
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _isSaving ? null : _guardar,
                icon: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSaving ? 'Guardando...' : 'Guardar datos generales',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Los cambios se guardan localmente y se sincronizan con la nube.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
