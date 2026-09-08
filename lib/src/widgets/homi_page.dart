import 'package:flutter/material.dart';

class HomiPage extends StatelessWidget {
  const HomiPage({
    required this.title,
    required this.subtitle,
    required this.children,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 760 ? 680.0 : constraints.maxWidth;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: Theme.of(context).textTheme.displaySmall),
                            const SizedBox(height: 6),
                            Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 12),
                        trailing!,
                      ],
                    ],
                  ),
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
