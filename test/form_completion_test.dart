import 'package:flutter_test/flutter_test.dart';

import 'package:app_productores_ra/services/form_completion.dart';
import 'package:app_productores_ra/templates/registro_cosecha.dart';

Map<String, dynamic> _respuestasCompletas() => {
  'fecha_cosecha': '2026-10-23T00:00:00.000',
  'area_cosechada_ha': '2.5',
  'cantidad_cosechada': '25.5',
  'cantidad_cosechada_unidad': 'qq',
  'viento_cosecha': 'Sin viento',
  'lluvia_cosecha': 'Sin lluvia',
  'temperatura_cosecha_c': '28',
  'responsable_cosecha': 'Juan Pérez',
  'destino_producto': 'Venta directa',
  'firma_agricultor': 'data:image/png;base64,abc',
  'unidad_estandarizada_qq': '25.5',
  'volumen_no_vendido': '10',
  'volumen_no_vendido_unidad': 'kg',
  'periodo_estimacion_mes': 'Octubre',
  'periodo_estimacion_anio': '2026',
};

void main() {
  test('cosecha está completa con los obligatorios y opcionales vacíos', () {
    expect(
      FormCompletion.estado(
        template: registroCosechaTemplate,
        respuestas: _respuestasCompletas(),
      ),
      'complete',
    );
  });

  test(
    'una sección con un obligatorio pendiente deja el formulario parcial',
    () {
      final respuestas = _respuestasCompletas()
        ..remove('temperatura_cosecha_c');

      expect(
        FormCompletion.estado(
          template: registroCosechaTemplate,
          respuestas: respuestas,
        ),
        'partial',
      );
    },
  );

  test('un número con unidad requiere también su unidad', () {
    final respuestas = _respuestasCompletas()
      ..remove('cantidad_cosechada_unidad');

    expect(
      FormCompletion.estado(
        template: registroCosechaTemplate,
        respuestas: respuestas,
      ),
      'partial',
    );
  });

  test('sin datos es vacío y con solo opcionales es parcial', () {
    expect(
      FormCompletion.estado(
        template: registroCosechaTemplate,
        respuestas: const {},
      ),
      'empty',
    );

    expect(
      FormCompletion.estado(
        template: registroCosechaTemplate,
        respuestas: const {'variedad_cultivo': 'CCN51'},
      ),
      'partial',
    );
  });
}
