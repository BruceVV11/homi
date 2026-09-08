import 'package:flutter/material.dart';

import 'shell/homi_shell.dart';
import 'theme/homi_theme.dart';

class HomiApp extends StatelessWidget {
  const HomiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Homi',
      debugShowCheckedModeBanner: false,
      theme: HomiTheme.light,
      home: const HomiShell(),
    );
  }
}
