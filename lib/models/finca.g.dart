// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finca.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FincaAdapter extends TypeAdapter<Finca> {
  @override
  final int typeId = 1;

  @override
  Finca read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Finca()
      ..codigo = fields[0] as String
      ..canton = fields[1] as String
      ..prefijo = fields[2] as String
      ..estado = fields[3] as String
      ..nombreAgricultor = fields[4] as String?
      ..id = fields[5] as String?
      ..actualizadoLocalEn = fields[6] as DateTime?
      ..sincronizado = fields[7] as bool?
      ..codigoAnteriorPendiente = fields[8] as String?;
  }

  @override
  void write(BinaryWriter writer, Finca obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.codigo)
      ..writeByte(1)
      ..write(obj.canton)
      ..writeByte(2)
      ..write(obj.prefijo)
      ..writeByte(3)
      ..write(obj.estado)
      ..writeByte(4)
      ..write(obj.nombreAgricultor)
      ..writeByte(5)
      ..write(obj.id)
      ..writeByte(6)
      ..write(obj.actualizadoLocalEn)
      ..writeByte(7)
      ..write(obj.sincronizado)
      ..writeByte(8)
      ..write(obj.codigoAnteriorPendiente);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FincaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
