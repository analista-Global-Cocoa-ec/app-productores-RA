/// Plantilla del formulario "Registro manual de cosecha".
/// Simula la respuesta JSON que vendría de un servidor.
const Map<String, dynamic> registroCosechaTemplate = {
  'id': 'registro_cosecha',
  'titulo': 'Registro manual de cosecha',
  'descripcion': 'Registro de cosechas manuales realizadas en la finca',
  'campos': [
    {
      'key': 'fecha_cosecha',
      'label': 'Fecha de cosecha',
      'type': 'date',
      'required': true,
    },
    {
      'key': 'producto_cosechado',
      'label': 'Producto cosechado',
      'type': 'dropdown',
      'required': true,
      'options': ['Cacao', 'Café', 'Maíz', 'Plátano', 'Otro'],
    },
    {
      'key': 'cantidad_kg',
      'label': 'Cantidad cosechada (kg)',
      'type': 'number',
      'required': true,
      'hint': 'Ej: 150.5',
    },
    {
      'key': 'calidad_producto',
      'label': 'Calidad del producto',
      'type': 'dropdown',
      'required': true,
      'options': ['A - Excelente', 'B - Buena', 'C - Regular', 'D - Mala'],
    },
    {
      'key': 'cuaderno_campo',
      'label': '¿Se registró en cuaderno de campo?',
      'type': 'switch',
      'required': false,
    },
    {
      'key': 'observaciones',
      'label': 'Observaciones',
      'type': 'text',
      'required': false,
      'maxLength': 500,
      'hint': 'Notas adicionales sobre la cosecha',
    },
  ],
};
