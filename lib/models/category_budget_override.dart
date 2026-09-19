import 'package:hive/hive.dart';

class CategoryBudgetOverride {
  final String id;
  final String householdId;
  final String categoryId;
  final String yearMonth; // "YYYY-MM", e.g. "2026-03" for Ramadan/Eid
  final double overrideBudget;
  final String? note;
  final int schemaVersion;

  CategoryBudgetOverride({
    required this.id,
    required this.householdId,
    required this.categoryId,
    required this.yearMonth,
    required this.overrideBudget,
    this.note,
    this.schemaVersion = 1,
  });

  CategoryBudgetOverride copyWith({
    double? overrideBudget,
    String? note,
    int? schemaVersion,
  }) {
    return CategoryBudgetOverride(
      id: id,
      householdId: householdId,
      categoryId: categoryId,
      yearMonth: yearMonth,
      overrideBudget: overrideBudget ?? this.overrideBudget,
      note: note ?? this.note,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}

class CategoryBudgetOverrideAdapter extends TypeAdapter<CategoryBudgetOverride> {
  @override
  final int typeId = 16;

  @override
  CategoryBudgetOverride read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CategoryBudgetOverride(
      id: fields[0] as String,
      householdId: fields[1] as String,
      categoryId: fields[2] as String,
      yearMonth: fields[3] as String,
      overrideBudget: (fields[4] as num).toDouble(),
      note: fields[5] as String?,
      schemaVersion: fields[99] as int? ?? 1,
    );
  }

  @override
  void write(BinaryWriter writer, CategoryBudgetOverride obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.householdId)
      ..writeByte(2)
      ..write(obj.categoryId)
      ..writeByte(3)
      ..write(obj.yearMonth)
      ..writeByte(4)
      ..write(obj.overrideBudget)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(99)
      ..write(obj.schemaVersion);
  }
}
