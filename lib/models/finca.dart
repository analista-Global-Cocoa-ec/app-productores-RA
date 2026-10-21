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
}
