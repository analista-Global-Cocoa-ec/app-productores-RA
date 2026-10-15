/// Plantilla del formulario "Registro de agroquimicos".
/// Simula la respuesta JSON que vendría de un servidor.
const Map<String, dynamic> registroAgroquimicosTemplate = {
  'id': 'registro_agroquimicos',
  'titulo': 'Registro de agroquimicos',
  'descripcion': 'Registro de químicos para combatir plagas (pesticidas, herbicidas, rodenticidas)',
  'campos': [
    {
      'key': 'fecha_aplicacion',
      'label': 'Fecha de aplicación',
      'type': 'date',
      'required': true,
    },
    {
      'key': 'tipo_producto',
      'label': 'Tipo de producto',
      'type': 'dropdown',
      'required': true,
      'options': ['Pesticida', 'Herbicida', 'Rodenticida'],
    },
    {
      'key': 'nombre_comercial',
      'label': 'Nombre comercial del producto',
      'type': 'text',
      'required': true,
      'maxLength': 100,
      'hint': 'Ej: Roundup, Glifosato',
    },
    {
      'key': 'cantidad_litros',
      'label': 'Cantidad aplicada (litros)',
      'type': 'number',
      'required': true,
      'hint': 'Ej: 2.5',
    },
    {
      'key': 'area_tratada',
      'label': 'Área tratada (hectáreas)',
      'type': 'number',
      'required': true,
      'hint': 'Ej: 1.0',
    },
    {
      'key': 'equipo_proteccion',
      'label': '¿Se usó equipo de protección personal?',
      'type': 'switch',
      'required': true,
    },
    {
      'key': 'observaciones',
      'label': 'Observaciones',
      'type': 'text',
      'required': false,
      'maxLength': 500,
      'hint': 'Notas adicionales sobre la aplicación',
    },
  ],
};
