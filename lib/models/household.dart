import 'package:hive/hive.dart';

class Household {
  final String id;
  final String name;
  final String currencyCode;
  final String currencySymbol;
  final String preferredLanguage; // 'ar' or 'en'
  final String nisabStandard; // 'gold_85g' or 'silver_595g'
  final String zakatAuthorityGuidance; // 'qatar_awqaf', 'uae_awqaf', 'saudi_standard', 'custom'
  final double? cachedGoldPricePerGram;
  final double? cachedSilverPricePerGram;
  final DateTime? pricesUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  Household({
    required this.id,
    required this.name,
    this.currencyCode = 'QAR',
    this.currencySymbol = 'ر.ق',
    this.preferredLanguage = 'ar',
    this.nisabStandard = 'gold_85g',
    this.zakatAuthorityGuidance = 'qatar_awqaf',
    this.cachedGoldPricePerGram,
    this.cachedSilverPricePerGram,
    this.pricesUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  Household copyWith({
    String? name,
    String? currencyCode,
    String? currencySymbol,
    String? preferredLanguage,
    String? nisabStandard,
    String? zakatAuthorityGuidance,
    double? cachedGoldPricePerGram,
    double? cachedSilverPricePerGram,
    DateTime? pricesUpdatedAt,
    DateTime? updatedAt,
    int? schemaVersion,
  }) {
    return Household(
      id: id,
      name: name ?? this.name,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      nisabStandard: nisabStandard ?? this.nisabStandard,
      zakatAuthorityGuidance: zakatAuthorityGuidance ?? this.zakatAuthorityGuidance,
      cachedGoldPricePerGram: cachedGoldPricePerGram ?? this.cachedGoldPricePerGram,
      cachedSilverPricePerGram: cachedSilverPricePerGram ?? this.cachedSilverPricePerGram,
      pricesUpdatedAt: pricesUpdatedAt ?? this.pricesUpdatedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}

class HouseholdAdapter extends TypeAdapter<Household> {
  @override
  final int typeId = 10;

  @override
  Household read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Household(
      id: fields[0] as String,
      name: fields[1] as String,
      currencyCode: fields[2] as String? ?? 'QAR',
      currencySymbol: fields[3] as String? ?? 'ر.ق',
      preferredLanguage: fields[4] as String? ?? 'ar',
      nisabStandard: fields[5] as String? ?? 'gold_85g',
      zakatAuthorityGuidance: fields[6] as String? ?? 'qatar_awqaf',
      cachedGoldPricePerGram: (fields[7] as num?)?.toDouble(),
      cachedSilverPricePerGram: (fields[8] as num?)?.toDouble(),
      pricesUpdatedAt: fields[9] as DateTime?,
      createdAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime,
      schemaVersion: fields[99] as int? ?? 1,
    );
  }

  @override
  void write(BinaryWriter writer, Household obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.currencyCode)
      ..writeByte(3)
      ..write(obj.currencySymbol)
      ..writeByte(4)
      ..write(obj.preferredLanguage)
      ..writeByte(5)
      ..write(obj.nisabStandard)
      ..writeByte(6)
      ..write(obj.zakatAuthorityGuidance)
      ..writeByte(7)
      ..write(obj.cachedGoldPricePerGram)
      ..writeByte(8)
      ..write(obj.cachedSilverPricePerGram)
      ..writeByte(9)
      ..write(obj.pricesUpdatedAt)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(99)
      ..write(obj.schemaVersion);
  }
}
