import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'receipt.g.dart';

@HiveType(typeId: 0)
class Receipt extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String? vendorName;

  @HiveField(2)
  DateTime? date;

  @HiveField(3)
  double? totalAmount;

  @HiveField(4)
  double? taxAmount;

  @HiveField(5)
  String? category;

  @HiveField(6)
  String localImagePath;

  @HiveField(7, defaultValue: 1)
  int schemaVersion;

  @HiveField(8, defaultValue: 'pending')
  String syncStatus; // 'pending', 'saved', 'failed'

  Receipt({
    String? id,
    this.vendorName,
    this.date,
    this.totalAmount,
    this.taxAmount,
    this.category,
    required this.localImagePath,
    this.schemaVersion = 1,
    this.syncStatus = 'pending',
  }) : id = id ?? const Uuid().v4();
}
