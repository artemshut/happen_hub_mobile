import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'src/theme.dart';
import 'src/screens/splash_screen.dart';
import 'src/utils/page_transition.dart';
import 'src/services/secrets.dart';
import 'src/providers/user_provider.dart'; // ✅ provider

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

  runApp(const HappenHubApp());
}

class HappenHubApp extends StatefulWidget {
  const HappenHubApp({super.key});

  @override
  State<HappenHubApp> createState() => _HappenHubAppState();
}

class _HappenHubAppState extends State<HappenHubApp> {
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
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
        home: const SplashScreen(), // 👈 still handles auto-login
      ),
    );
  }
}