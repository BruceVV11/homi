import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homi/src/domain/homi_plus_plan.dart';

void main() {
  test('continuous-location commercial cost guardrails stay aligned', () {
    expect(homiPlusMaxTrustedLiveViewersPerSender, 5);

    final locationSource = File(
      'lib/src/services/location_status_service.dart',
    ).readAsStringSync();
    expect(
      locationSource,
      contains('_minimumCloudWriteGap = Duration(seconds: 90)'),
    );

    final firestoreRules = File('firebase/firestore.rules').readAsStringSync();
    expect(
      firestoreRules,
      contains("duration.value(90, 's')"),
    );

    final shareFunction = File('functions/location_share.js').readAsStringSync();
    expect(shareFunction, contains('MAX_ACTIVE_LIVE_VIEWERS = 5'));
    expect(
      shareFunction,
      contains('Live location can be shared with up to five trusted people'),
    );
  });
}
