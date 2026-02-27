import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'theme/retro_theme.dart';

void main() {
  runApp(const TapirApp());
}

/// root widget for the Tapir key sender application.
/// uses a retro-futurism 16-bit pixel aesthetic dark theme.
class TapirApp extends StatelessWidget {
  const TapirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tapir',
      debugShowCheckedModeBanner: false,
      theme: buildRetroTheme(),
      home: const HomePage(),
    );
  }
}
