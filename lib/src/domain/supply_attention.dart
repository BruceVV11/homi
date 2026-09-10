import 'supply_item.dart';

class SupplyAttention {
  const SupplyAttention._();

  static List<SupplyItem> sorted(
    Iterable<SupplyItem> items,
    DateTime now,
  ) {
    final result = items
        .where((item) => item.effectiveStatus(now) != SupplyStatus.okay)
        .toList(growable: true);
    result.sort((a, b) {
      final rankCompare = rank(a, now).compareTo(rank(b, now));
      if (rankCompare != 0) return rankCompare;

      final aExpiry = a.expiryDate;
      final bExpiry = b.expiryDate;
      if (aExpiry != null && bExpiry != null) {
        final expiryCompare = aExpiry.compareTo(bExpiry);
        if (expiryCompare != 0) return expiryCompare;
      } else if (aExpiry != null) {
        return -1;
      } else if (bExpiry != null) {
        return 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  /// Lower means more important on attention surfaces.
  static int rank(SupplyItem item, DateTime now) {
    final status = item.effectiveStatus(now);
    if (status == SupplyStatus.needToBuy) return 0;
    if (item.isExpired(now)) return 1;
    if (status == SupplyStatus.eatSoon) return 2;
    if (status == SupplyStatus.runningLow) return 3;
    return 4;
  }

  static String conciseStatus(SupplyItem item, DateTime now) {
    if (item.effectiveStatus(now) == SupplyStatus.needToBuy) {
      return 'Need to buy';
    }
    if (item.isExpired(now)) return 'Expired';
    if (item.effectiveStatus(now) == SupplyStatus.eatSoon) return 'Use soon';
    if (item.effectiveStatus(now) == SupplyStatus.runningLow) {
      return 'Running low';
    }
    return 'In stock';
  }
}
