import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'sync_utils.dart';

/// Acceso de bajo nivel a la colección `formularios-fincas` de Firestore.
///
/// La inicialización es tolerante a fallos: si la plataforma no tiene
/// configuración de Firebase (por ejemplo Windows) o no hay conexión, la app
/// sigue funcionando únicamente con Hive.
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  static const String coleccionFormularios = 'formularios-fincas';
  static const int versionEsquema = 1;

  bool _disponible = false;
  bool _inicializacionIntentada = false;

  /// Indica si Firebase/Firestore se inicializó correctamente.
  bool get disponible => _disponible;

  Future<bool> initialize() async {
    if (_disponible) return true;
    if (_inicializacionIntentada) return _disponible;
    _inicializacionIntentada = true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (error) {
      _disponible = false;
      debugPrint('Firebase no disponible: $error');
      return _disponible;
    }

    // Los settings deben aplicarse antes del primer uso de Firestore. Si ya
    // fueron aplicados (por ejemplo tras un hot restart), no es un error.
    try {
      if (kIsWeb) {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          webPersistentTabManager: WebPersistentMultipleTabManager(),
        );
      } else {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      }
    } catch (error) {
      debugPrint('No se pudieron aplicar los settings de Firestore: $error');
    }

    _disponible = true;
    return _disponible;
  }

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      FirebaseFirestore.instance.collection(coleccionFormularios);

  /// ID determinista del documento para una finca y formulario.
  static String docIdPara(String fincaCodigo, String templateId) =>
      SyncUtils.docIdPara(fincaCodigo, templateId);

  /// Descarga todos los documentos válidos de la colección.
  ///
  /// Los documentos que no tienen el esquema esperado (por ejemplo el
  /// documento dummy usado para conservar la colección) se ignoran.
  Future<Map<String, Map<String, dynamic>>> obtenerTodos() async {
    if (!_disponible) return {};

    final snapshot = await _coleccion.get();
    final documentos = <String, Map<String, dynamic>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (!esDocumentoValido(data)) {
        debugPrint('Documento ignorado (esquema no reconocido): ${doc.id}');
        continue;
      }
      documentos[doc.id] = data;
    }

    return documentos;
  }

  /// Sube (o actualiza) la respuesta de un formulario.
  Future<void> guardarDocumento({
    required String fincaCodigo,
    required String templateId,
    required String templateTitulo,
    required Map<String, dynamic> respuestas,
    required DateTime actualizadoLocalEn,
    required String hashRespuestas,
    String? nombreAgricultor,
    String? canton,
  }) async {
    if (!_disponible) {
      throw StateError('Firestore no está disponible en esta plataforma.');
    }

    final docId = docIdPara(fincaCodigo, templateId);
    final referencia = _coleccion.doc(docId);

    await referencia.set({
      'fincaCodigo': fincaCodigo,
      'nombreAgricultor': nombreAgricultor ?? '',
      'canton': canton ?? '',
      'templateId': templateId,
      'templateTitulo': templateTitulo,
      'respuestas': SyncUtils.sanitizarRespuestas(respuestas),
      'hashRespuestas': hashRespuestas,
      'actualizadoEn': FieldValue.serverTimestamp(),
      'actualizadoLocalEn': actualizadoLocalEn.toUtc().toIso8601String(),
      'versionEsquema': versionEsquema,
      'origen': 'app-productores-RA',
    }, SetOptions(merge: true));
  }

  /// Valida que un documento pertenezca al esquema de formularios.
  static bool esDocumentoValido(Map<String, dynamic> data) {
    final fincaCodigo = data['fincaCodigo'];
    final templateId = data['templateId'];
    final respuestas = data['respuestas'];
    return fincaCodigo is String &&
        fincaCodigo.isNotEmpty &&
        templateId is String &&
        templateId.isNotEmpty &&
        respuestas is Map;
  }

  /// Fecha de última edición remota (se prefiere la marca del cliente para
  /// comparar con los timestamps locales).
  static DateTime? fechaDesdeDocumento(Map<String, dynamic> data) {
    final local = data['actualizadoLocalEn'];
    if (local is String) {
      final fecha = DateTime.tryParse(local);
      if (fecha != null) return fecha.toUtc();
    }

    final servidor = data['actualizadoEn'];
    if (servidor is Timestamp) return servidor.toDate().toUtc();

    return null;
  }
}
