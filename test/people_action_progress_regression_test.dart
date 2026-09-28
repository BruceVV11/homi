import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('People connection actions never look frozen while cloud work runs', () {
    final page = File(
      'lib/src/features/people/people_page.dart',
    ).readAsStringSync();
    final controls = File(
      'lib/src/widgets/homi_controls.dart',
    ).readAsStringSync();

    expect(
      page,
      contains("_connectionActionById[connection.id] = action"),
      reason: 'Each connection needs its own in-flight action state.',
    );
    expect(
      page,
      contains("busy: action == 'accept'"),
      reason: 'Accept must show progress until the callable resolves.',
    );
    expect(
      page,
      contains("busy: action == 'decline'"),
      reason: 'Decline must show progress until the callable resolves.',
    );
    expect(
      page,
      contains("title: 'You’re connected'"),
      reason: 'Successful acceptance needs explicit completion feedback.',
    );
    expect(
      controls,
      contains('class HomiActionLabel extends StatelessWidget'),
      reason: 'Async action progress should use the shared Homi control.',
    );
    expect(
      controls,
      contains('CircularProgressIndicator(strokeWidth: 2.2)'),
      reason: 'Busy actions need a visible spinner, not only disabled input.',
    );
  });
}
