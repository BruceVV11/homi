import 'package:country_flags/country_flags.dart' as country_flags;
import 'package:flutter/material.dart';

import '../theme/homi_theme.dart';

/// Consistent country flag treatment for Homi's region surfaces.
///
/// The flag artwork comes from the ISO-country-code based `country_flags`
/// package. A small text fallback keeps the picker usable if a future region
/// code is added before the package knows about it.
class HomiCountryFlag extends StatelessWidget {
  const HomiCountryFlag({
    required this.isoCode,
    this.size = 42,
    super.key,
  });

  final String isoCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    final code = isoCode.trim().toUpperCase();
    final flagWidth = size * 0.72;
    final flagHeight = size * 0.50;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HomiColors.peach.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: HomiColors.border),
      ),
      child: code.length == 2
          ? country_flags.CountryFlag.fromCountryCode(
              code,
              theme: country_flags.ImageTheme(
                width: flagWidth,
                height: flagHeight,
                shape: const country_flags.RoundedRectangle(4),
              ),
            )
          : Text(
              code.isEmpty ? '--' : code,
              style: const TextStyle(
                color: HomiColors.coral,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}
