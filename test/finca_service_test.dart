import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:app_productores_ra/models/finca.dart';
import 'package:app_productores_ra/models/form_response.dart';
import 'package:app_productores_ra/services/database_service.dart';
import 'package:app_productores_ra/services/finca_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('finca_service_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(FormResponseAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(FincaAdapter());
    }

    await Hive.openBox<FormResponse>('form_responses');
    await Hive.openBox<Finca>('fincas');
    await FincaService.instance.initialize();
  });

  setUp(() async {
    await Hive.box<Finca>('fincas').clear();
    await Hive.box<FormResponse>('form_responses').clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('los números liberados por fincas inactivas se reutilizan', () async {
    final finca1 = await FincaService.instance.registrarFinca(
      codigo: 'BAB-001',
      canton: 'Babahoyo',
      prefijo: 'BAB',
      nombreAgricultor: 'Agricultor 1',
    );
    final finca2 = await FincaService.instance.registrarFinca(
      codigo: 'BAB-002',
      canton: 'Babahoyo',
      prefijo: 'BAB',
      nombreAgricultor: 'Agricultor 2',
    );

    expect(FincaService.instance.getNumerosDisponibles('BAB'), contains(3));

    await FincaService.instance.inactivarFinca(finca2.codigo);

    final disponibles = FincaService.instance.getNumerosDisponibles('BAB');
    expect(disponibles.first, 2);

    final paraEdicion = FincaService.instance.getNumerosDisponiblesParaFinca(
      prefijo: 'BAB',
      codigoActual: finca1.codigo,
    );
    expect(paraEdicion, contains(1));
    expect(paraEdicion, isNot(contains(2)));
  });

  test('un código no está disponible para otra finca', () async {
    final finca1 = await FincaService.instance.registrarFinca(
      codigo: 'BAB-001',
      canton: 'Babahoyo',
      prefijo: 'BAB',
    );
    final finca2 = await FincaService.instance.registrarFinca(
      codigo: 'BAB-002',
      canton: 'Babahoyo',
      prefijo: 'BAB',
    );

    expect(FincaService.instance.codigoDisponible('BAB-001'), isFalse);
    expect(
      FincaService.instance.codigoDisponible(
        'BAB-001',
        excluirFincaId: finca1.identificador,
      ),
      isTrue,
    );
    expect(
      FincaService.instance.codigoDisponible(
        'BAB-002',
        excluirFincaId: finca1.identificador,
      ),
      isFalse,
    );
    expect(finca2.codigo, 'BAB-002');
  });

  test('cambiar el código migra las respuestas locales', () async {
    final finca = await FincaService.instance.registrarFinca(
      codigo: 'BAB-001',
      canton: 'Babahoyo',
      prefijo: 'BAB',
      nombreAgricultor: 'Agricultor 1',
    );

    await DatabaseService.instance.saveFormResponse(
      templateId: 'registro_cosecha',
      respuestas: {'peso': 10},
      fincaCodigo: 'BAB-001',
    );

    final actualizada = await FincaService.instance.actualizarDatosGenerales(
      fincaId: finca.identificador,
      codigo: 'BAB-010',
      canton: 'Babahoyo',
      prefijo: 'BAB',
      nombreAgricultor: 'Agricultor actualizado',
      estado: 'Activa',
    );

    expect(actualizada.codigo, 'BAB-010');
    expect(actualizada.codigoAnteriorPendiente, 'BAB-001');
    expect(actualizada.sincronizado, isFalse);

    final respuesta = await DatabaseService.instance.getFormResponseForFinca(
      fincaCodigo: 'BAB-010',
      templateId: 'registro_cosecha',
    );
    expect(respuesta, {'peso': 10});
  });
}
