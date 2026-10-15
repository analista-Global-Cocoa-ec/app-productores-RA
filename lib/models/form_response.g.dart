// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'form_response.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FormResponseAdapter extends TypeAdapter<FormResponse> {
  @override
  final int typeId = 0;

  @override
  FormResponse read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FormResponse()
      ..templateId = fields[0] as String
      ..respuestas = (fields[1] as Map).cast<String, dynamic>()
      ..timestamp = fields[2] as DateTime;
  }

  @override
  void write(BinaryWriter writer, FormResponse obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.templateId)
      ..writeByte(1)
      ..write(obj.respuestas)
      ..writeByte(2)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormResponseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
