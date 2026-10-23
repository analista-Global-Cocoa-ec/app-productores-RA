import 'package:flutter_test/flutter_test.dart';

import 'package:app_productores_ra/templates/registro_cosecha.dart';

void main() {
  test('el nombre del cultivo es fijo con valor Cacao', () {
    final campos = (registroCosechaTemplate['campos'] as List)
        .cast<Map<String, dynamic>>();
    final nombreCultivo = campos.firstWhere(
      (campo) => campo['key'] == 'nombre_cultivo',
    );

    expect(nombreCultivo['type'], 'fixed');
    expect(nombreCultivo['value'], 'Cacao');
  });

  test('las condiciones climáticas agrupan viento, lluvia y temperatura', () {
    final campos = (registroCosechaTemplate['campos'] as List)
        .cast<Map<String, dynamic>>();
    final condiciones = campos.firstWhere(
      (campo) => campo['key'] == 'condiciones_climaticas',
    );

    expect(condiciones['type'], 'section');

    final subcampos = (condiciones['campos'] as List)
        .cast<Map<String, dynamic>>();
    final viento = subcampos.firstWhere(
      (campo) => campo['key'] == 'viento_cosecha',
    );
    final lluvia = subcampos.firstWhere(
      (campo) => campo['key'] == 'lluvia_cosecha',
    );
    final temperatura = subcampos.firstWhere(
      (campo) => campo['key'] == 'temperatura_cosecha_c',
    );

    expect(viento['type'], 'dropdown');
    expect(viento['options'], [
      'Sin viento',
      'Viento leve',
      'Viento moderado',
      'Viento fuerte',
    ]);
    expect(lluvia['type'], 'dropdown');
    expect(lluvia['options'], [
      'Sin lluvia',
      'Lluvia ligera',
      'Lluvia moderada',
      'Lluvia intensa',
    ]);
    expect(temperatura['type'], 'number');
    expect(temperatura['integer'], isTrue);
    expect(temperatura['suffix'], '°C');
  });

  test('la variedad del cultivo es una lista con CCN51 por defecto', () {
    final campos = (registroCosechaTemplate['campos'] as List)
        .cast<Map<String, dynamic>>();
    final variedad = campos.firstWhere(
      (campo) => campo['key'] == 'variedad_cultivo',
    );

    expect(variedad['type'], 'dropdown');
    expect(variedad['default'], 'CCN51');
    expect(variedad['options'], [
      'CCN51',
      'Cacao Arriba',
      'Cacao Nacional',
      'Cacao Trinitario',
      'Cacao Forastero',
    ]);
  });
}
