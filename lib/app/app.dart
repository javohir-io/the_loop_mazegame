import 'package:flutter/material.dart';

import '../menu/main_menu.dart';

class LoopApp extends StatelessWidget {
  const LoopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'THE LOOP',

      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,

        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.white70,
          surface: Color(0xFF101010),
        ),

        useMaterial3: true,
      ),

      home: const MainMenu(),
    );
  }
}