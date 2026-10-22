import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'sync_utils.dart';

/// Acceso de bajo nivel a las colecciones `fincas` y `formularios-fincas`.
///
/// La inicialización es tolerante a fallos: si la plataforma no tiene
/// configuración de Firebase (por ejemplo Windows) o no hay conexión, la app
/// sigue funcionando únicamente con Hive.
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  static const String coleccionFincas = 'fincas';
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

  CollectionReference<Map<String, dynamic>> get _coleccionFincas =>
      FirebaseFirestore.instance.collection(coleccionFincas);

  /// ID determinista del documento para una finca y formulario.
  static String docIdPara(String fincaCodigo, String templateId) =>
      SyncUtils.docIdPara(fincaCodigo, templateId);

  /// Descarga los datos generales de todas las fincas.
  Future<Map<String, Map<String, dynamic>>> obtenerFincas() async {
    if (!_disponible) return {};

    final snapshot = await _coleccionFincas.get();
    final documentos = <String, Map<String, dynamic>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (!esFincaValida(data)) {
        debugPrint('Finca remota ignorada (esquema no reconocido): ${doc.id}');
        continue;
      }
      documentos[doc.id] = data;
    }

    return documentos;
  }

  /// Descarga una finca concreta, o `null` si no existe en la nube.
  Future<Map<String, dynamic>?> obtenerFinca(String fincaId) async {
    if (!_disponible) return null;
    final doc = await _coleccionFincas.doc(fincaId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null || !esFincaValida(data)) return null;
    return data;
  }

  /// Sube (o actualiza) los datos generales de una finca.
  Future<void> guardarFinca({
    required String fincaId,
    required String codigo,
    required String canton,
    required String prefijo,
    required String estado,
    required String? nombreAgricultor,
    required DateTime actualizadoLocalEn,
  }) async {
    if (!_disponible) {
      throw StateError('Firestore no está disponible en esta plataforma.');
    }

    final nombre = nombreAgricultor?.trim() ?? '';
    await _coleccionFincas.doc(fincaId).set({
      'fincaId': fincaId,
      'codigo': codigo,
      'canton': canton,
      'prefijo': prefijo,
      'estado': estado,
      'nombreAgricultor': nombre,
      'hashDatos': SyncUtils.hashFinca(
        codigo: codigo,
        canton: canton,
        prefijo: prefijo,
        estado: estado,
        nombreAgricultor: nombre,
      ),
      'actualizadoEn': FieldValue.serverTimestamp(),
      'actualizadoLocalEn': actualizadoLocalEn.toUtc().toIso8601String(),
      'versionEsquema': versionEsquema,
      'origen': 'app-productores-RA',
    }, SetOptions(merge: true));
  }

  /// Actualiza el código de la finca en todos sus formularios remotos.
  ///
  /// Los documentos de `formularios-fincas` usan un ID determinista que
  /// incluye el código de la finca. Al cambiarlo hay que crear el documento
  /// con el nuevo ID y borrar el anterior para no dejar duplicados.
  Future<void> migrarDocumentosFormulario({
    required String codigoAnterior,
    required String codigoNuevo,
    String? fincaId,
    String? nombreAgricultor,
    String? canton,
  }) async {
    if (!_disponible) {
      throw StateError('Firestore no está disponible en esta plataforma.');
    }
    if (codigoAnterior == codigoNuevo) {
      await actualizarMetadatosFormularios(
        fincaCodigo: codigoNuevo,
        fincaId: fincaId,
        nombreAgricultor: nombreAgricultor,
        canton: canton,
      );
      return;
    }

    final snapshot = await _coleccion
        .where('fincaCodigo', isEqualTo: codigoAnterior)
        .get();

    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());

      // Un código puede reutilizarse cuando una finca se inactiva. Si el
      // documento ya tiene `fincaId`, solo se migra si pertenece a esta finca.
      final docFincaId = data['fincaId'];
      if (fincaId != null &&
          fincaId.isNotEmpty &&
          docFincaId is String &&
          docFincaId.isNotEmpty &&
          docFincaId != fincaId) {
        continue;
      }

      final templateId = data['templateId'];
      if (templateId is! String || templateId.isEmpty) continue;

      final nuevoDocId = docIdPara(codigoNuevo, templateId);
      final nuevoRef = _coleccion.doc(nuevoDocId);

      if (nuevoDocId == doc.id) {
        final metadatos = <String, dynamic>{
          'fincaCodigo': codigoNuevo,
          'actualizadoEn': FieldValue.serverTimestamp(),
        };
        if (fincaId != null && fincaId.isNotEmpty) {
          metadatos['fincaId'] = fincaId;
        }
        if (nombreAgricultor != null) {
          metadatos['nombreAgricultor'] = nombreAgricultor.trim();
        }
        if (canton != null) metadatos['canton'] = canton;

        await nuevoRef.set(metadatos, SetOptions(merge: true));
        continue;
      }

      final existente = await nuevoRef.get();
      if (existente.exists) {
        final datosExistentes = existente.data();
        final fechaExistente = datosExistentes == null
            ? null
            : fechaDesdeDocumento(datosExistentes);
        final fechaOrigen = fechaDesdeDocumento(data);

        // Si el documento destino ya tiene datos más recientes, se conserva
        // ese contenido y solo se actualizan los metadatos de la finca.
        if (fechaExistente != null &&
            (fechaOrigen == null || fechaExistente.isAfter(fechaOrigen))) {
          final metadatos = <String, dynamic>{
            'fincaCodigo': codigoNuevo,
            'actualizadoEn': FieldValue.serverTimestamp(),
          };
          if (fincaId != null && fincaId.isNotEmpty) {
            metadatos['fincaId'] = fincaId;
          }
          if (nombreAgricultor != null) {
            metadatos['nombreAgricultor'] = nombreAgricultor.trim();
          }
          if (canton != null) metadatos['canton'] = canton;

          await nuevoRef.set(metadatos, SetOptions(merge: true));
          await doc.reference.delete();
          continue;
        }
      }

      data['fincaCodigo'] = codigoNuevo;
      if (fincaId != null && fincaId.isNotEmpty) {
        data['fincaId'] = fincaId;
      }
      if (nombreAgricultor != null) {
        data['nombreAgricultor'] = nombreAgricultor.trim();
      }
      if (canton != null) data['canton'] = canton;
      data['actualizadoEn'] = FieldValue.serverTimestamp();

      await nuevoRef.set(data);
      await doc.reference.delete();
    }
  }

  /// Actualiza nombre del agricultor y cantón en los formularios remotos.
  Future<void> actualizarMetadatosFormularios({
    required String fincaCodigo,
    String? fincaId,
    String? nombreAgricultor,
    String? canton,
  }) async {
    if (!_disponible) return;
    if (nombreAgricultor == null && canton == null && fincaId == null) return;

    final snapshot = await _coleccion
        .where('fincaCodigo', isEqualTo: fincaCodigo)
        .get();
    if (snapshot.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    var tieneCambios = false;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final docFincaId = data['fincaId'];
      if (fincaId != null &&
          fincaId.isNotEmpty &&
          docFincaId is String &&
          docFincaId.isNotEmpty &&
          docFincaId != fincaId) {
        continue;
      }

      final metadatos = <String, dynamic>{};
      if (fincaId != null && fincaId.isNotEmpty) {
        metadatos['fincaId'] = fincaId;
      }
      if (nombreAgricultor != null) {
        metadatos['nombreAgricultor'] = nombreAgricultor.trim();
      }
      if (canton != null) metadatos['canton'] = canton;
      if (metadatos.isNotEmpty) {
        batch.update(doc.reference, metadatos);
        tieneCambios = true;
      }
    }
    if (tieneCambios) await batch.commit();
  }

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
    String? fincaId,
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
      if (fincaId != null && fincaId.isNotEmpty) 'fincaId': fincaId,
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

  /// Valida que un documento pertenezca al esquema de datos generales.
  static bool esFincaValida(Map<String, dynamic> data) {
    final fincaId = data['fincaId'];
    final codigo = data['codigo'];
    return fincaId is String &&
        fincaId.isNotEmpty &&
        codigo is String &&
        codigo.isNotEmpty;
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

  /// Fecha de última edición de los datos generales de una finca.
  static DateTime? fechaDesdeFinca(Map<String, dynamic> data) =>
      fechaDesdeDocumento(data);
}
