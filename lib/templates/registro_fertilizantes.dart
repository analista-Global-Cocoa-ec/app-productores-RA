/// Plantilla del formulario "Registro de fertilizantes".
/// Simula la respuesta JSON que vendría de un servidor.
const Map<String, dynamic> registroFertilizantesTemplate = {
  'id': 'registro_fertilizantes',
  'titulo': 'Registro de fertilizantes',
  'descripcion': 'Registro de químicos orgánicos/inorgánicos para mejorar la productividad de la finca',
  'campos': [
    {
      'key': 'fecha_aplicacion',
      'label': 'Fecha de aplicación',
      'type': 'date',
      'required': true,
    },
    {
      'key': 'tipo_fertilizante',
      'label': 'Tipo de fertilizante',
      'type': 'dropdown',
      'required': true,
      'options': ['Orgánico', 'Inorgánico'],
    },
    {
      'key': 'nombre_comercial',
      'label': 'Nombre comercial del producto',
      'type': 'text',
      'required': true,
      'maxLength': 100,
      'hint': 'Ej: Urea, Compost, NPK',
    },
    {
      'key': 'cantidad_kg',
      'label': 'Cantidad aplicada (kg)',
      'type': 'number',
      'required': true,
      'hint': 'Ej: 50.0',
    },
    {
      'key': 'area_fertilizada',
      'label': 'Área fertilizada (hectáreas)',
      'type': 'number',
      'required': true,
      'hint': 'Ej: 2.0',
    },
    {
      'key': 'riego_posterior',
      'label': '¿Se regó después de aplicar?',
      'type': 'switch',
      'required': false,
    },
    {
      'key': 'observaciones',
      'label': 'Observaciones',
      'type': 'text',
      'required': false,
      'maxLength': 500,
      'hint': 'Notas adicionales sobre la fertilización',
    },
  ],
};
