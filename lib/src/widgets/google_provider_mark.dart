import 'package:flutter/material.dart';

class GoogleProviderMark extends StatelessWidget {
  const GoogleProviderMark({this.size = 18, super.key});

  final double size;

  static const _logoUrl =
      'https://developers.google.com/static/identity/images/g-logo.png';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Google',
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.08),
            child: Image.network(
              _logoUrl,
              width: size,
              height: size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Text(
                  'G',
                  style: TextStyle(
                    color: const Color(0xFF4285F4),
                    fontSize: size * 0.76,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
