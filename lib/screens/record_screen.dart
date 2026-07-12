// lib/screens/record_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dashboard_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> with WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;

  // Instantiating the Geocoding class engine required by package version 5.0.0+
  final Geocoding _geocoding = Geocoding();

  // Background-Resilient Timer Variables
  bool _isRunning = false;
  bool _isPaused = false;
  int _elapsedSeconds = 0;
  DateTime? _startTime;
  int _previouslyAccumulatedSeconds = 0;
  DateTime? _pauseStartTime;
  Timer? _uiTicker;

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
    WidgetsBinding.instance.addObserver(this); // Register lifecycle listener
    _fetchModules();
    _restoreTimerState(); // Auto-recover state on cold launch or component redraw
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Clean up lifecycle observer
    _uiTicker?.cancel();
    _taskNameController.dispose();
    _durationController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // Intercept phone background transitions, locked screens, and user returns
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isTimerMode || !_isRunning) return;

    if (state == AppLifecycleState.resumed) {
      // User unlocked their phone or returned to the workspace mid-session
      _autoPauseOnReturn();
    }
  }

  // --- Location Tracking Engine ---

  

Future<void> _determineAndSetLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if location hardware services are enabled on the device
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _locationController.text = '');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled. Please enter your location manually.')),
      );
      return;
    }

    // 2. Handle app level workflow permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _locationController.text = '');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied. Please enter your location manually.')),
        );
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _locationController.text = '');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are permanently blocked. Please enter your location manually.')),
      );
      return;
    }

    // 3. Request absolute highest tracking resolution spot
    try {
      if (mounted) setState(() => _locationController.text = 'Locating...');
      
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      // 4. Using the updated v5.0.0 class instance method
      List<Placemark> placemarks = await _geocoding.placemarkFromCoordinates(
        position.latitude, 
        position.longitude
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        
        // --- SMART MULTI-PART ADDRESS BUILDER ---
        List<String> addressParts = [];

        // 1. Get primary street info
        if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
          addressParts.add(place.thoroughfare!);
        } 
        else if (place.name != null && place.name!.isNotEmpty && int.tryParse(place.name!) == null) {
          addressParts.add(place.name!);
        }

        // 2. Add neighborhood or city descriptor
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        } else if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }

        if (mounted) {
          setState(() {
            // Set the built address string, or leave it empty if nothing resolved
            _locationController.text = addressParts.isNotEmpty ? addressParts.join(', ') : '';
          });
        }
      } else {
        if (mounted) setState(() => _locationController.text = '');
      }
    } catch (e) {
      // Clear the loading text if GPS drops out or times out
      if (mounted) setState(() => _locationController.text = '');
    }
  }
  // --- Core Persistent Timer Engine ---

  Future<void> _toggleTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    if (_isRunning) {
      if (_isPaused) {
        // RESUME ACTION
        final pauseDuration = now.difference(_pauseStartTime!);
        final adjustedStartTime = _startTime!.add(pauseDuration);

        await prefs.setBool('timer_is_paused', false);
        await prefs.setString('timer_start_time', adjustedStartTime.toIso8601String());
        await prefs.remove('timer_pause_start_time');

        setState(() {
          _startTime = adjustedStartTime;
          _isPaused = false;
          _pauseStartTime = null;
        });
        _startUiTicker();
      } else {
        // MANUAL PAUSE ACTION
        _uiTicker?.cancel();
        final currentChunk = now.difference(_startTime!).inSeconds;
        final totalSecs = _previouslyAccumulatedSeconds + currentChunk;

        await prefs.setBool('timer_is_paused', true);
        await prefs.setString('timer_pause_start_time', now.toIso8601String());
        await prefs.setInt('timer_accumulated_seconds', totalSecs);

        setState(() {
          _isPaused = true;
          _pauseStartTime = now;
          _elapsedSeconds = totalSecs;
        });
      }
    } else {
      // INITIAL START ACTION
      await prefs.setString('timer_start_time', now.toIso8601String());
      await prefs.setBool('timer_is_running', true);
      await prefs.setBool('timer_is_paused', false);
      await prefs.setInt('timer_accumulated_seconds', 0);
      await prefs.remove('timer_pause_start_time');

      setState(() {
        _startTime = now;
        _isRunning = true;
        _isPaused = false;
        _previouslyAccumulatedSeconds = 0;
        _elapsedSeconds = 0;
        _pauseStartTime = null;
      });
      _startUiTicker();

      // Trigger the single-shot background position fetch concurrently 
      _determineAndSetLocation();
    }
  }

  Future<void> _autoPauseOnReturn() async {
    if (_isPaused || _startTime == null) return;

    _uiTicker?.cancel();
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    final currentChunk = now.difference(_startTime!).inSeconds;
    final totalSecs = _previouslyAccumulatedSeconds + currentChunk;

    await prefs.setBool('timer_is_paused', true);
    await prefs.setString('timer_pause_start_time', now.toIso8601String());
    await prefs.setInt('timer_accumulated_seconds', totalSecs);

    setState(() {
      _isPaused = true;
      _pauseStartTime = now;
      _elapsedSeconds = totalSecs;
    });
  }

  void _startUiTicker() {
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isRunning && !_isPaused && _startTime != null) {
        setState(() {
          _elapsedSeconds = _previouslyAccumulatedSeconds + DateTime.now().difference(_startTime!).inSeconds;
        });
      }
    });
  }

  Future<void> _resetTimer() async {
    _uiTicker?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('timer_start_time');
    await prefs.remove('timer_pause_start_time');
    await prefs.remove('timer_is_running');
    await prefs.remove('timer_is_paused');
    await prefs.remove('timer_accumulated_seconds');

    setState(() {
      _isRunning = false;
      _isPaused = false;
      _elapsedSeconds = 0;
      _startTime = null;
      _previouslyAccumulatedSeconds = 0;
      _pauseStartTime = null;
    });
    _locationController.clear();
  }

  // Recover previous state if app was cleared from memory
  Future<void> _restoreTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isRunning = prefs.getBool('timer_is_running') ?? false;
    if (!isRunning) return;

    final String? startStr = prefs.getString('timer_start_time');
    final String? pauseStr = prefs.getString('timer_pause_start_time');
    final bool isPaused = prefs.getBool('timer_is_paused') ?? false;
    final int accumulated = prefs.getInt('timer_accumulated_seconds') ?? 0;

    if (startStr != null) {
      final restoredStart = DateTime.parse(startStr);
      final restoredPause = pauseStr != null ? DateTime.parse(pauseStr) : null;

      setState(() {
        _isRunning = true;
        _isPaused = isPaused;
        _startTime = restoredStart;
        _pauseStartTime = restoredPause;
        _previouslyAccumulatedSeconds = accumulated;

        if (isPaused) {
          _elapsedSeconds = accumulated;
        } else {
          _elapsedSeconds = accumulated + DateTime.now().difference(restoredStart).inSeconds;
        }
      });

      if (!_isPaused) {
        _startUiTicker();
      }
    }
  }

  // --- Data Infrastructure Tasks ---

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
        syncTasksNotifier.value++;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create tag: $e')));
    }
  }

  
