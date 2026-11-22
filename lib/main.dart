import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/auth_gate.dart';
import 'core/theme.dart';
import 'core/push_notification_service.dart';
import 'core/firebase_web_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isMobile =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (kIsWeb || isMobile) {
    try {
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: FirebaseWebOptions.currentPlatform,
        );
      } else {
        await Firebase.initializeApp();
      }
      await PushNotificationService.instance.initialize();
    } catch (error, stackTrace) {
      debugPrint('Klubb Firebase push setup is unavailable: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    runApp(const MyClubApp(configured: false));
    return;
  }

  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);

  runApp(const MyClubApp(configured: true));
}

class MyClubApp extends StatelessWidget {
  final bool configured;

  const MyClubApp({super.key, required this.configured});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Klubb',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey:
          PushNotificationService.instance.scaffoldMessengerKey,
      themeMode: ThemeMode.light,
      theme: MyClubTheme.light,
      home: configured
          ? const AuthGate()
          : const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Klubb setup required.\n'
                    'Run the app with your Supabase credentials.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
    );
  }
}
