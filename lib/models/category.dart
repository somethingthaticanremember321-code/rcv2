import 'package:hive/hive.dart';

class Category {
  final String id;
  final String householdId;
  final String nameEn;
  final String nameAr;
  final String iconName;
  final double baselineMonthlyBudget;
  final bool isCustom;
  final int sortOrder;
  final int schemaVersion;

  Category({
    required this.id,
    required this.householdId,
    required this.nameEn,
    required this.nameAr,
    this.iconName = 'category',
    this.baselineMonthlyBudget = 0.0,
    this.isCustom = false,
    this.sortOrder = 0,
    this.schemaVersion = 1,
  });

  String localizedName(String langCode) => langCode == 'ar' ? nameAr : nameEn;

  Category copyWith({
    String? nameEn,
    String? nameAr,
    String? iconName,
    double? baselineMonthlyBudget,
    bool? isCustom,
    int? sortOrder,
    int? schemaVersion,
  }) {
    return Category(
      id: id,
      householdId: householdId,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      iconName: iconName ?? this.iconName,
      baselineMonthlyBudget: baselineMonthlyBudget ?? this.baselineMonthlyBudget,
      isCustom: isCustom ?? this.isCustom,
      sortOrder: sortOrder ?? this.sortOrder,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}

class CategoryAdapter extends TypeAdapter<Category> {
  @override
  final int typeId = 12;

  @override
  Category read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Category(
      id: fields[0] as String,
      householdId: fields[1] as String,
      nameEn: fields[2] as String,
      nameAr: fields[3] as String,
      iconName: fields[4] as String? ?? 'category',
      baselineMonthlyBudget: (fields[5] as num?)?.toDouble() ?? 0.0,
      isCustom: fields[6] as bool? ?? false,
      sortOrder: fields[7] as int? ?? 0,
      schemaVersion: fields[99] as int? ?? 1,
    );
  }

  @override
  void write(BinaryWriter writer, Category obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.householdId)
      ..writeByte(2)
      ..write(obj.nameEn)
      ..writeByte(3)
      ..write(obj.nameAr)
      ..writeByte(4)
      ..write(obj.iconName)
      ..writeByte(5)
      ..write(obj.baselineMonthlyBudget)
      ..writeByte(6)
      ..write(obj.isCustom)
      ..writeByte(7)
      ..write(obj.sortOrder)
      ..writeByte(99)
      ..write(obj.schemaVersion);
  }
}
