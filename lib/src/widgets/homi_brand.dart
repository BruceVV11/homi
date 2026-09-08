import 'package:flutter/material.dart';

class HomiLogo extends StatelessWidget {
  const HomiLogo({this.width = 190, super.key});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/homi_logo_lockup.png',
      width: width,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Homi',
    );
  }
}

class HomiMark extends StatelessWidget {
  const HomiMark({this.size = 74, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/homi_splash_mark.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Homi mark',
    );
  }
}
