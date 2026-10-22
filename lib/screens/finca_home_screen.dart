import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'editar_finca_screen.dart';
import 'login_screen.dart';
import 'registrar_finca_screen.dart';

class FincaHomeScreen extends StatelessWidget {
  const FincaHomeScreen({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    await AuthService.instance.logout();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = AuthService.instance.usuarioActual;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Fincas'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _cerrarSesion(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (usuario != null) ...[
                    Chip(
                      avatar: Icon(
                        AuthService.instance.esAdministrador
                            ? Icons.admin_panel_settings_outlined
                            : Icons.engineering_outlined,
                        size: 18,
                      ),
                      label: Text(
                        '${usuario.username} · ${usuario.perfil.nombre}',
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Icon(
                    Icons.agriculture,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Seleccione una opción',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegistrarFincaScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Registrar Finca'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EditarFincaScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Actualizar Finca'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
