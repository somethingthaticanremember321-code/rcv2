// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReceiptAdapter extends TypeAdapter<Receipt> {
  @override
  final int typeId = 0;

  @override
  Receipt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Receipt(
      id: fields[0] as String?,
      vendorName: fields[1] as String?,
      date: fields[2] as DateTime?,
      totalAmount: fields[3] as double?,
      taxAmount: fields[4] as double?,
      category: fields[5] as String?,
      localImagePath: fields[6] as String,
      schemaVersion: fields[7] == null ? 1 : fields[7] as int,
      syncStatus: fields[8] == null ? 'pending' : fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Receipt obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.vendorName)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.totalAmount)
      ..writeByte(4)
      ..write(obj.taxAmount)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.localImagePath)
      ..writeByte(7)
      ..write(obj.schemaVersion)
      ..writeByte(8)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
