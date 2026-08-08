import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/start_screen.dart';
import 'services/player_service.dart';

Future<void> main() async {
  // Firebase needs the bindings up before it can initialize.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Every player gets an anonymous account so they have a stable id without
  // signing up for anything. If it fails (no network, say) the app still opens
  // and the start screen reports the problem when it tries to save.
  final playerService = PlayerService();
  try {
    final uid = await playerService.signIn();
    debugPrint('Signed in anonymously as $uid');
  } catch (e) {
    debugPrint('Anonymous sign-in failed: $e');
  }

  runApp(TerritoryWarsApp(playerService: playerService));
}

class TerritoryWarsApp extends StatelessWidget {
  const TerritoryWarsApp({super.key, this.playerService});

  // Null in widget tests, where there's no Firebase to talk to.
  final PlayerService? playerService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Territory Wars',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: StartScreen(playerService: playerService),
    );
  }
}