Future<void> _submitSession() async {
    final String taskNameInput = _taskNameController.text.trim();
    final String locationInput = _locationController.text.trim();

    // COMPULSORY VALIDATION CHECKS
    if (taskNameInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please name what you worked on!')));
      return;
    }

    if (locationInput.isEmpty || locationInput == 'Locating...') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location is compulsory! Please type a location or auto-detect your current address.')),
      );
      return;
    }

    int duration = 0;
    if (_isTimerMode) {
      duration = (_elapsedSeconds / 60).round();
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
        'location': locationInput, // Verified clean and present
        'xp_earned': xpEarned,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Session saved! +$xpEarned XP earned.'), backgroundColor: Colors.green));
        await _resetTimer();
        _taskNameController.clear();
        _durationController.clear();
        _locationController.clear();

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
                      onTap: () {
                        if (!_isRunning) setState(() => _isTimerMode = true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: _isTimerMode ? const Color(0xff5732a3) : Colors.transparent, borderRadius: BorderRadius.circular(11)),
                        child: Text('Live Timer', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: _isTimerMode ? Colors.white : Colors.black54)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!_isRunning) setState(() => _isTimerMode = false);
                      },
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      hintText: 'Location (e.g. UTown Library, Home)',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.my_location, color: Color(0xff5732a3)),
                  tooltip: 'Auto-detect location',
                  onPressed: _determineAndSetLocation,
                ),
              ],
            ),
            const SizedBox(height: 40),
            _isTimerMode ? _buildTimerView() : const SizedBox.shrink(),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting || (_isTimerMode && _isRunning && !_isPaused) ? null : _submitSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff5732a3),
                  foregroundColor: Colors.white,
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
    
    int hoursInt = _elapsedSeconds ~/ 3600;
    int minutesInt = (_elapsedSeconds % 3600) ~/ 60;
    int secondsInt = _elapsedSeconds % 60;

    final hours = twoDigits(hoursInt);
    final minutes = twoDigits(minutesInt);
    final seconds = twoDigits(secondsInt);

    Color borderAccentColor = const Color(0xff5732a3);
    if (_isRunning) {
      borderAccentColor = _isPaused ? Colors.orange : const Color(0xffb73229);
    }

    return Column(
      children: [
        Text(
          _isRunning ? (_isPaused ? "⚠️ AUTO-PAUSED" : "Focusing...") : "Ready to Lock In?",
          style: TextStyle(fontSize: 16, color: _isPaused ? Colors.orange : Colors.grey, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          width: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderAccentColor, width: 8),
          ),
          child: Center(
            child: Text('$hours:$minutes:$seconds', style: const TextStyle(fontSize: 35, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_elapsedSeconds > 0) 
              IconButton(
                icon: const Icon(Icons.replay, size: 32, color: Colors.grey), 
                onPressed: _resetTimer
              ),
            const SizedBox(width: 20),
            ElevatedButton.icon(
              onPressed: _toggleTimer,
              icon: Icon(_isRunning ? (_isPaused ? Icons.play_arrow : Icons.pause) : Icons.play_arrow, color: Colors.white),
              label: Text(
                _isRunning 
                    ? (_isPaused ? 'Resume' : 'Pause') 
                    : (_elapsedSeconds == 0 ? 'Start Focus' : 'Resume'), 
                style: const TextStyle(fontSize: 16)
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRunning ? (_isPaused ? Colors.green : Colors.orange) : const Color(0xff5732a3),
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