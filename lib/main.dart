import 'package:flutter/material.dart';

import 'screens/start_screen.dart';

void main() {
  runApp(const TerritoryWarsApp());
}

class TerritoryWarsApp extends StatelessWidget {
  const TerritoryWarsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Territory Wars',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const StartScreen(),
    );
  }
}
