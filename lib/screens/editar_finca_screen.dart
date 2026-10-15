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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Finca'),
        centerTitle: true,
      ),
      body: _fincas.isEmpty
          ? const Center(
              child: Text('No hay fincas registradas'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _fincas.length,
              itemBuilder: (context, index) {
                final finca = _fincas[index];
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
                    subtitle: Text('${finca.canton} - ${finca.estado}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FincaFormulariosScreen(finca: finca),
                        ),
                      ).then((_) => _loadFincas());
                    },
                  ),
                );
              },
            ),
    );
  }
}
