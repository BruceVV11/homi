import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app source does not regress to development/roadmap wording', () {
    const forbidden = <String>[
      'being built',
      'pre-release',
      'pre release',
      'not yet implemented',
      'future feature',
      'roadmap',
      'this build',
    ];

    final offenders = <String>[];
    final sourceRoot = Directory('lib');
    expect(sourceRoot.existsSync(), isTrue,
        reason: 'Run Flutter tests from the Homi project root.');

    for (final entity in sourceRoot.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync().toLowerCase();
      for (final phrase in forbidden) {
        if (content.contains(phrase)) {
          offenders.add('${entity.path}: "$phrase"');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'User-visible Homi source must speak as a complete product. Rephrase development/roadmap wording rather than exposing it in the app. Offenders: ${offenders.join(', ')}',
    );
  });
}
