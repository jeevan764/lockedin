// lib/main.dart
import 'package:flutter/material.dart';
// This line imports your welcome screen file from your screens folder
import 'package:lockedin/screens/welcome_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Removes the red debug banner from the emulator
      title: 'LockedIn',
      theme: ThemeData(
        useMaterial3: true,
        // Fixed the colorScheme syntax and set a clean purple base theme
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff5732a3)),
      ),
      // Changed this from MyHomePage to your WelcomeScreen!
      home: const WelcomeScreen(), 
    );
  }
}