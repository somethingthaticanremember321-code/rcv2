import 'package:hive/hive.dart';

class Transaction {
  final String id;
  final String householdId;
  final String memberId; // Attributed contributor
  final String categoryId;
  final double amount; // Base currency
  final String type; // 'expense' or 'income'
  final DateTime date;
  final String? note;
  // Multi-currency hooks for Pro tier (dormant in v1, no migration needed)
  final String? originalCurrency;
  final double? originalAmount;
  final double? exchangeRate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  Transaction({
    required this.id,
    required this.householdId,
    required this.memberId,
    required this.categoryId,
    required this.amount,
    required this.type,
    required this.date,
    this.note,
    this.originalCurrency,
    this.originalAmount,
    this.exchangeRate,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';

  Transaction copyWith({
    String? memberId,
    String? categoryId,
    double? amount,
    String? type,
    DateTime? date,
    String? note,
    String? originalCurrency,
    double? originalAmount,
    double? exchangeRate,
    DateTime? updatedAt,
    int? schemaVersion,
  }) {
    return Transaction(
      id: id,
      householdId: householdId,
      memberId: memberId ?? this.memberId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      note: note ?? this.note,
      originalCurrency: originalCurrency ?? this.originalCurrency,
      originalAmount: originalAmount ?? this.originalAmount,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 13;

  @override
  Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction(
      id: fields[0] as String,
      householdId: fields[1] as String,
      memberId: fields[2] as String,
      categoryId: fields[3] as String,
      amount: (fields[4] as num).toDouble(),
      type: fields[5] as String? ?? 'expense',
      date: fields[6] as DateTime,
      note: fields[7] as String?,
      originalCurrency: fields[8] as String?,
      originalAmount: (fields[9] as num?)?.toDouble(),
      exchangeRate: (fields[10] as num?)?.toDouble(),
      createdAt: fields[11] as DateTime,
      updatedAt: fields[12] as DateTime,
      schemaVersion: fields[99] as int? ?? 1,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.householdId)
      ..writeByte(2)
      ..write(obj.memberId)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.note)
      ..writeByte(8)
      ..write(obj.originalCurrency)
      ..writeByte(9)
      ..write(obj.originalAmount)
      ..writeByte(10)
      ..write(obj.exchangeRate)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt)
      ..writeByte(99)
      ..write(obj.schemaVersion);
  }
}
