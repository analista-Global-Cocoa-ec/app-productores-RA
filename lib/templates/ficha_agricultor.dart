/// Plantilla del formulario "Ficha del agricultor".
/// Simula la respuesta JSON que vendría de un servidor.
const Map<String, dynamic> fichaAgricultorTemplate = {
  'id': 'ficha_agricultor',
  'titulo': 'Ficha del agricultor',
  'descripcion': 'Registro de datos personales del productor de cacao',
  'campos': [
    {
      'key': 'nombre_agricultor',
      'label': 'Nombre completo del agricultor',
      'type': 'text',
      'required': true,
      'maxLength': 100,
      'hint': 'Ej: Juan Pérez García',
    },
    {
      'key': 'codigo_cedula',
      'label': 'Número de cédula / ID',
      'type': 'number',
      'required': true,
      'hint': 'Ej: 12345678',
    },
    {
      'key': 'fecha_registro',
      'label': 'Fecha de registro',
      'type': 'date',
      'required': true,
    },
    {
      'key': 'estado_finca',
      'label': 'Estado de la finca',
      'type': 'dropdown',
      'required': true,
      'options': ['Buena', 'Regular', 'Deficiente'],
    },
    {
      'key': 'asistencia_urgente',
      'label': '¿Requiere asistencia técnica urgente?',
      'type': 'switch',
      'required': false,
    },
    {
      'key': 'hectareas_cacao',
      'label': 'Hectáreas de cacao',
      'type': 'number',
      'required': true,
      'hint': 'Ej: 5.5',
    },
    {
      'key': 'variedad_cacao',
      'label': 'Variedad predominante',
      'type': 'dropdown',
      'required': false,
      'options': ['Criollo', 'Trinitario', 'Forastero', 'No identificada'],
    },
  ],
};
