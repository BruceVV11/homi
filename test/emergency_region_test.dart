import 'package:flutter_test/flutter_test.dart';
import 'package:homi/src/domain/emergency_region.dart';

void main() {
  test('offline emergency catalog has unique ISO regions and dialable numbers', () {
    final seen = <String>{};
    for (final region in EmergencyRegionCatalog.regions) {
      expect(seen.add(region.isoCode), isTrue, reason: region.isoCode);
      expect(region.isoCode, matches(RegExp(r'^[A-Z]{2}$')));
      expect(region.contacts, isNotEmpty, reason: region.countryName);
      expect(
        region.contacts.where((contact) => contact.primary).length,
        lessThanOrEqualTo(1),
        reason: region.countryName,
      );
      for (final contact in region.contacts) {
        expect(
          contact.number,
          matches(RegExp(r'^\d{2,6}$')),
          reason: '${region.countryName}: ${contact.label}',
        );
      }
    }
  });

  test('South African emergency contract remains correct', () {
    final region = EmergencyRegionCatalog.byIsoCode('za');
    expect(region, isNotNull);
    expect(region!.primaryContact?.number, '112');
    expect(
      region.contacts
          .firstWhere((item) => item.kind == EmergencyServiceKind.police)
          .number,
      '10111',
    );
    expect(
      region.contacts
          .firstWhere((item) => item.kind == EmergencyServiceKind.ambulance)
          .number,
      '10177',
    );
  });

  test('leading-zero emergency numbers remain strings', () {
    final australia = EmergencyRegionCatalog.byIsoCode('AU');
    expect(australia?.primaryContact?.number, '000');
  });

  test('regions without one universal number do not invent an SOS number', () {
    expect(EmergencyRegionCatalog.byIsoCode('JP')?.primaryContact, isNull);
    expect(EmergencyRegionCatalog.byIsoCode('BR')?.primaryContact, isNull);
  });
}
