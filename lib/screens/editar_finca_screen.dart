import 'package:flutter/material.dart';

import '../models/finca.dart';
import '../services/finca_service.dart';
import 'finca_formularios_screen.dart';

class EditarFincaScreen extends StatefulWidget {
  const EditarFincaScreen({super.key});

  @override
  State<EditarFincaScreen> createState() => _EditarFincaScreenState();
}

class _EditarFincaScreenState extends State<EditarFincaScreen> {
  List<Finca> _fincas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFincas();
  }

  Future<void> _loadFincas() async {
    final fincas = FincaService.instance.getTodasLasFincas();
    if (mounted) {
      setState(() {
        _fincas = fincas;
        _isLoading = false;
      });
    }
  }

  Future<void> _editarNombreAgricultor(Finca finca) async {
    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoNombreAgricultor(
        codigoFinca: finca.codigo,
        nombreActual: finca.nombreAgricultor ?? '',
      ),
    );

    if (nuevoNombre == null) return;

    await FincaService.instance.actualizarNombreAgricultor(
      codigo: finca.codigo,
      nombreAgricultor: nuevoNombre,
    );

    if (!mounted) return;

    await _loadFincas();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Agricultor actualizado en la finca ${finca.codigo}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Actualizar Finca'), centerTitle: true),
      body: SafeArea(
        top: false,
        child: _fincas.isEmpty
            ? const Center(child: Text('No hay fincas registradas'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _fincas.length,
                itemBuilder: (context, index) {
                  final finca = _fincas[index];
                  final nombreAgricultor = finca.nombreAgricultor?.trim() ?? '';
                  final tieneNombre = nombreAgricultor.isNotEmpty;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: finca.estado == 'Activa'
                            ? Colors.green[100]
                            : Colors.red[100],
                        child: Icon(
                          Icons.agriculture,
                          color: finca.estado == 'Activa'
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                      title: Text(
                        finca.codigo,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tieneNombre
                                ? nombreAgricultor
                                : 'Sin agricultor registrado',
                            style: TextStyle(
                              fontStyle: tieneNombre
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                          Text(
                            '${finca.canton} - ${finca.estado}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Editar nombre del agricultor',
                            onPressed: () => _editarNombreAgricultor(finca),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    FincaFormulariosScreen(finca: finca),
                              ),
                            )
                            .then((_) => _loadFincas());
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Diálogo para editar el nombre del agricultor asociado a una finca.
/// Devuelve el nuevo nombre (ya recortado) o `null` si se cancela.
class _DialogoNombreAgricultor extends StatefulWidget {
  final String codigoFinca;
  final String nombreActual;

  const _DialogoNombreAgricultor({
    required this.codigoFinca,
    required this.nombreActual,
  });

  @override
  State<_DialogoNombreAgricultor> createState() =>
      _DialogoNombreAgricultorState();
}

class _DialogoNombreAgricultorState extends State<_DialogoNombreAgricultor> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.nombreActual);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _guardar() {
    final valor = _controller.text.trim();
    if (valor.isEmpty) {
      setState(() => _errorText = 'Ingrese el nombre del agricultor');
      return;
    }
    Navigator.of(context).pop(valor);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Agricultor de ${widget.codigoFinca}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Nombre del agricultor',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.person_outline),
          errorText: _errorText,
        ),
        onSubmitted: (_) => _guardar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
