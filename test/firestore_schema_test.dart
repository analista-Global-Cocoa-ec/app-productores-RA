import 'package:flutter_test/flutter_test.dart';

import 'package:app_productores_ra/services/firestore_service.dart';

void main() {
  group('FirestoreService.esDocumentoValido', () {
    test('ignora el documento dummy con solo "saludo"', () {
      expect(
        FirestoreService.esDocumentoValido({'saludo': 'Hola mundo'}),
        isFalse,
      );
    });

    test('acepta un documento con el esquema de formularios', () {
      expect(
        FirestoreService.esDocumentoValido({
          'fincaCodigo': 'BAB-002',
          'templateId': 'registro_cosecha',
          'respuestas': {'peso': 10},
        }),
        isTrue,
      );
    });

    test('rechaza documentos incompletos', () {
      expect(
        FirestoreService.esDocumentoValido({
          'fincaCodigo': 'BAB-002',
          'templateId': 'registro_cosecha',
        }),
        isFalse,
      );
      expect(
        FirestoreService.esDocumentoValido({
          'fincaCodigo': '',
          'templateId': 'registro_cosecha',
          'respuestas': <String, dynamic>{},
        }),
        isFalse,
      );
    });
  });

  group('FirestoreService.esFincaValida', () {
    test('acepta un documento de datos generales', () {
      expect(
        FirestoreService.esFincaValida({
          'fincaId': 'finca-uuid',
          'codigo': 'BAB-002',
        }),
        isTrue,
      );
    });

    test('rechaza documentos sin identidad o código', () {
      expect(FirestoreService.esFincaValida({'saludo': 'Hola mundo'}), isFalse);
      expect(
        FirestoreService.esFincaValida({'fincaId': '', 'codigo': 'BAB-002'}),
        isFalse,
      );
      expect(
        FirestoreService.esFincaValida({'fincaId': 'finca-uuid', 'codigo': ''}),
        isFalse,
      );
    });
  });
}
