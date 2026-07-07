// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart'; // Safe import to handle sign out navigation route

// Imports Jeevan's syncProfileNotifier  
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  // Merged State Variables
  List<dynamic> _myHistory = [];
  List<Map<String, dynamic>> _modules = [];
  bool _isLoading = true;
  int _totalXp = 0;
  int _currentStreak = 0;
  String _username = "Loading...";
  int _followerCount = 0;
  int _followingCount = 0;

  // Calendar Variables
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _sessionsByDay = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileDetails();
    _fetchModules();
    syncProfileNotifier.addListener(_loadProfileDetails);
  }

  @override
  void dispose() {
    _tabController.dispose();
    syncProfileNotifier.removeListener(_loadProfileDetails);
    super.dispose();
  }

  // --- CORE DATA FETCHING ---
  Future<void> _loadProfileDetails() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final profileData = await _supabase.from('profiles').select('username').eq('id', currentUserId).maybeSingle();
      if (profileData != null) _username = profileData['username'] ?? 'User';

      final followersData = await _supabase.from('follows').select('id').eq('following_id', currentUserId);
      final followingData = await _supabase.from('follows').select('id').eq('follower_id', currentUserId);

      final response = await _supabase
          .from('study_sessions')
          .select('*')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      int xpCounter = 0;
      Set<String> uniqueDates = {};
      Map<DateTime, List<dynamic>> groupedSessions = {};

      for (var rawRow in response) {
        final row = rawRow as Map<String, dynamic>;
        xpCounter += (row['xp_earned'] as num?)?.toInt() ?? 0;
        if (row['created_at'] != null) {
          DateTime date = DateTime.parse(row['created_at'].toString()).toLocal();
          DateTime cleanDate = DateTime(date.year, date.month, date.day);

          uniqueDates.add("${date.year}-${date.month}-${date.day}");

          if (groupedSessions[cleanDate] == null) groupedSessions[cleanDate] = [];
          groupedSessions[cleanDate]!.add(row);
        }
      }

      if (mounted) {
        setState(() {
          _myHistory = response;
          _totalXp = xpCounter;
          _followerCount = followersData.length;
          _followingCount = followingData.length;
          _sessionsByDay = groupedSessions;
          _currentStreak = _calculateStreak(uniqueDates);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Profile metrics load issue: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchModules() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase.from('task_modules').select().eq('user_id', user.id);
        if (mounted) setState(() => _modules = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      print('Error fetching modules: $e');
    }
  }

  int _calculateStreak(Set<String> uniqueDates) {
    int streak = 0;
    DateTime checkDate = DateTime.now();

    while (true) {
      String checkStr = "${checkDate.year}-${checkDate.month}-${checkDate.day}";
      if (uniqueDates.contains(checkStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        if (streak == 0) {
          DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
          String yestStr = "${yesterday.year}-${yesterday.month}-${yesterday.day}";
          if (uniqueDates.contains(yestStr)) {
            checkDate = yesterday;
            continue;
          }
        }
        break;
      }
    }
    return streak;
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    DateTime cleanDay = DateTime(day.year, day.month, day.day);
    return _sessionsByDay[cleanDay] ?? [];
  }

  // --- EDIT & DELETE LOGIC WITH EXPLICIT AWAIT AND SELECT ---
  Future<void> _updateSession(dynamic id, String subject, int duration, String location) async {
    try {
      final response = await _supabase.from('study_sessions').update({
        'subject': subject,
        'duration_minutes': duration,
        'location': location,
        'xp_earned': duration * 2,
      }).eq('id', id).select();

      if (response.isEmpty) {
        throw Exception("Database blocked the update. Missing RLS Update policy!");
      }
      await _loadProfileDetails();
      syncFeedNotifier.value++;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session Updated!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteSession(dynamic id) async {
    try {
      final response = await _supabase.from('study_sessions').delete().eq('id', id).select();
      if (response.isEmpty) {
        throw Exception("Database blocked the deletion. Missing RLS Delete policy!");
      }

      await _loadProfileDetails();
      syncFeedNotifier.value++;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session Deleted.'), backgroundColor: Colors.grey));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _showEditDialog(dynamic rawSession) {
    final session = rawSession as Map<String, dynamic>;
    final sessionId = session['id'];
    String rawSubject = session['subject']?.toString() ?? '';
    String initialTaskName = rawSubject;
    String? initialSelectedModule;

    if (rawSubject.contains('(') && rawSubject.endsWith(')')) {
      int openParen = rawSubject.lastIndexOf('(');
      initialTaskName = rawSubject.substring(0, openParen).trim();
      String tagName = rawSubject.substring(openParen + 1, rawSubject.length - 1).trim();
      try {
        initialSelectedModule = _modules.firstWhere((m) => m['name'] == tagName)['id'].toString();
      } catch (e) {
        initialSelectedModule = null;
      }
    }

    final taskNameController = TextEditingController(text: initialTaskName);
    final durationController = TextEditingController(text: session['duration_minutes']?.toString() ?? '0');
    final locationController = TextEditingController(text: session['location']?.toString() ?? '');
    String? selectedModuleId = initialSelectedModule;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Edit Session', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: taskNameController, decoration: const InputDecoration(labelText: 'Task Name', hintText: 'e.g. Tutorial 3')),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('Add/Change Tag...'),
                        value: selectedModuleId,
                        items: _modules.map((m) => DropdownMenuItem(value: m['id'].toString(), child: Text(m['name'].toString()))).toList(),
                        onChanged: (val) => setModalState(() => selectedModuleId = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: durationController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (Minutes)')),
                  const SizedBox(height: 10),
                  TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location')),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _deleteSession(sessionId);
                },
                child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff5732a3), foregroundColor: Colors.white),
                onPressed: () async {
                  final newDuration = int.tryParse(durationController.text) ?? 0;
                  if (taskNameController.text.isNotEmpty && newDuration > 0) {
                    String finalSubject = taskNameController.text.trim();
                    if (selectedModuleId != null) {
                      String modName = _modules.firstWhere((m) => m['id'].toString() == selectedModuleId)['name'].toString();
                      finalSubject = '$finalSubject ($modName)';
                    }
                    Navigator.pop(ctx);
                    await _updateSession(sessionId, finalSubject, newDuration, locationController.text);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        }
      ),
    );
  }

  Color _getColorForModule(String moduleName) {
    final colors = [
      const Color(0xff5732a3),
      Colors.blueAccent,
      Colors.teal,
      Colors.orange,
      Colors.pinkAccent,
      Colors.redAccent,
      Colors.indigo,
      const Color(0xff2d4059)
    ];
    int hash = moduleName.hashCode;
    return colors[hash.abs() % colors.length];
  }

  /// Logs the user out securely from Supabase and wipes the navigation stack back to login screen
  Future<void> _handleLogout() async {
    try {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- UI BUILDERS ---
  @override
  Widget build(BuildContext context) {
    final userEmail = _supabase.auth.currentUser?.email ?? 'User Account';

    return Scaffold(
      backgroundColor: const Color(0xfff8f9fa),
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xff5732a3),
        elevation: 0,
        automaticallyImplyLeading: false, // Prevents default back navigation arrows
        actions: [
          // Clear white logout icon added cleanly as an AppBar option
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white), // Explicit color so it's fully visible on purple background
            tooltip: 'Log Out',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xff5732a3)))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xff5732a3),
                  padding: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                  child: Column(
                    children: [
                      const CircleAvatar(radius: 36, backgroundColor: Colors.white, child: Icon(Icons.person, size: 40, color: Color(0xff5732a3))),
                      const SizedBox(height: 10),
                      Text('@$_username', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(userEmail, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$_followerCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const Text(' Followers', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(width: 24),
                          Text('$_followingCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const Text(' Following', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text('$_totalXp', style: const TextStyle(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold)),
                              const Text('TOTAL XP', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Container(width: 1, height: 24, color: Colors.white24),
                          Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 20),
                                  Text('$_currentStreak', style: const TextStyle(color: Colors.orangeAccent, fontSize: 22, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Text('DAY STREAK', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xff5732a3),
                    unselectedLabelColor: Colors.black54,
                    indicatorColor: const Color(0xff5732a3),
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(icon: Icon(Icons.calendar_month), text: "Calendar"),
                      Tab(icon: Icon(Icons.history), text: "History Log"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInteractiveCalendarTab(),
                      _myHistory.isEmpty
                          ? const Center(child: Text('No study history recorded.', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _myHistory.length,
                              itemBuilder: (context, index) {
                                return _buildActivityItem(_myHistory[index]);
                              },
                            ),
                    ],
                  ),
                )
              ],
            ),
    );
  }

  Widget _buildInteractiveCalendarTab() {
    final selectedEvents = _getEventsForDay(_selectedDay ?? _focusedDay);
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: TableCalendar(
              firstDay: DateTime.utc(2023, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              eventLoader: _getEventsForDay,
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(color: const Color(0xff5732a3).withOpacity(0.3), shape: BoxShape.circle),
                selectedDecoration: const BoxDecoration(color: Color(0xff5732a3), shape: BoxShape.circle),
                markerDecoration: const BoxDecoration(color: Color(0xffb73229), shape: BoxShape.circle),
              ),
              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
            ),
          ),
          if (selectedEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text("No sessions on this day.", style: TextStyle(color: Colors.grey))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: selectedEvents.length,
              itemBuilder: (context, index) {
                return _buildActivityItem(selectedEvents[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(dynamic rawSession) {
    final session = rawSession as Map<String, dynamic>;
    final subjectFull = session['subject']?.toString() ?? 'Unknown Task';
    String taskName = subjectFull;
    String moduleName = '';
    if (subjectFull.contains('(') && subjectFull.endsWith(')')) {
      int openParen = subjectFull.lastIndexOf('(');
      taskName = subjectFull.substring(0, openParen).trim();
      moduleName = subjectFull.substring(openParen + 1, subjectFull.length - 1).trim();
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
      child: ListTile(
        leading: const Icon(Icons.history, color: Colors.grey),
        title: Row(
          children: [
            Text(taskName, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (moduleName.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getColorForModule(moduleName).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _getColorForModule(moduleName), width: 1),
                ),
                child: Text(moduleName, style: TextStyle(color: _getColorForModule(moduleName), fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ]
          ],
        ),
        subtitle: Text('${session['duration_minutes']} mins at ${session['location']}'),
        trailing: Text('+${session['xp_earned']} XP', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        onTap: () => _showEditDialog(session),
      ),
    );
  }
}