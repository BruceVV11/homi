import 'package:flutter/material.dart';

class HomiPage extends StatelessWidget {
  const HomiPage({
    required this.title,
    required this.subtitle,
    required this.children,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 760 ? 680.0 : constraints.maxWidth;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 6),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
