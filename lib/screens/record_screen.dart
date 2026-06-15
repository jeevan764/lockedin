// lib/screens/record_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _supabase = Supabase.instance.client;
  final _subjectController = TextEditingController();
  final _durationController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _durationController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submitSession() async {
    final subject = _subjectController.text.trim();
    final durationText = _durationController.text.trim();
    final location = _locationController.text.trim();

    if (subject.isEmpty || durationText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a subject and duration'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User session missing');

      final durationMins = int.tryParse(durationText) ?? 0;
      final xp = durationMins * 2; 

      await _supabase.from('study_sessions').insert({
        'user_id': user.id,
        'subject': subject,
        'duration_minutes': durationMins,
        'location': location.isEmpty ? 'NUS Central Library' : location, 
        'xp_earned': xp,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session Recorded Successfully!'), backgroundColor: Colors.green),
        );
        _subjectController.clear();
        _durationController.clear();
        _locationController.clear();

        // Send instant notification broadcast payload
        syncFeedNotifier.value++;
        syncProfileNotifier.value++;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Log Study Session', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xff5732a3),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What did you focus on?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _subjectController,
              decoration: InputDecoration(
                hintText: 'e.g. Linear Algebra (MA1512)',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12, width: 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12, width: 1.0),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            const Text('Duration (Minutes)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g. 120',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12, width: 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12, width: 1.0),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'e.g. UTown Starbucks',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12, width: 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12, width: 1.0),
                ),
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff5732a3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Record Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}