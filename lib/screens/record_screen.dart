// lib/screens/record_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _supabase = Supabase.instance.client;
  
  // Tag Fetching State
  List<Map<String, dynamic>> _modules = [];
  String? _selectedModuleId;
  String? _selectedModuleName;
  bool _isLoadingModules = true;

  // View Toggle State
  bool _isTimerMode = true;
  
  // Inputs State
  final _taskNameController = TextEditingController(); // NEW: Task Name Input
  final _durationController = TextEditingController();
  final _locationController = TextEditingController();

  // Live Timer State
  Duration _accumulatedTime = Duration.zero;
  DateTime? _lastStartTime;
  Timer? _uiTimer;
  bool _isRunning = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchModules();
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _taskNameController.dispose();
    _durationController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // --- BACKGROUND-SAFE TIMER LOGIC ---
  void _toggleTimer() {
    setState(() {
      if (_isRunning) {
        _uiTimer?.cancel();
        if (_lastStartTime != null) {
          _accumulatedTime += DateTime.now().difference(_lastStartTime!);
        }
        _isRunning = false;
      } else {
        _lastStartTime = DateTime.now();
        _isRunning = true;
        _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
      }
    });
  }

  Duration get _currentElapsed {
    if (!_isRunning || _lastStartTime == null) return _accumulatedTime;
    return _accumulatedTime + DateTime.now().difference(_lastStartTime!);
  }

  void _resetTimer() {
    setState(() {
      _uiTimer?.cancel();
      _isRunning = false;
      _accumulatedTime = Duration.zero;
      _lastStartTime = null;
    });
  }

  // --- DATABASE LOGIC ---
  Future<void> _fetchModules() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase.from('task_modules').select().eq('user_id', user.id);
        setState(() {
          _modules = List<Map<String, dynamic>>.from(data);
          _isLoadingModules = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingModules = false);
    }
  }

  Future<void> _createNewTag(String name) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      final response = await _supabase.from('task_modules').insert({
        'user_id': user.id,
        'name': name,
        'color_hex': '0xff5732a3', 
      }).select().single();

      setState(() {
        _modules.add(response);
        _selectedModuleId = response['id'];
        _selectedModuleName = response['name'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create tag: $e')));
    }
  }

  Future<void> _submitSession() async {
    // Validation Checks
    if (_taskNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please name your task.'), backgroundColor: Colors.orange));
      return;
    }
    
    if (_selectedModuleName == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a module tag.'), backgroundColor: Colors.orange));
      return;
    }

    int durationMins = 0;
    if (_isTimerMode) {
      durationMins = _currentElapsed.inMinutes;
      if (durationMins < 1) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Study for at least 1 minute to save!'), backgroundColor: Colors.orange));
        return;
      }
    } else {
      durationMins = int.tryParse(_durationController.text) ?? 0;
      if (durationMins <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid duration.'), backgroundColor: Colors.orange));
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _supabase.auth.currentUser;
      final location = _locationController.text.trim().isEmpty ? 'Campus' : _locationController.text.trim();
      final xp = durationMins * 2;

      // COMBINING THE TASK NAME AND MODULE TAG FOR SUPABASE
      final combinedSubject = '${_taskNameController.text.trim()} ($_selectedModuleName)';

      await _supabase.from('study_sessions').insert({
        'user_id': user!.id,
        'subject': combinedSubject, 
        'duration_minutes': durationMins,
        'location': location,
        'xp_earned': xp,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session Logged Successfully!'), backgroundColor: Colors.green));
        if (_isTimerMode) _resetTimer();
        _taskNameController.clear();
        _durationController.clear();
        _locationController.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- UI BUILDERS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Record Activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xff5732a3),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Mode Toggle
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isTimerMode = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: _isTimerMode ? const Color(0xff5732a3) : Colors.transparent, borderRadius: BorderRadius.circular(11)),
                        child: Text('Live Timer', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: _isTimerMode ? Colors.white : Colors.black54)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isTimerMode = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: !_isTimerMode ? const Color(0xff5732a3) : Colors.transparent, borderRadius: BorderRadius.circular(11)),
                        child: Text('Manual Entry', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: !_isTimerMode ? Colors.white : Colors.black54)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // NEW: Task Name Input
            TextField(
              controller: _taskNameController,
              decoration: InputDecoration(
                hintText: 'What are you working on? (e.g. Tutorial 3)',
                filled: true, fillColor: Colors.white,
                prefixIcon: const Icon(Icons.edit_note, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // Dynamic Tag Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
              child: _isLoadingModules 
                ? const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('Choose Module Tag...', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: _selectedModuleId,
                      items: [
                        ..._modules.map((m) => DropdownMenuItem(value: m['id'].toString(), child: Text(m['name']))).toList(),
                        const DropdownMenuItem(value: 'ADD_NEW', child: Text('+ Add New Tag', style: TextStyle(color: Color(0xffb73229), fontWeight: FontWeight.bold))),
                      ],
                      onChanged: (val) {
                        if (val == 'ADD_NEW') {
                          _showAddTagDialog();
                        } else {
                          setState(() {
                            _selectedModuleId = val;
                            _selectedModuleName = _modules.firstWhere((m) => m['id'] == val)['name'];
                          });
                        }
                      },
                    ),
                  ),
            ),
            const SizedBox(height: 30),

            // Dynamic View (Timer OR Manual Input)
            if (_isTimerMode) _buildTimerView() else _buildManualView(),

            const SizedBox(height: 30),

            // Location Input
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Location (e.g. UTown Starbucks)',
                filled: true, fillColor: Colors.white,
                prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 30),

            // Submit Button
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting || (_isTimerMode && _isRunning) ? null : _submitSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff5732a3), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerView() {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(_currentElapsed.inHours);
    final minutes = twoDigits(_currentElapsed.inMinutes.remainder(60));
    final seconds = twoDigits(_currentElapsed.inSeconds.remainder(60));

    return Column(
      children: [
        Container(
          height: 200, width: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _isRunning ? const Color(0xffb73229) : const Color(0xff5732a3), width: 8),
          ),
          child: Center(
            child: Text('$hours:$minutes:$seconds', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_accumulatedTime > Duration.zero && !_isRunning)
               IconButton(icon: const Icon(Icons.replay, size: 32, color: Colors.grey), onPressed: _resetTimer),
            const SizedBox(width: 20),
            ElevatedButton.icon(
              onPressed: _toggleTimer,
              icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow, color: Colors.white),
              label: Text(_isRunning ? 'Pause' : (_accumulatedTime == Duration.zero ? 'Start Focus' : 'Resume'), style: const TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRunning ? Colors.orange : const Color(0xff5732a3),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildManualView() {
    return TextField(
      controller: _durationController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: 'Duration in Minutes (e.g. 120)',
        filled: true, fillColor: Colors.white,
        prefixIcon: const Icon(Icons.timer_outlined, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  void _showAddTagDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Tag'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. CS2040S')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _createNewTag(controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}