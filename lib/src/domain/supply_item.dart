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

enum SupplyUnit {
  item,
  loaf,
  bottle,
  carton,
  pack,
  bag,
  roll,
  egg,
  kilogram,
  gram,
  litre,
  millilitre,
}

extension SupplyUnitDetails on SupplyUnit {
  String get label {
    switch (this) {
      case SupplyUnit.item:
        return 'Item';
      case SupplyUnit.loaf:
        return 'Loaf';
      case SupplyUnit.bottle:
        return 'Bottle';
      case SupplyUnit.carton:
        return 'Carton';
      case SupplyUnit.pack:
        return 'Pack';
      case SupplyUnit.bag:
        return 'Bag';
      case SupplyUnit.roll:
        return 'Roll';
      case SupplyUnit.egg:
        return 'Egg';
      case SupplyUnit.kilogram:
        return 'kg';
      case SupplyUnit.gram:
        return 'g';
      case SupplyUnit.litre:
        return 'L';
      case SupplyUnit.millilitre:
        return 'mL';
    }
  }

  String displayLabel(double quantity) {
    final singular = (quantity - 1).abs() < 0.0001;
    switch (this) {
      case SupplyUnit.item:
        return singular ? 'item' : 'items';
      case SupplyUnit.loaf:
        return singular ? 'loaf' : 'loaves';
      case SupplyUnit.bottle:
        return singular ? 'bottle' : 'bottles';
      case SupplyUnit.carton:
        return singular ? 'carton' : 'cartons';
      case SupplyUnit.pack:
        return singular ? 'pack' : 'packs';
      case SupplyUnit.bag:
        return singular ? 'bag' : 'bags';
      case SupplyUnit.roll:
        return singular ? 'roll' : 'rolls';
      case SupplyUnit.egg:
        return singular ? 'egg' : 'eggs';
      case SupplyUnit.kilogram:
        return 'kg';
      case SupplyUnit.gram:
        return 'g';
      case SupplyUnit.litre:
        return 'L';
      case SupplyUnit.millilitre:
        return 'mL';
    }
  }

  bool get prefersWholeNumbers {
    return switch (this) {
      SupplyUnit.kilogram ||
      SupplyUnit.gram ||
      SupplyUnit.litre ||
      SupplyUnit.millilitre => false,
      _ => true,
    };
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
    this.quantity,
    this.unit,
  });

  final String id;
  final String name;
  final String category;
  final SupplyStatus status;
  final String iconKey;
  final DateTime? expiryDate;

  /// Optional lightweight stock amount. Existing/legacy supplies may leave this
  /// null and continue using the manual stock status exactly as before.
  final double? quantity;
  final SupplyUnit? unit;

  bool get tracksQuantity => quantity != null && unit != null;

  SupplyItem copyWith({
    SupplyStatus? status,
    String? iconKey,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    double? quantity,
    bool clearQuantity = false,
    SupplyUnit? unit,
    bool clearUnit = false,
  }) {
    return SupplyItem(
      id: id,
      name: name,
      category: category,
      status: status ?? this.status,
      iconKey: iconKey ?? this.iconKey,
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      quantity: clearQuantity ? null : (quantity ?? this.quantity),
      unit: clearUnit ? null : (unit ?? this.unit),
    );
  }

  SupplyStatus effectiveStatus(DateTime now, {int soonWithinDays = 3}) {
    if (tracksQuantity && quantity! <= 0) return SupplyStatus.needToBuy;
    if (status != SupplyStatus.okay) return status;
    if (isExpired(now) || isExpiringSoon(now, withinDays: soonWithinDays)) {
      return SupplyStatus.eatSoon;
    }
    return SupplyStatus.okay;
  }

  String displayStatusLabel(DateTime now, {int soonWithinDays = 3}) {
    if (tracksQuantity && quantity! <= 0) return SupplyStatus.needToBuy.label;
    if (status != SupplyStatus.okay) return status.label;
    if (isExpired(now)) return 'Expired';
    if (isExpiringSoon(now, withinDays: soonWithinDays)) {
      return SupplyStatus.eatSoon.label;
    }
    return SupplyStatus.okay.label;
  }

  String? get quantityLabel {
    if (!tracksQuantity) return null;
    final value = quantity!;
    final formatted = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return '$formatted ${unit!.displayLabel(value)}';
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
        'quantity': quantity,
        'unit': unit?.name,
      };

  factory SupplyItem.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String?;
    final expiry = json['expiryDate'] as String?;
    final rawQuantity = json['quantity'];
    final unitName = json['unit'] as String?;
    final parsedUnit = SupplyUnit.values.where((value) => value.name == unitName);
    final quantity = rawQuantity is num ? rawQuantity.toDouble() : null;
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
      quantity: quantity == null || quantity.isNaN || quantity.isInfinite
          ? null
          : quantity < 0
              ? 0
              : quantity,
      unit: parsedUnit.isEmpty ? null : parsedUnit.first,
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
