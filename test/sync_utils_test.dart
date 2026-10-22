import 'package:flutter_test/flutter_test.dart';

import 'package:app_productores_ra/services/sync_utils.dart';

void main() {
  group('SyncUtils', () {
    test('genera IDs de documento válidos y deterministas', () {
      expect(
        SyncUtils.docIdPara('BAB-002', 'registro_cosecha'),
        'BAB-002_registro_cosecha',
      );
      expect(
        SyncUtils.docIdPara('BAB/002', 'registro_cosecha'),
        'BAB-002_registro_cosecha',
      );
    });

    test('extrae el ID base de la clave compuesta de Hive', () {
      expect(
        SyncUtils.templateBaseId('registro_cosecha:123456'),
        'registro_cosecha',
      );
      expect(SyncUtils.templateBaseId('registro_cosecha'), 'registro_cosecha');
    });

    test('el hash no depende del orden de las claves', () {
      final a = {
        'b': 1,
        'a': {'z': true, 'y': 'x'},
      };
      final b = {
        'a': {'y': 'x', 'z': true},
        'b': 1,
      };

      expect(SyncUtils.hashRespuestas(a), SyncUtils.hashRespuestas(b));
    });

    test('el hash cambia cuando cambia una respuesta', () {
      final original = {'peso': 10, 'calidad': 'A'};
      final actualizado = {'peso': 11, 'calidad': 'A'};

      expect(
        SyncUtils.hashRespuestas(original),
        isNot(SyncUtils.hashRespuestas(actualizado)),
      );
    });

    test('el hash de los datos generales cambia con el código y el estado', () {
      final original = SyncUtils.hashFinca(
        codigo: 'BAB-001',
        canton: 'Babahoyo',
        prefijo: 'BAB',
        estado: 'Activa',
        nombreAgricultor: 'Juan Pérez',
      );
      final mismoContenido = SyncUtils.hashFinca(
        codigo: 'BAB-001',
        canton: 'Babahoyo',
        prefijo: 'BAB',
        estado: 'Activa',
        nombreAgricultor: ' Juan Pérez ',
      );
      final otroCodigo = SyncUtils.hashFinca(
        codigo: 'BAB-002',
        canton: 'Babahoyo',
        prefijo: 'BAB',
        estado: 'Activa',
        nombreAgricultor: 'Juan Pérez',
      );
      final inactiva = SyncUtils.hashFinca(
        codigo: 'BAB-001',
        canton: 'Babahoyo',
        prefijo: 'BAB',
        estado: 'Inactiva',
        nombreAgricultor: 'Juan Pérez',
      );

      expect(mismoContenido, original);
      expect(otroCodigo, isNot(original));
      expect(inactiva, isNot(original));
    });

    test('sanitiza fechas para Firestore', () {
      final fecha = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final salida = SyncUtils.sanitizarRespuestas({
        'fecha': fecha,
        'anidado': {'valor': fecha},
      });

      expect(salida['fecha'], fecha.toIso8601String());
      expect(
        (salida['anidado'] as Map<String, dynamic>)['valor'],
        fecha.toIso8601String(),
      );
    });
  });
}
