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
        return 'In stock';
      case SupplyStatus.runningLow:
        return 'Running low';
      case SupplyStatus.needToBuy:
        return 'Need to buy';
      case SupplyStatus.eatSoon:
        return 'Use soon';
    }
  }
}

class SupplyItem {
  const SupplyItem({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    this.iconKey = 'inventory',
    this.expiryDate,
  });

  final String id;
  final String name;
  final String category;
  final SupplyStatus status;
  final String iconKey;
  final DateTime? expiryDate;

  SupplyItem copyWith({
    SupplyStatus? status,
    String? iconKey,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
  }) {
    return SupplyItem(
      id: id,
      name: name,
      category: category,
      status: status ?? this.status,
      iconKey: iconKey ?? this.iconKey,
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
    );
  }

  SupplyStatus effectiveStatus(DateTime now, {int soonWithinDays = 3}) {
    if (status != SupplyStatus.okay) return status;
    if (isExpired(now) || isExpiringSoon(now, withinDays: soonWithinDays)) {
      return SupplyStatus.eatSoon;
    }
    return SupplyStatus.okay;
  }

  String displayStatusLabel(DateTime now, {int soonWithinDays = 3}) {
    if (status != SupplyStatus.okay) return status.label;
    if (isExpired(now)) return 'Expired';
    if (isExpiringSoon(now, withinDays: soonWithinDays)) {
      return SupplyStatus.eatSoon.label;
    }
    return SupplyStatus.okay.label;
  }

  bool isExpired(DateTime now) {
    if (expiryDate == null) return false;
    return _day(expiryDate!).isBefore(_day(now));
  }

  bool isExpiringSoon(DateTime now, {int withinDays = 3}) {
    if (expiryDate == null) return false;
    final difference = _day(expiryDate!).difference(_day(now)).inDays;
    return difference >= 0 && difference <= withinDays;
  }

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'category': category,
        'status': status.name,
        'iconKey': iconKey,
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
      iconKey: (json['iconKey'] as String?)?.trim().isNotEmpty == true
          ? (json['iconKey'] as String).trim()
          : 'inventory',
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
