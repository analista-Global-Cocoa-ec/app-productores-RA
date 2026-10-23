/// Calcula el estado de completitud de las respuestas de un formulario.
///
/// Las secciones agrupan campos y no se cuentan como un campo independiente.
/// Un formulario se considera completo cuando todos sus campos obligatorios
/// tienen respuesta; los campos opcionales vacíos no bloquean el estado verde.
class FormCompletion {
  FormCompletion._();

  /// Retorna `empty`, `partial` o `complete`.
  static String estado({
    required Map<String, dynamic>? template,
    required Map<String, dynamic>? respuestas,
  }) {
    if (template == null || respuestas == null) return 'empty';

    final campos =
        (template['campos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (campos.isEmpty) return 'empty';

    final conteo = _Conteo();
    _contarCampos(campos, respuestas, conteo);

    if (conteo.total == 0) return 'empty';

    if (conteo.requeridos > 0) {
      if (conteo.requeridosLlenos == conteo.requeridos) return 'complete';
    } else if (conteo.llenos == conteo.total) {
      return 'complete';
    }

    if (conteo.llenos == 0) return 'empty';
    return 'partial';
  }

  static void _contarCampos(
    List<Map<String, dynamic>> campos,
    Map<String, dynamic> respuestas,
    _Conteo conteo,
  ) {
    for (final campo in campos) {
      if (campo['type'] == 'section') {
        final subcampos =
            (campo['campos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _contarCampos(subcampos, respuestas, conteo);
        continue;
      }

      final claves = <String>[];
      final clave = campo['key'];
      if (clave is String && clave.isNotEmpty) claves.add(clave);

      // Un mismo campo puede guardar su valor en varias claves
      // (número + unidad, mes + año).
      for (final atributo in const ['unitKey', 'anioKey']) {
        final claveExtra = campo[atributo];
        if (claveExtra is String && claveExtra.isNotEmpty) {
          claves.add(claveExtra);
        }
      }

      final requerido = campo['required'] == true;
      for (final clave in claves) {
        conteo.total++;
        if (requerido) conteo.requeridos++;

        final valor = respuestas[clave]?.toString().trim() ?? '';
        if (valor.isNotEmpty) {
          conteo.llenos++;
          if (requerido) conteo.requeridosLlenos++;
        }
      }
    }
  }
}

class _Conteo {
  int total = 0;
  int llenos = 0;
  int requeridos = 0;
  int requeridosLlenos = 0;
}
