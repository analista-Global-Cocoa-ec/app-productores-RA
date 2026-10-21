/// Plantilla del formulario "Registro manual de cosecha".
/// Simula la respuesta JSON que vendría de un servidor.
///
/// Tipos de campo soportados por [FormScreen]:
/// - text: respuesta corta
/// - number: número (con `positive: true` exige > 0 y `suffix` para la unidad)
/// - number_unit: número + lista desplegable de unidades (`unitKey`)
/// - date: fecha
/// - fixed: valor fijo tomado de la finca (`source`)
/// - signature: firma dibujada
/// - month_year: lista de meses + lista de años (`anioKey`)
final Map<String, dynamic> registroCosechaTemplate = {
  'id': 'registro_cosecha',
  'titulo': 'Registro manual de cosecha',
  'descripcion': 'Registro de cosechas manuales realizadas en la finca',
  'campos': [
    {
      'key': 'codigo_agricultor',
      'label': 'Código del agricultor',
      'type': 'fixed',
      'source': 'finca_codigo',
      'required': false,
    },
    {
      'key': 'nombre_agricultor',
      'label': 'Nombre del agricultor',
      'type': 'fixed',
      'source': 'finca_nombre_agricultor',
      'required': false,
    },
    {
      'key': 'nombre_cultivo',
      'label': 'Nombre del cultivo',
      'type': 'text',
      'required': true,
      'maxLength': 100,
      'hint': 'Ej: Cacao',
    },
    {
      'key': 'variedad_cultivo',
      'label': 'Variedad (si aplica)',
      'type': 'text',
      'required': false,
      'maxLength': 100,
      'hint': 'Ej: Criollo, Trinitario',
    },
    {
      'key': 'fecha_cosecha',
      'label': 'Fecha de cosecha',
      'type': 'date',
      'required': true,
    },
    {
      'key': 'area_cosechada_ha',
      'label': 'Área cosechada',
      'type': 'number',
      'required': true,
      'positive': true,
      'suffix': 'ha',
      'hint': 'Ej: 2.5',
    },
    {
      'key': 'cantidad_cosechada',
      'label': 'Cantidad cosechada',
      'type': 'number_unit',
      'required': true,
      'positive': true,
      'unitKey': 'cantidad_cosechada_unidad',
      'units': ['qq', 'kg'],
      'unitLabel': 'Unidad',
      'hint': 'Ej: 25.5',
    },
    {
      'key': 'condiciones_climaticas',
      'label': 'Condiciones climáticas durante la cosecha',
      'type': 'text',
      'required': true,
      'maxLength': 150,
      'hint': 'Ej: Soleado, lluvia ligera',
    },
    {
      'key': 'responsable_cosecha',
      'label': 'Nombre de quien realiza la cosecha',
      'type': 'text',
      'required': true,
      'maxLength': 100,
      'hint': 'Ej: Juan Pérez',
    },
    {
      'key': 'destino_producto',
      'label': 'Destino del producto',
      'type': 'text',
      'required': true,
      'maxLength': 150,
      'hint': 'Ej: Acopio, venta directa',
    },
    {
      'key': 'firma_agricultor',
      'label': 'Firma del agricultor o responsable',
      'type': 'signature',
      'required': true,
    },
    {
      'key': 'firma_tecnico',
      'label': 'Firma del técnico (si aplica)',
      'type': 'signature',
      'required': false,
    },
    {
      'key': 'unidad_estandarizada_qq',
      'label': 'Unidad estandarizada de volumen cosechado',
      'type': 'number',
      'required': true,
      'positive': true,
      'suffix': 'QQ',
      'hint': 'Ej: 25.5',
    },
    {
      'key': 'lote_ubicacion',
      'label': 'Lote o ubicación dentro de la finca (si aplica)',
      'type': 'text',
      'required': false,
      'maxLength': 150,
      'hint': 'Ej: Lote 3, sector norte',
    },
    {
      'key': 'volumen_no_vendido',
      'label': 'Volumen total no vendido a Global Cocoa (vendido a otros)',
      'type': 'number_unit',
      'required': true,
      'positive': true,
      'unitKey': 'volumen_no_vendido_unidad',
      'units': ['kg', 'MT'],
      'unitLabel': 'Unidad',
      'hint': 'Ej: 10.5',
    },
    {
      'key': 'periodo_estimacion_mes',
      'label': 'Periodo con el que se estimó el volumen cosechado',
      'type': 'month_year',
      'required': true,
      'anioKey': 'periodo_estimacion_anio',
      'meses': [
        'Enero',
        'Febrero',
        'Marzo',
        'Abril',
        'Mayo',
        'Junio',
        'Julio',
        'Agosto',
        'Septiembre',
        'Octubre',
        'Noviembre',
        'Diciembre',
      ],
      'anios': List.generate(
        12,
        (indice) => '${DateTime.now().year - indice}',
      ),
    },
  ],
};
