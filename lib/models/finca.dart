import 'package:hive/hive.dart';

part 'finca.g.dart';

@HiveType(typeId: 1)
class Finca extends HiveObject {
  @HiveField(0)
  late String codigo;

  @HiveField(1)
  late String canton;

  @HiveField(2)
  late String prefijo;

  @HiveField(3)
  String estado = 'Activa';

  @HiveField(4)
  String? nombreAgricultor;

  /// Identificador estable de la finca, independiente de su código.
  ///
  /// Se usa como ID del documento en la colección `fincas` de Firestore para
  /// que cambiar el código no cambie la identidad de la finca.
  @HiveField(5)
  String? id;

  /// Última modificación local de los datos generales.
  @HiveField(6)
  DateTime? actualizadoLocalEn;

  /// Indica si los datos generales actuales ya fueron aceptados por la nube.
  @HiveField(7)
  bool? sincronizado;

  /// Código anterior pendiente de migrar en los formularios remotos.
  @HiveField(8)
  String? codigoAnteriorPendiente;

  /// Identificador usable incluso en fincas creadas antes de esta versión.
  /// [FincaService.initialize] asigna y guarda un UUID a los registros
  /// existentes, por lo que este fallback solo cubre casos excepcionales.
  String get identificador {
    final valor = id;
    return valor == null || valor.isEmpty ? codigo : valor;
  }
}
