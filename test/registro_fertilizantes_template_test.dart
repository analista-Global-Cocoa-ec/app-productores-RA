import 'package:flutter_test/flutter_test.dart';

import 'package:app_productores_ra/templates/registro_fertilizantes.dart';

List<Map<String, dynamic>> _campos() =>
    (registroFertilizantesTemplate['campos'] as List)
        .cast<Map<String, dynamic>>();

void main() {
  test('el registro de fertilizantes conserva el orden solicitado', () {
    expect(_campos().map((campo) => campo['key']).toList(), [
      'codigo_agricultor',
      'nombre_agricultor',
      'nombre_cultivo_fertilizado',
      'tipo_fertilizante',
      'origen_fertilizante',
      'fuente_fertilizante',
      'presentacion_fertilizante',
      'nombre_comercial',
      'proveedor',
      'composicion',
      'lote_producto',
      'dosis_aplicada',
      'area_tratada',
      'fecha_aplicacion',
      'hora_aplicacion',
      'nombre_aplicador',
      'uso_epp',
      'motivo_fertilizacion',
      'analisis_suelo_previo',
      'frecuencia_aplicacion',
      'metodo_aplicacion',
      'condiciones_climaticas_fertilizacion',
      'intervalo_reentrada',
      'aplicacion_cerca_agua',
      'riesgo_escorrentia',
      'zonas_protegidas',
      'plan_manejo',
      'firma_aplicador',
      'firma_responsable',
    ]);
  });

  test('los datos generales y el cultivo son campos fijos', () {
    final campos = {for (final campo in _campos()) campo['key']: campo};

    expect(campos['codigo_agricultor']!['type'], 'fixed');
    expect(campos['codigo_agricultor']!['source'], 'finca_codigo');
    expect(campos['nombre_agricultor']!['type'], 'fixed');
    expect(campos['nombre_agricultor']!['source'], 'finca_nombre_agricultor');
    expect(campos['nombre_cultivo_fertilizado']!['type'], 'fixed');
    expect(campos['nombre_cultivo_fertilizado']!['value'], 'Cacao');
  });

  test('las opciones de fertilizante y aplicación son listas', () {
    final campos = {for (final campo in _campos()) campo['key']: campo};

    expect(campos['tipo_fertilizante']!['type'], 'dropdown');
    expect(campos['tipo_fertilizante']!['options'], ['Orgánico', 'Sintético']);
    expect(campos['origen_fertilizante']!['type'], 'dropdown');
    expect(campos['origen_fertilizante']!['options'], [
      'Autoproducido',
      'Comprado',
    ]);
    expect(campos['fuente_fertilizante']!['type'], 'dropdown');
    expect(campos['presentacion_fertilizante']!['type'], 'dropdown');
    expect(campos['metodo_aplicacion']!['options'], [
      'Manual',
      'Mecánico',
      'Fertirriego',
    ]);
    expect(campos['uso_epp']!['options'], ['Sí', 'No']);
  });

  test('las dosis, áreas y frecuencias tienen el tipo numérico correcto', () {
    final campos = {for (final campo in _campos()) campo['key']: campo};

    expect(campos['dosis_aplicada']!['type'], 'number_unit');
    expect(campos['dosis_aplicada']!['positive'], isTrue);
    expect(campos['dosis_aplicada']!['unitKey'], 'dosis_aplicada_unidad');
    expect(campos['dosis_aplicada']!['units'], ['L', 'kg']);
    expect(campos['area_tratada']!['type'], 'number');
    expect(campos['area_tratada']!['positive'], isTrue);
    expect(campos['frecuencia_aplicacion']!['integer'], isTrue);
    expect(campos['frecuencia_aplicacion']!['positive'], isTrue);
    expect(campos['frecuencia_aplicacion']!['required'], isFalse);
    expect(campos['intervalo_reentrada']!['integer'], isTrue);
    expect(campos['intervalo_reentrada']!['required'], isFalse);
  });

  test('incluye fecha, hora local y firmas digitales', () {
    final campos = {for (final campo in _campos()) campo['key']: campo};

    expect(campos['fecha_aplicacion']!['type'], 'date');
    expect(campos['hora_aplicacion']!['type'], 'time');
    expect(campos['firma_aplicador']!['type'], 'signature');
    expect(campos['firma_responsable']!['type'], 'signature');
  });

  test('las condiciones climáticas agrupan viento, lluvia y temperatura', () {
    final campos = {for (final campo in _campos()) campo['key']: campo};
    final condiciones = campos['condiciones_climaticas_fertilizacion']!;

    expect(condiciones['type'], 'section');

    final subcampos = (condiciones['campos'] as List)
        .cast<Map<String, dynamic>>();
    final viento = subcampos.firstWhere(
      (campo) => campo['key'] == 'viento_fertilizacion',
    );
    final lluvia = subcampos.firstWhere(
      (campo) => campo['key'] == 'lluvia_fertilizacion',
    );
    final temperatura = subcampos.firstWhere(
      (campo) => campo['key'] == 'temperatura_fertilizacion_c',
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
}
