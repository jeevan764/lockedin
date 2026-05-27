// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 1. Import the package
import 'screens/welcome_screen.dart';

void main() async {
  // 2. Ensure Flutter bindings are ready for async operations
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Initialize Supabase with your unique credentials
  await Supabase.initialize(
    url: 'https://wqihmyuspsgumjjwzvoy.supabase.co/rest/v1/',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndxaWhteXVzcHNndW1qand6dm95Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk4ODM4MTIsImV4cCI6MjA5NTQ1OTgxMn0.t-vcY87uEWvRJx1rsw5EM_Up1RmNgeLiQz3rXf4TO2Y',
  );

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