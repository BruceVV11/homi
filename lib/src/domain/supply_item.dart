import 'dart:convert';

enum SupplyStatus {
  okay,
  runningLow,
  needToBuy,
  eatSoon,
}

extension SupplyStatusLabel on SupplyStatus {
  String get label {
    switch (this) {
      case SupplyStatus.okay:
        return 'All good';
      case SupplyStatus.runningLow:
        return 'Running low';
      case SupplyStatus.needToBuy:
        return 'Need to buy';
      case SupplyStatus.eatSoon:
        return 'Eat soon';
    }
  }
}

class SupplyItem {
  const SupplyItem({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    this.expiryDate,
  });

  final String id;
  final String name;
  final String category;
  final SupplyStatus status;
  final DateTime? expiryDate;

  SupplyItem copyWith({
    SupplyStatus? status,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
  }) {
    return SupplyItem(
      id: id,
      name: name,
      category: category,
      status: status ?? this.status,
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'category': category,
        'status': status.name,
        'expiryDate': expiryDate?.toIso8601String(),
      };

  factory SupplyItem.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String?;
    final expiry = json['expiryDate'] as String?;
    return SupplyItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Supply',
      category: json['category'] as String? ?? 'Household',
      status: SupplyStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => SupplyStatus.okay,
      ),
      expiryDate: expiry == null ? null : DateTime.tryParse(expiry),
    );
  }

  String encode() => jsonEncode(toJson());

  factory SupplyItem.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Supply item must be a JSON object.');
    }
    return SupplyItem.fromJson(Map<String, dynamic>.from(decoded));
  }
}
