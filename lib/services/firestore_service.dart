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
  static const int versionEsquemaFincas = 1;
  static const int versionEsquemaFormularios = 2;

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
  static String docIdPara(String fincaId, String templateId) =>
      SyncUtils.docIdPara(fincaId, templateId);

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
      'versionEsquema': versionEsquemaFincas,
      'origen': 'app-productores-RA',
    }, SetOptions(merge: true));
  }

  /// Lee los formularios remotos y migra los documentos antiguos al esquema
  /// actual.
  ///
  /// El esquema nuevo usa `fincaId` como única referencia a la finca y el ID
  /// determinista `{fincaId}_{templateId}`. Los documentos antiguos se
  /// reemplazan por el documento nuevo y se eliminan para no dejar duplicados.
  Future<Map<String, Map<String, dynamic>>> obtenerFormulariosV2({
    required Map<String, String> fincaIdPorCodigo,
  }) async {
    if (!_disponible) return {};

    final snapshot = await _coleccion.get();
    final pendientes = <String, List<_DocumentoFormularioPendiente>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final templateId = data['templateId'];
      final respuestas = data['respuestas'];
      if (templateId is! String || templateId.isEmpty || respuestas is! Map) {
        debugPrint('Formulario ignorado (esquema no reconocido): ${doc.id}');
        continue;
      }

      final fincaId = _resolverFincaId(data, fincaIdPorCodigo);
      if (fincaId == null) {
        debugPrint('Formulario ignorado (finca no identificable): ${doc.id}');
        continue;
      }

      final nuevoId = docIdPara(fincaId, templateId);
      final normalizado = _normalizarDocumentoFormulario(
        data,
        fincaId: fincaId,
        templateId: templateId,
      );

      pendientes
          .putIfAbsent(nuevoId, () => [])
          .add(
            _DocumentoFormularioPendiente(
              docId: doc.id,
              normalizado: normalizado,
              fecha: fechaDesdeDocumento(data),
              yaV2: _esDocumentoFormularioV2(data, fincaId, templateId),
            ),
          );
    }

    final documentos = <String, Map<String, dynamic>>{};
    for (final entrada in pendientes.entries) {
      final nuevoId = entrada.key;
      final candidatos = entrada.value;

      // El último de la lista es el ganador: fecha más reciente y, en empate,
      // el documento que ya cumple el esquema nuevo.
      candidatos.sort((a, b) {
        final fechaA = a.fecha;
        final fechaB = b.fecha;
        if (fechaA != null && fechaB != null) {
          final comparacion = fechaA.compareTo(fechaB);
          if (comparacion != 0) return comparacion;
        } else if (fechaA != null) {
          return 1;
        } else if (fechaB != null) {
          return -1;
        }

        if (a.yaV2 != b.yaV2) return a.yaV2 ? 1 : -1;

        final aEsDeterminista = a.docId == nuevoId;
        final bEsDeterminista = b.docId == nuevoId;
        if (aEsDeterminista != bEsDeterminista) {
          return aEsDeterminista ? 1 : -1;
        }
        return 0;
      });

      final ganador = candidatos.last;
      final datosFinales = ganador.normalizado;

      try {
        if (!ganador.yaV2 || ganador.docId != nuevoId) {
          await _coleccion.doc(nuevoId).set(datosFinales);
        }

        for (final candidato in candidatos) {
          if (candidato.docId != nuevoId) {
            await _coleccion.doc(candidato.docId).delete();
          }
        }
      } catch (error) {
        debugPrint('No se pudo migrar el formulario $nuevoId: $error');
      }

      documentos[nuevoId] = datosFinales;
    }

    return documentos;
  }

  /// Sube (o actualiza) la respuesta de un formulario.
  Future<void> guardarDocumento({
    required String fincaId,
    required String templateId,
    required String templateTitulo,
    required Map<String, dynamic> respuestas,
    required DateTime actualizadoLocalEn,
    required String hashRespuestas,
  }) async {
    if (!_disponible) {
      throw StateError('Firestore no está disponible en esta plataforma.');
    }

    final docId = docIdPara(fincaId, templateId);
    final referencia = _coleccion.doc(docId);

    await referencia.set({
      'fincaId': fincaId,
      'templateId': templateId,
      'templateTitulo': templateTitulo,
      'respuestas': SyncUtils.sanitizarRespuestas(respuestas),
      'hashRespuestas': hashRespuestas,
      'actualizadoEn': FieldValue.serverTimestamp(),
      'actualizadoLocalEn': actualizadoLocalEn.toUtc().toIso8601String(),
      'versionEsquema': versionEsquemaFormularios,
      'origen': 'app-productores-RA',
    }, SetOptions(merge: true));
  }

  /// Valida que un documento pertenezca al esquema de formularios actual.
  static bool esDocumentoValido(Map<String, dynamic> data) {
    final fincaId = data['fincaId'];
    final templateId = data['templateId'];
    final respuestas = data['respuestas'];
    return fincaId is String &&
        fincaId.isNotEmpty &&
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

  static String? _resolverFincaId(
    Map<String, dynamic> data,
    Map<String, String> fincaIdPorCodigo,
  ) {
    final fincaId = data['fincaId'];
    if (fincaId is String && fincaId.isNotEmpty) return fincaId;

    final fincaCodigo = data['fincaCodigo'];
    if (fincaCodigo is String && fincaCodigo.isNotEmpty) {
      return fincaIdPorCodigo[fincaCodigo];
    }

    return null;
  }

  static Map<String, dynamic> _normalizarDocumentoFormulario(
    Map<String, dynamic> data, {
    required String fincaId,
    required String templateId,
  }) {
    final respuestas = Map<String, dynamic>.from(data['respuestas'] as Map);
    final hash = data['hashRespuestas'];
    final fecha = fechaDesdeDocumento(data);
    final actualizadoLocalEn = data['actualizadoLocalEn'];
    final actualizadoEn = data['actualizadoEn'];
    final templateTitulo = data['templateTitulo'];
    final origen = data['origen'];

    return {
      'fincaId': fincaId,
      'templateId': templateId,
      'templateTitulo': templateTitulo is String ? templateTitulo : '',
      'respuestas': SyncUtils.sanitizarRespuestas(respuestas),
      'hashRespuestas': hash is String && hash.isNotEmpty
          ? hash
          : SyncUtils.hashRespuestas(respuestas),
      'actualizadoEn': actualizadoEn is Timestamp
          ? actualizadoEn
          : FieldValue.serverTimestamp(),
      'actualizadoLocalEn':
          actualizadoLocalEn is String && actualizadoLocalEn.isNotEmpty
          ? actualizadoLocalEn
          : (fecha ?? DateTime.now()).toUtc().toIso8601String(),
      'versionEsquema': versionEsquemaFormularios,
      'origen': origen is String && origen.isNotEmpty
          ? origen
          : 'app-productores-RA',
    };
  }

  static bool _esDocumentoFormularioV2(
    Map<String, dynamic> data,
    String fincaId,
    String templateId,
  ) {
    return data['versionEsquema'] == versionEsquemaFormularios &&
        data['fincaId'] == fincaId &&
        data['templateId'] == templateId &&
        data['respuestas'] is Map &&
        !data.containsKey('fincaCodigo') &&
        !data.containsKey('nombreAgricultor') &&
        !data.containsKey('canton');
  }
}

class _DocumentoFormularioPendiente {
  final String docId;
  final Map<String, dynamic> normalizado;
  final DateTime? fecha;
  final bool yaV2;

  const _DocumentoFormularioPendiente({
    required this.docId,
    required this.normalizado,
    required this.fecha,
    required this.yaV2,
  });
}
