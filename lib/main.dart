import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'src/theme.dart';
import 'src/screens/splash_screen.dart';
import 'src/utils/page_transition.dart';
import 'src/services/secrets.dart';
import 'src/providers/user_provider.dart'; // ✅ add provider

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  await SecretsService.init();
  runApp(const HappenHubApp());
}

class HappenHubApp extends StatelessWidget {
  const HappenHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()), // ✅ register
      ],
      child: MaterialApp(
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
        home: const SplashScreen(), // 👈 SplashScreen will handle auto-login
      ),
    );
  }
}