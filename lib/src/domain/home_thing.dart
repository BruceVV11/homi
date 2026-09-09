import 'dart:convert';

class HomeThing {
  const HomeThing({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.createdAt,
    this.brandModel,
    this.nextServiceDate,
    this.warrantyUntil,
    this.notes,
  });

  final String id;
  final String name;
  final String category;
  final String location;
  final String? brandModel;
  final DateTime createdAt;
  final DateTime? nextServiceDate;
  final DateTime? warrantyUntil;
  final String? notes;

  bool serviceDue(DateTime now) {
    if (nextServiceDate == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      nextServiceDate!.year,
      nextServiceDate!.month,
      nextServiceDate!.day,
    );
    return !due.isAfter(today);
  }

  bool serviceSoon(DateTime now, {int withinDays = 14}) {
    if (nextServiceDate == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      nextServiceDate!.year,
      nextServiceDate!.month,
      nextServiceDate!.day,
    );
    final days = due.difference(today).inDays;
    return days >= 0 && days <= withinDays;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'category': category,
        'location': location,
        'brandModel': brandModel,
        'createdAt': createdAt.toIso8601String(),
        'nextServiceDate': nextServiceDate?.toIso8601String(),
        'warrantyUntil': warrantyUntil?.toIso8601String(),
        'notes': notes,
      };

  factory HomeThing.fromJson(Map<String, dynamic> json) => HomeThing(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Home item',
        category: json['category'] as String? ?? 'Appliance',
        location: json['location'] as String? ?? 'Home',
        brandModel: json['brandModel'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        nextServiceDate: DateTime.tryParse(
          json['nextServiceDate'] as String? ?? '',
        ),
        warrantyUntil: DateTime.tryParse(
          json['warrantyUntil'] as String? ?? '',
        ),
        notes: json['notes'] as String?,
      );

  String encode() => jsonEncode(toJson());

  factory HomeThing.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Home thing must be a JSON object.');
    }
    return HomeThing.fromJson(Map<String, dynamic>.from(decoded));
  }
}
