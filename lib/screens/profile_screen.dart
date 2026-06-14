// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  String _username = "Loading...";
  String _email = "Loading...";
  bool _isLoadingProfile = true;
  
  List<dynamic> _allSessions = [];
  bool _isLoadingSessions = true;

  // NEW: State variable to hold your tags
  List<Map<String, dynamic>> _modules = [];

  // Analytics Variables
  double _totalFocusHours = 0;
  int _currentStreak = 0;

  // Calendar Variables
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _sessionsByDay = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchUserProfile();
    _fetchUserSessions(); 
    _fetchModules(); // NEW: Fetch the tags when profile loads
  }

  Future<void> _fetchUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase.from('profiles').select('username, email').eq('id', user.id).single();
        setState(() {
          _username = data['username'] ?? 'LockedIn User';
          _email = data['email'] ?? user.email ?? '';
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _fetchUserSessions() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('study_sessions')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false);

        _processAnalytics(response);

        setState(() {
          _allSessions = response;
          _isLoadingSessions = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingSessions = false);
    }
  }

  // NEW: Fetch modules to populate the dropdown in the edit dialog
  Future<void> _fetchModules() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase.from('task_modules').select().eq('user_id', user.id);
        if (mounted) {
          setState(() {
            _modules = List<Map<String, dynamic>>.from(data);
          });
        }
      }
    } catch (e) {
      print('Error fetching modules: $e');
    }
  }

  void _processAnalytics(List<dynamic> sessions) {
    double totalMins = 0;
    Map<DateTime, int> dailyMinutesMap = {};
    Map<DateTime, List<dynamic>> groupedSessions = {};

    for (var session in sessions) {
      if (session['created_at'] == null) continue;
      
      int duration = session['duration_minutes'] ?? 0;
      totalMins += duration;

      DateTime rawDate = DateTime.parse(session['created_at']).toLocal();
      DateTime cleanDate = DateTime(rawDate.year, rawDate.month, rawDate.day);

      dailyMinutesMap[cleanDate] = (dailyMinutesMap[cleanDate] ?? 0) + duration;

      if (groupedSessions[cleanDate] == null) groupedSessions[cleanDate] = [];
      groupedSessions[cleanDate]!.add(session);
    }

    int streak = 0;
    DateTime checkDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    if ((dailyMinutesMap[checkDate] ?? 0) < 30) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    while ((dailyMinutesMap[checkDate] ?? 0) >= 30) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    setState(() {
      _totalFocusHours = totalMins / 60.0;
      _currentStreak = streak;
      _sessionsByDay = groupedSessions;
    });
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    DateTime cleanDay = DateTime(day.year, day.month, day.day);
    return _sessionsByDay[cleanDay] ?? [];
  }

  Future<void> _updateSession(String id, String subject, int duration, String location) async {
    try {
      await _supabase.from('study_sessions').update({
        'subject': subject,
        'duration_minutes': duration,
        'location': location,
        'xp_earned': duration * 2,
      }).eq('id', id);
      
      _fetchUserSessions(); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session Updated!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteSession(String id) async {
    try {
      await _supabase.from('study_sessions').delete().eq('id', id);
      _fetchUserSessions(); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session Deleted.'), backgroundColor: Colors.grey));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red));
    }
  }

  // --- UPDATED: EDIT DIALOG WITH DROPDOWN ---
  void _showEditDialog(Map<String, dynamic> session) {
    String rawSubject = session['subject'] ?? '';
    String initialTaskName = rawSubject;
    String? initialSelectedModule;

    // Smart logic: If the session already has a tag formatted like "Task (Tag)", extract it
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
    final durationController = TextEditingController(text: session['duration_minutes'].toString());
    final locationController = TextEditingController(text: session['location']);
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
                  TextField(
                    controller: taskNameController,
                    decoration: const InputDecoration(labelText: 'Task Name', hintText: 'e.g. Tutorial 3'),
                  ),
                  const SizedBox(height: 16),
                  
                  // NEW: Dynamic Tag Dropdown for editing
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('Add/Change Tag...'),
                        value: selectedModuleId,
                        items: _modules.map((m) => DropdownMenuItem(value: m['id'].toString(), child: Text(m['name']))).toList(),
                        onChanged: (val) {
                          setModalState(() => selectedModuleId = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Duration (Minutes)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteSession(session['id']);
                },
                child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff5732a3), foregroundColor: Colors.white),
                onPressed: () {
                  final newDuration = int.tryParse(durationController.text) ?? 0;
                  if (taskNameController.text.isNotEmpty && newDuration > 0) {
                    
                    // Recombine the Task Name and Tag back into the formatted string
                    String finalSubject = taskNameController.text.trim();
                    if (selectedModuleId != null) {
                       String modName = _modules.firstWhere((m) => m['id'].toString() == selectedModuleId)['name'];
                       finalSubject = '$finalSubject ($modName)';
                    }
                    
                    _updateSession(session['id'], finalSubject, newDuration, locationController.text);
                    Navigator.pop(ctx);
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
  // --------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) return const Center(child: CircularProgressIndicator(color: Color(0xff5732a3)));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xfff8f9fa),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 180.0, floating: false, pinned: true, backgroundColor: const Color(0xff5732a3), elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    padding: const EdgeInsets.only(top: 35.0), color: const Color(0xff5732a3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            const SizedBox(width: 84, height: 84, child: CircularProgressIndicator(value: 0.74, strokeWidth: 5, backgroundColor: Colors.white24, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                            const CircleAvatar(radius: 35, backgroundColor: Color(0xfff1edfa), child: Icon(Icons.school, size: 32, color: Color(0xff5732a3))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(_username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(_email, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w400)),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  const TabBar(
                    labelColor: Color(0xff5732a3), unselectedLabelColor: Colors.black38, indicatorColor: Color(0xff5732a3), indicatorSize: TabBarIndicatorSize.label,
                    tabs: [Tab(icon: Icon(Icons.analytics_outlined), text: "Overview"), Tab(icon: Icon(Icons.calendar_month_outlined), text: "Calendar")],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(children: [_buildOverviewTab(), _buildCalendarTab()]),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Performance Analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.4,
            children: [
              _buildMetricCard('Current Streak', '$_currentStreak Days', Icons.local_fire_department, Colors.orange),
              _buildMetricCard('Focus Hours', '${_totalFocusHours.toStringAsFixed(1)} hrs', Icons.timer_outlined, Colors.blue),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Recent Sessions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          if (_isLoadingSessions)
            const Center(child: CircularProgressIndicator(color: Color(0xff5732a3)))
          else if (_allSessions.isEmpty)
            const Text('No logged sessions yet. Get to work!', style: TextStyle(color: Colors.grey))
          else
            ..._allSessions.take(5).map((session) {
              final subject = session['subject'] ?? 'Unknown';
              final durationMins = session['duration_minutes'] ?? 0;
              final durationStr = durationMins >= 60 ? '${(durationMins / 60).toStringAsFixed(1)} hrs' : '$durationMins mins';
              return _buildActivityItem(session, subject, durationStr, DateFormat('MMM d, h:mm a').format(DateTime.parse(session['created_at']).toLocal()));
            }),
            
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 48,
            child: OutlinedButton.icon(
              onPressed: () async {
                await _supabase.auth.signOut();
                if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.logout, color: Color(0xffb73229), size: 18),
              label: const Text('Sign Out', style: TextStyle(color: Color(0xffb73229), fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xffb73229))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarTab() {
    final selectedEvents = _getEventsForDay(_selectedDay ?? _focusedDay);

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(16),
          elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        Expanded(
          child: selectedEvents.isEmpty
              ? const Center(child: Text("No sessions on this day.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: selectedEvents.length,
                  itemBuilder: (context, index) {
                    final session = selectedEvents[index];
                    return _buildActivityItem(
                      session,
                      session['subject'], 
                      '${session['duration_minutes']} mins', 
                      session['location'] ?? 'Campus'
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w600)), Icon(icon, color: color, size: 18)]),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> session, String title, String duration, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8), elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black)),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.history_edu, color: Color(0xff5732a3)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Text(duration, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xffb73229))),
        onTap: () => _showEditDialog(session),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: const Color(0xfff8f9fa), child: _tabBar);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}