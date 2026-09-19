import 'package:hive/hive.dart';

class ZakatAsset {
  final String id;
  final String householdId;
  final String? memberId; // Owner (or null if pooled household asset)
  final String assetType; // 'cash', 'gold', 'silver', 'investments', 'trade_goods'
  final String name;
  final double cashValue; // Market value in base currency
  final double? weightGrams; // For gold / silver
  final int? purityKarat; // e.g. 24, 22, 21, 18
  final DateTime? hawlStartDate; // When nisab threshold was reached
  final double deductibleLiabilities; // Immediate debts offsetting zakatable wealth
  final String? notes;
  final DateTime updatedAt;
  final int schemaVersion;

  ZakatAsset({
    required this.id,
    required this.householdId,
    this.memberId,
    required this.assetType,
    required this.name,
    required this.cashValue,
    this.weightGrams,
    this.purityKarat,
    this.hawlStartDate,
    this.deductibleLiabilities = 0.0,
    this.notes,
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  /// Net zakatable value after deducting short-term liabilities
  double get netZakatableValue => (cashValue - deductibleLiabilities).clamp(0.0, double.infinity);

  ZakatAsset copyWith({
    String? memberId,
    String? assetType,
    String? name,
    double? cashValue,
    double? weightGrams,
    int? purityKarat,
    DateTime? hawlStartDate,
    double? deductibleLiabilities,
    String? notes,
    DateTime? updatedAt,
    int? schemaVersion,
  }) {
    return ZakatAsset(
      id: id,
      householdId: householdId,
      memberId: memberId ?? this.memberId,
      assetType: assetType ?? this.assetType,
      name: name ?? this.name,
      cashValue: cashValue ?? this.cashValue,
      weightGrams: weightGrams ?? this.weightGrams,
      purityKarat: purityKarat ?? this.purityKarat,
      hawlStartDate: hawlStartDate ?? this.hawlStartDate,
      deductibleLiabilities: deductibleLiabilities ?? this.deductibleLiabilities,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? DateTime.now(),
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}

class ZakatAssetAdapter extends TypeAdapter<ZakatAsset> {
  @override
  final int typeId = 14;

  @override
  ZakatAsset read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ZakatAsset(
      id: fields[0] as String,
      householdId: fields[1] as String,
      memberId: fields[2] as String?,
      assetType: fields[3] as String? ?? 'cash',
      name: fields[4] as String,
      cashValue: (fields[5] as num).toDouble(),
      weightGrams: (fields[6] as num?)?.toDouble(),
      purityKarat: fields[7] as int?,
      hawlStartDate: fields[8] as DateTime?,
      deductibleLiabilities: (fields[9] as num?)?.toDouble() ?? 0.0,
      notes: fields[10] as String?,
      updatedAt: fields[11] as DateTime,
      schemaVersion: fields[99] as int? ?? 1,
    );
  }

  @override
  void write(BinaryWriter writer, ZakatAsset obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.householdId)
      ..writeByte(2)
      ..write(obj.memberId)
      ..writeByte(3)
      ..write(obj.assetType)
      ..writeByte(4)
      ..write(obj.name)
      ..writeByte(5)
      ..write(obj.cashValue)
      ..writeByte(6)
      ..write(obj.weightGrams)
      ..writeByte(7)
      ..write(obj.purityKarat)
      ..writeByte(8)
      ..write(obj.hawlStartDate)
      ..writeByte(9)
      ..write(obj.deductibleLiabilities)
      ..writeByte(10)
      ..write(obj.notes)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(99)
      ..write(obj.schemaVersion);
  }
}
