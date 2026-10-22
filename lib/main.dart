import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/finca_service.dart';
import 'services/sync_service.dart';

/// Permite mostrar avisos de sincronización aunque el usuario esté en
/// cualquier pantalla de la app.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void _mostrarResultadoSync(ResultadoSync resultado) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null || resultado.enCurso) return;

  final conError = !resultado.disponible || resultado.errores > 0;
  final String mensaje;

  if (!resultado.disponible) {
    mensaje = 'Conexión recuperada, pero la nube no está disponible.';
  } else if (resultado.errores > 0 && resultado.cambios == 0) {
    mensaje =
        'Conexión recuperada, pero no se pudo sincronizar. '
        'Se reintentará más adelante.';
  } else if (resultado.errores > 0) {
    mensaje = 'Conexión recuperada. ${resultado.resumen}';
  } else if (resultado.cambios == 0) {
    mensaje = 'Conexión recuperada. Todo está sincronizado.';
  } else {
    mensaje = 'Conexión recuperada. ${resultado.resumen}';
  }

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: conError ? Colors.orange : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar base de datos Hive
  await DatabaseService.instance.initialize();
  await FincaService.instance.initialize();

  // Inicializar usuario por defecto en almacenamiento seguro
  await AuthService.instance.initDefaultUser();

  // Escuchar los resultados de las sincronizaciones automáticas (reconexión).
  SyncService.instance.resultados.listen(_mostrarResultadoSync);

  // Inicializar Firebase/Firestore y la sincronización en la nube.
  // Si la plataforma no tiene configuración de Firebase, la app continúa
  // funcionando solo con Hive.
  try {
    await SyncService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('No se pudo inicializar la sincronización: $error\n$stackTrace');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Productores RA',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
