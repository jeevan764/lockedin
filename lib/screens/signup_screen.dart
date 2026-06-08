// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart'; // Loads your persistent 4-tab dashboard view

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // Input tracking text controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    // 1. Core input parameter validation checks
    if (email.isEmpty || username.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in all fields', Colors.orange);
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _showSnackBar('Please enter a valid email address', Colors.orange);
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Register account parameters inside secure Supabase Auth ledger
      final AuthResponse response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user != null) {
        // 3. Map custom plaintext handle into the public profiles relational table
        await Supabase.instance.client.from('profiles').insert({
          'id': user.id, // Foreign Key bound to secure user account token ID
          'username': username,
        });

        if (mounted) {
          _showSnackBar('Account created successfully!', Colors.green);
          
          // 4. CLEAR stack memory and route user straight into the main tasks screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      }
    } on AuthException catch (error) {
      _showSnackBar(error.message, Colors.red);
    } catch (error) {
      // Catch-all debug point showcasing explicit PostgreSQL anomalies if they occur
      _showSnackBar('Database Error: ${error.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xff8b6bf0), // Radial highlight
              Color(0xff5732a3), // Deep purple match
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // Back navigation threshold asset
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  const Text(
                    'Create Account',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign up to get started tracking tasks',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  
                  const SizedBox(height: 30),

                  // Real Email Input Field
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Email Address',
                      hintStyle: const TextStyle(color: Colors.white60),
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // Public Custom Username Input Field
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Username',
                      hintStyle: const TextStyle(color: Colors.white60),
                      prefixIcon: const Icon(Icons.person_outline, color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // Password Input Field
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _isLoading ? null : _handleSignup(),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: const TextStyle(color: Colors.white60),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  // Register Action Trigger Primary Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xff222222),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: Color(0xff222222), strokeWidth: 2.5),
                            )
                          : const Text(
                              'Sign Up',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}