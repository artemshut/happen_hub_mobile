import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'src/theme.dart';
import 'src/screens/splash_screen.dart';
import 'src/utils/page_transition.dart';
import 'src/services/secrets.dart';
import 'src/providers/theme_provider.dart';

// 🔔 Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("🔔 Background message received: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables + secrets
  await dotenv.load(fileName: ".env");
  await SecretsService.init();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Setup FCM background handling
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: HappenHubApp()));
}

class HappenHubApp extends ConsumerStatefulWidget {
  const HappenHubApp({super.key});

  @override
  ConsumerState<HappenHubApp> createState() => _HappenHubAppState();
}

class _HappenHubAppState extends ConsumerState<HappenHubApp> {
  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request user permissions
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint("🔔 Notification permission: ${settings.authorizationStatus}");

    // Get FCM token
    String? token = await messaging.getToken();
    debugPrint("📱 FCM Token: $token");

    // Foreground message listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📩 Foreground message: ${message.notification?.title}");
      debugPrint("📩 Data: ${message.data}");
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeControllerProvider);

    final pageTransitions = PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CustomPageTransitionBuilder(),
        TargetPlatform.iOS: CustomPageTransitionBuilder(),
        TargetPlatform.macOS: CustomPageTransitionBuilder(),
        TargetPlatform.windows: CustomPageTransitionBuilder(),
        TargetPlatform.linux: CustomPageTransitionBuilder(),
      },
    );

    return themeMode.when(
      data: (mode) => MaterialApp(
        title: 'HappenHub',
        theme: AppTheme.light.copyWith(
          pageTransitionsTheme: pageTransitions,
        ),
        darkTheme: AppTheme.dark.copyWith(
          pageTransitionsTheme: pageTransitions,
        ),
        themeMode: mode,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      ),
      loading: () => MaterialApp(
        title: 'HappenHub',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => MaterialApp(
        title: 'HappenHub',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: Scaffold(
          body: Center(child: Text('Failed to load theme: $error')),
        ),
      ),
    );
  }
}
