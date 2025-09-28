import 'package:flutter/material.dart';
import 'src/theme.dart';
import 'src/screens/splash_screen.dart';
import 'src/utils/page_transition.dart';

void main() {
  runApp(const HappenHubApp());
}

class HappenHubApp extends StatelessWidget {
  const HappenHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HappenHub',
      theme: AppTheme.light.copyWith(
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CustomPageTransitionBuilder(),
            TargetPlatform.iOS: CustomPageTransitionBuilder(),
            TargetPlatform.macOS: CustomPageTransitionBuilder(),
            TargetPlatform.windows: CustomPageTransitionBuilder(),
            TargetPlatform.linux: CustomPageTransitionBuilder(),
          },
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}