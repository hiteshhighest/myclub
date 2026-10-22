import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/auth_gate.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      title: 'MyClub',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: MyClubTheme.light,
      darkTheme: MyClubTheme.dark,
      home: configured
          ? const AuthGate()
          : const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'MyClub setup required.\n'
                    'Run the app with your Supabase credentials.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
    );
  }
}
