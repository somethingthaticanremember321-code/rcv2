import 'package:hive/hive.dart';

class ZakatPayment {
  final String id;
  final String householdId; // Scoped to household
  final String? memberId; // Payer (or null for pooled household payment)
  final String obligationPeriod; // e.g. "1447 AH" or "2026"
  final double amount;
  final DateTime paymentDate;
  final String? recipient; // e.g. "Qatar Charity", "Red Crescent", "Local Family"
  final String? note;
  final int schemaVersion;

  ZakatPayment({
    required this.id,
    required this.householdId,
    this.memberId,
    required this.obligationPeriod,
    required this.amount,
    required this.paymentDate,
    this.recipient,
    this.note,
    this.schemaVersion = 1,
  });

  ZakatPayment copyWith({
    String? memberId,
    String? obligationPeriod,
    double? amount,
    DateTime? paymentDate,
    String? recipient,
    String? note,
    int? schemaVersion,
  }) {
    return ZakatPayment(
      id: id,
      householdId: householdId,
      memberId: memberId ?? this.memberId,
      obligationPeriod: obligationPeriod ?? this.obligationPeriod,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      recipient: recipient ?? this.recipient,
      note: note ?? this.note,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}

class ZakatPaymentAdapter extends TypeAdapter<ZakatPayment> {
  @override
  final int typeId = 15;

  @override
  ZakatPayment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ZakatPayment(
      id: fields[0] as String,
      householdId: fields[1] as String,
      memberId: fields[2] as String?,
      obligationPeriod: fields[3] as String? ?? 'Current Period',
      amount: (fields[4] as num).toDouble(),
      paymentDate: fields[5] as DateTime,
      recipient: fields[6] as String?,
      note: fields[7] as String?,
      schemaVersion: fields[99] as int? ?? 1,
    );
  }

  @override
  void write(BinaryWriter writer, ZakatPayment obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.householdId)
      ..writeByte(2)
      ..write(obj.memberId)
      ..writeByte(3)
      ..write(obj.obligationPeriod)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.paymentDate)
      ..writeByte(6)
      ..write(obj.recipient)
      ..writeByte(7)
      ..write(obj.note)
      ..writeByte(99)
      ..write(obj.schemaVersion);
  }
}
