import 'dart:async';

import 'package:flutter/material.dart';

import '../models/finca.dart';
import '../services/finca_service.dart';
import '../services/sync_service.dart';
import 'finca_formularios_screen.dart';

class EditarFincaScreen extends StatefulWidget {
  const EditarFincaScreen({super.key});

  @override
  State<EditarFincaScreen> createState() => _EditarFincaScreenState();
}

class _EditarFincaScreenState extends State<EditarFincaScreen> {
  List<Finca> _fincas = [];
  bool _isLoading = true;
  StreamSubscription<ResultadoSync>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _loadFincas();

    // Si la sincronización automática (por ejemplo al recuperar internet)
    // descarga fincas nuevas, refrescar la lista sin salir de esta pantalla.
    _syncSubscription = SyncService.instance.resultados.listen((resultado) {
      if (!mounted || resultado.enCurso) return;
      _loadFincas();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontStyle: tieneNombre
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                          Text(
                            '${finca.canton} - ${finca.estado}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
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
