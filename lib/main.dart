// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/welcome_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://wqihmyuspsgumjjwzvoy.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndxaWhteXVzcHNndW1qand6dm95Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk4ODM4MTIsImV4cCI6MjA5NTQ1OTgxMn0.t-vcY87uEWvRJx1rsw5EM_Up1RmNgeLiQz3rXf4TO2Y',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LockedIn',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff5732a3)),
      ),
      // Use AuthGate to safely control session routing
      home: const AuthGate(), 
    );
  }
}

/// Safely handles the authentication persistence routing without letting
/// arbitrary database exceptions trigger unexpected sign-outs.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _supabase = Supabase.instance.client;
  bool _checkingAuth = true;
  Session? _currentSession;

  @override
  void initState() {
    super.initState();
    _initializeAuthCheck();
  }

  void _initializeAuthCheck() {
    // 1. Check initial active session status
    _currentSession = _supabase.auth.currentSession;
    if (mounted) {
      setState(() => _checkingAuth = false);
    }

    // 2. Setup structural listener that ONLY logs out if an explicit 
    // AuthChangeEvent.signedOut is fired by a user clicking a logout button.
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedOut || session == null) {
        if (mounted) {
          setState(() {
            _currentSession = null;
            _checkingAuth = false;
          });
        }
      } else if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession) {
        if (mounted) {
          setState(() {
            _currentSession = session;
            _checkingAuth = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xff5732a3)),
        ),
      );
    }

    // Secure routing boundary
    return _currentSession != null ? const DashboardScreen() : const WelcomeScreen();
  }
}