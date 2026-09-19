import 'package:hive/hive.dart';

class Member {
  final String id;
  final String householdId;
  final String name;
  final String role; // 'self', 'spouse', 'contributor', 'dependent'
  final String colorHex;
  final bool isPrimary;
  final DateTime createdAt;
  final int schemaVersion;

  Member({
    required this.id,
    required this.householdId,
    required this.name,
    this.role = 'contributor',
    this.colorHex = '#0F6E56',
    this.isPrimary = false,
    required this.createdAt,
    this.schemaVersion = 1,
  });

  Member copyWith({
    String? name,
    String? role,
    String? colorHex,
    bool? isPrimary,
    int? schemaVersion,
  }) {
    return Member(
      id: id,
      householdId: householdId,
      name: name ?? this.name,
      role: role ?? this.role,
      colorHex: colorHex ?? this.colorHex,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}

class MemberAdapter extends TypeAdapter<Member> {
  @override
  final int typeId = 11;

  @override
  Member read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Member(
      id: fields[0] as String,
      householdId: fields[1] as String,
      name: fields[2] as String,
      role: fields[3] as String? ?? 'contributor',
      colorHex: fields[4] as String? ?? '#0F6E56',
      isPrimary: fields[5] as bool? ?? false,
      createdAt: fields[6] as DateTime,
      schemaVersion: fields[99] as int? ?? 1,
    );
  }

  @override
  void write(BinaryWriter writer, Member obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.householdId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.role)
      ..writeByte(4)
      ..write(obj.colorHex)
      ..writeByte(5)
      ..write(obj.isPrimary)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(99)
      ..write(obj.schemaVersion);
  }
}
