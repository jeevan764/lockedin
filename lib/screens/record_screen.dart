// lib/screens/record_screen.dart
import 'dart:async';
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

  // Timer Variables
  Timer? _uiTimer;
  bool _isRunning = false;
  Duration _accumulatedTime = Duration.zero;
  DateTime? _lastStartTime;

  // Form Inputs
  bool _isTimerMode = true;
  final _taskNameController = TextEditingController();
  final _durationController = TextEditingController();
  final _locationController = TextEditingController();

  // Workspace Tags Data
  List<Map<String, dynamic>> _modules = [];
  bool _isLoadingModules = true;
  String? _selectedModuleId;
  String? _selectedModuleName;
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

  Future<void> _fetchModules() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase.from('task_modules').select().eq('user_id', user.id);
        if (mounted) {
          setState(() {
            _modules = List<Map<String, dynamic>>.from(data);
            _isLoadingModules = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingModules = false);
    }
  }

  Future<void> _createNewTag(String name, Color chosenColor) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      final String hexString = '0x${chosenColor.value.toRadixString(16)}';

      final response = await _supabase.from('task_modules').insert({
        'user_id': user.id,
        'name': name,
        'color_hex': hexString,
      }).select().single();

      if (mounted) {
        setState(() {
          _modules.add(response);
          _selectedModuleId = response['id'].toString();
          _selectedModuleName = response['name'];
        });
        syncTasksNotifier.value++; // Signal Tasks page to refresh right away
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create tag: $e')));
    }
  }

  Future<void> _submitSession() async {
    final String taskNameInput = _taskNameController.text.trim();
    final String locationInput = _locationController.text.trim().isEmpty ? 'Campus' : _locationController.text.trim();

    if (taskNameInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please name what you worked on!')));
      return;
    }

    int duration = 0;
    if (_isTimerMode) {
      duration = _currentElapsed.inMinutes;
      if (duration < 1) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Focus session must be at least 1 minute long.')));
        return;
      }
    } else {
      duration = int.tryParse(_durationController.text.trim()) ?? 0;
      if (duration <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please input a valid manual duration.')));
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      String finalSubjectTitle = taskNameInput;
      if (_selectedModuleName != null && _selectedModuleName!.isNotEmpty) {
        finalSubjectTitle = '$taskNameInput ($_selectedModuleName)';
      }

      int xpEarned = duration * 10;

      await _supabase.from('study_sessions').insert({
        'user_id': user.id,
        'subject': finalSubjectTitle,
        'duration_minutes': duration,
        'location': locationInput,
        'xp_earned': xpEarned,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Session saved! +$xpEarned XP earned.'), backgroundColor: Colors.green));
        _resetTimer();
        _taskNameController.clear();
        _durationController.clear();
        _locationController.clear();

        // Broadcast payloads
        syncFeedNotifier.value++;
        syncProfileNotifier.value++;
        syncTasksNotifier.value++;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Color _getColorForModule(String moduleName) {
    try {
      final match = _modules.firstWhere((m) => m['name'].toString().toLowerCase() == moduleName.toLowerCase());
      if (match['color_hex'] != null) {
        return Color(int.parse(match['color_hex'].toString()));
      }
    } catch (_) {}
    int hash = moduleName.hashCode;
    final colors = [const Color(0xff5732a3), Colors.blueAccent, Colors.teal, Colors.orange, Colors.pinkAccent, Colors.redAccent, Colors.indigo, const Color(0xff2d4059)];
    return colors[hash.abs() % colors.length];
  }

  void _showCreateTagDialog() {
    final TextEditingController tagController = TextEditingController();
    Color chosenColor = const Color(0xff5732a3);
    
    final List<Color> palette = [
      const Color(0xff5732a3),
      Colors.blueAccent,
      Colors.teal,
      Colors.orange,
      Colors.pinkAccent,
      Colors.redAccent,
      Colors.indigo,
      const Color(0xff2d4059),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Create New Tag', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tagController,
                  decoration: const InputDecoration(hintText: 'e.g. CS2103T'),
                  autofocus: true,
                ),
                const SizedBox(height: 20),
                const Align(alignment: Alignment.centerLeft, child: Text('Select Tag Color:', style: TextStyle(color: Colors.grey, fontSize: 13))),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: palette.map((color) {
                    final bool isSelected = chosenColor == color;
                    return GestureDetector(
                      onTap: () => setModalState(() => chosenColor = color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                      ),
                    );
                  }).toList(),
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              TextButton(
                onPressed: () {
                  if (tagController.text.trim().isNotEmpty) {
                    _createNewTag(tagController.text.trim(), chosenColor);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Create', style: TextStyle(color: Color(0xff5732a3), fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

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
            TextField(
              controller: _taskNameController,
              decoration: InputDecoration(
                hintText: 'What are you working on? (e.g. Tutorial 3)',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.edit_note, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            _isLoadingModules
                ? const LinearProgressIndicator()
                : Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: const Text('Select Subject Tag (Optional)'),
                              value: _selectedModuleId,
                              items: _modules.map((m) {
                                return DropdownMenuItem<String>(
                                  value: m['id'].toString(),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        margin: const EdgeInsets.only(right: 10),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _getColorForModule(m['name'].toString()),
                                        ),
                                      ),
                                      Text(m['name'].toString()),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedModuleId = val;
                                  _selectedModuleName = _modules.firstWhere((m) => m['id'].toString() == val)['name'];
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      if (_selectedModuleId != null)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () => setState(() {
                            _selectedModuleId = null;
                            _selectedModuleName = null;
                          }),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.create_new_folder, color: Color(0xff5732a3), size: 28),
                        onPressed: _showCreateTagDialog,
                      ),
                    ],
                  ),
            const SizedBox(height: 16),
            if (!_isTimerMode) ...[
              TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Duration (Minutes)',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.timer_outlined, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Location (e.g. UTown Library, Home)',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 40),
            _isTimerMode ? _buildTimerView() : const SizedBox.shrink(),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting || (_isTimerMode && _isRunning) ? null : _submitSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff5732a3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          height: 200,
          width: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _isRunning ? const Color(0xffb73229) : const Color(0xff5732a3), width: 8),
          ),
          child: Center(
            child: Text('$hours:$minutes:$seconds', style: const TextStyle(fontSize: 35, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_accumulatedTime > Duration.zero && !_isRunning) IconButton(icon: const Icon(Icons.replay, size: 32, color: Colors.grey), onPressed: _resetTimer),
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
        ),
      ],
    );
  }
}