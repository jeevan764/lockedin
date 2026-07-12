// lib/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart'; // Added to support debugPrint
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  late TabController _subTabController;

  bool _isLoading = true;
  bool _isUploading = false;
  String _username = 'User';
  int _totalXp = 0;
  int _currentStreak = 0;
  String? _avatarUrl;

  List<dynamic> _myHistory = [];
  List<Map<String, dynamic>> _modules = [];
  Map<DateTime, List<dynamic>> _sessionsByDay = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<String> _followersUsernames = [];
  List<String> _followingUsernames = [];

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 2, vsync: this);
    _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
    _fetchProfileMetrics();
    _fetchModules();
    syncProfileNotifier.addListener(_fetchProfileMetrics);
    syncProfileNotifier.addListener(_fetchModules);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    syncProfileNotifier.removeListener(_fetchProfileMetrics);
    syncProfileNotifier.removeListener(_fetchModules);
    super.dispose();
  }

  Future<void> _handleSignOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _fetchProfileMetrics() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profileData = await _supabase.from('profiles').select('username, avatar_url').eq('id', user.id).single();
      _username = profileData['username'] ?? 'User';
      _avatarUrl = profileData['avatar_url'];

      final followersData = await _supabase.from('follows').select('profiles!follower_id(username)').eq('following_id', user.id);
      final followingData = await _supabase.from('follows').select('profiles!following_id(username)').eq('follower_id', user.id);

      _followersUsernames = (followersData as List).map((f) => (f['profiles']?['username'] ?? 'Anonymous').toString()).toList();
      _followingUsernames = (followingData as List).map((f) => (f['profiles']?['username'] ?? 'Anonymous').toString()).toList();

      final response = await _supabase.from('study_sessions').select().eq('user_id', user.id).order('created_at', ascending: false);

      int xpCounter = 0;
      Map<DateTime, List<dynamic>> groupedSessions = {};
      Set<String> uniqueDates = {};

      for (var row in response) {
        xpCounter += (row['xp_earned'] as num?)?.toInt() ?? 0;
        if (row['created_at'] != null) {
          DateTime date = DateTime.parse(row['created_at'].toString()).toLocal();
          DateTime cleanDate = DateTime(date.year, date.month, date.day);

          uniqueDates.add("${cleanDate.year}-${cleanDate.month}-${cleanDate.day}");

          if (groupedSessions[cleanDate] == null) groupedSessions[cleanDate] = [];
          groupedSessions[cleanDate]!.add(row);
        }
      }

      if (mounted) {
        setState(() {
          _myHistory = response;
          _totalXp = xpCounter;
          _sessionsByDay = groupedSessions;
          _currentStreak = _calculateStreak(uniqueDates);
          _isLoading = false;
        });
      }
    } catch (e) {
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
      debugPrint('Error fetching modules: $e'); // FIXED: Swapped print to debugPrint
    }
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final File file = File(pickedFile.path);
      final String fileExtension = pickedFile.path.split('.').last;
      final String filePath = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      await _supabase.storage.from('avatars').upload(
            filePath,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final String publicUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);

      await _supabase.from('profiles').upsert({
        'id': user.id,
        'avatar_url': publicUrl,
        'username': _username,
      });

      if (mounted) {
        setState(() => _avatarUrl = publicUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  int _calculateStreak(Set<String> uniqueDates) {
    int streak = 0;
    DateTime checkDate = DateTime.now();
    DateTime todayClean = DateTime(checkDate.year, checkDate.month, checkDate.day);
    DateTime check = todayClean;

    while (true) {
      String checkStr = "${check.year}-${check.month}-${check.day}";
      if (uniqueDates.contains(checkStr)) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      } else {
        if (streak == 0) {
          DateTime yesterday = todayClean.subtract(const Duration(days: 1));
          String yestStr = "${yesterday.year}-${yesterday.month}-${yesterday.day}";
          if (uniqueDates.contains(yestStr)) {
            check = yesterday;
            continue;
          }
        }
        break;
      }
    }
    return streak;
  }

  Color _getColorForModule(String moduleName) {
    try {
      final match = _modules.firstWhere((m) => m['name'].toString().toLowerCase() == moduleName.toLowerCase());
      if (match['color_hex'] != null) {
        String hex = match['color_hex'].toString().replaceAll('#', '').trim();
        if (hex.startsWith('0x')) hex = hex.substring(2);
        if (hex.length == 6) hex = 'FF$hex';
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    final colors = [const Color(0xff5732a3), Colors.blueAccent, Colors.teal, Colors.orange, Colors.pinkAccent, Colors.redAccent, Colors.indigo, const Color(0xff2d4059)];
    int hash = moduleName.hashCode;
    return colors[hash.abs() % colors.length];
  }

  void _showSocialListModal(String title, List<String> usernames) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff5732a3))),
            const Divider(height: 24),
            usernames.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text("No users found here yet.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
                  )
                : Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: usernames.length,
                      itemBuilder: (ctx, i) => ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xfff1eefc), child: Icon(Icons.person, color: Color(0xff5732a3), size: 20)),
                        title: Text('@${usernames[i]}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        trailing: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xff5732a3)), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                          ),
                          child: const Text('View Profile', style: TextStyle(color: Color(0xff5732a3), fontSize: 12)),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSession(dynamic sessionId) async {
    try {
      await _supabase.from('study_sessions').delete().eq('id', sessionId);
      _fetchProfileMetrics();
      syncFeedNotifier.value++;
    } catch (e) {
      if (!mounted) return; // FIXED: Safety check before displaying SnackBar across async gap
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  void _showEditDialog(dynamic rawSession) {
    final session = rawSession as Map<String, dynamic>;
    final sessionId = session['id'];
    String rawSubject = session['subject']?.toString() ?? '';
    String initialTaskName = rawSubject;
    String? selectedModuleId;

    if (rawSubject.contains('(') && rawSubject.endsWith(')')) {
      int openParen = rawSubject.lastIndexOf('(');
      initialTaskName = rawSubject.substring(0, openParen).trim();
      String tagName = rawSubject.substring(openParen + 1, rawSubject.length - 1).trim();
      try {
        selectedModuleId = _modules.firstWhere((m) => m['name'].toString().toLowerCase() == tagName.toLowerCase())['id'].toString();
      } catch (_) {}
    }

    final taskNameController = TextEditingController(text: initialTaskName);
    final durationController = TextEditingController(text: session['duration_minutes']?.toString() ?? '0');
    final locationController = TextEditingController(text: session['location']?.toString() ?? '');

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
                  TextField(controller: taskNameController, decoration: const InputDecoration(labelText: 'Task Name')),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100], 
                      borderRadius: BorderRadius.circular(8), 
                      border: Border.all(color: Colors.grey.shade300),
                    ),
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
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              TextButton(
                onPressed: () async {
                  String finalSubject = taskNameController.text.trim();
                  if (selectedModuleId != null) {
                    final matchedMod = _modules.firstWhere((m) => m['id'].toString() == selectedModuleId);
                    finalSubject = '$finalSubject (${matchedMod['name']})';
                  }
                  int minutes = int.tryParse(durationController.text.trim()) ?? 0;
                  
                  await _supabase.from('study_sessions').update({
                    'subject': finalSubject,
                    'duration_minutes': minutes,
                    'location': locationController.text.trim(),
                    'xp_earned': minutes * 10,
                  }).eq('id', sessionId);
                  
                  if (!mounted) return; // FIXED: Safety check before navigation
                  Navigator.pop(context);
                  _fetchProfileMetrics();
                  syncFeedNotifier.value++;
                },
                child: const Text('Save Changes', style: TextStyle(color: Color(0xff5732a3), fontWeight: FontWeight.bold)),
              )
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = _supabase.auth.currentUser?.email ?? 'User Account';

    return Scaffold(
      backgroundColor: const Color(0xfff8f9fa),
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xff5732a3),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Log Out',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Text('Are you sure you want to log out of LockedIn?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleSignOut();
                      },
                      child: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
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
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.white,
                            backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                            child: _avatarUrl == null
                                ? const Icon(Icons.person, size: 40, color: Color(0xff5732a3))
                                : null,
                          ),
                          if (_isUploading)
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isUploading ? null : _pickAndUploadImage,
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.camera_alt, size: 12, color: Color(0xff5732a3)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              '@$_username', 
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              userEmail, 
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _showSocialListModal('Followers', _followersUsernames),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                // FIXED: Switched to .withAlpha for strict modern linting
                                decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(16)),
                                child: Row(
                                  children: [
                                    Text('${_followersUsernames.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    const Text(' Followers', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _showSocialListModal('Following', _followingUsernames),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(16)),
                                child: Row(
                                  children: [
                                    Text('${_followingUsernames.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    const Text(' Following', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ),
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
                                  Text('$_currentStreak', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Text('DAY STREAK', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _subTabController,
                    labelColor: const Color(0xff5732a3),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xff5732a3),
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(icon: Icon(Icons.calendar_month), text: "Calendar"),
                      Tab(icon: Icon(Icons.bar_chart_rounded), text: "Analytics"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _subTabController,
                    children: [
                      _buildCalendarViewTab(),
                      _buildAnalyticsViewTab(),
                    ],
                  ),
                )
              ],
            ),
    );
  }

  Widget _buildCalendarViewTab() {
    DateTime lookupKey = _selectedDay ?? DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
    final selectedEvents = _sessionsByDay[lookupKey] ?? [];

    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            elevation: 0,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.black12)),
            child: TableCalendar(
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: (day) => _sessionsByDay[DateTime(day.year, day.month, day.day)] ?? [],
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                  _focusedDay = focusedDay;
                });
              },
              calendarStyle: CalendarStyle(
                // FIXED: Safely using withAlpha
                todayDecoration: BoxDecoration(color: const Color(0xff5732a3).withAlpha(76), shape: BoxShape.circle),
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
              itemBuilder: (context, index) => _buildActivityItem(selectedEvents[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsViewTab() {
    if (_myHistory.isEmpty) {
      return const Center(child: Text("Complete study sessions to generate metric summaries!"));
    }

    int totalMinutes = 0;
    Map<String, int> moduleTimeMap = {};
    Map<String, int> locationMap = {};

    for (var session in _myHistory) {
      int duration = (session['duration_minutes'] as num?)?.toInt() ?? 0;
      totalMinutes += duration;

      String subjectFull = session['subject']?.toString() ?? '';
      String moduleTag = 'General';
      if (subjectFull.contains('(') && subjectFull.endsWith(')')) {
        int openParen = subjectFull.lastIndexOf('(');
        moduleTag = subjectFull.substring(openParen + 1, subjectFull.length - 1).trim();
      }
      moduleTimeMap[moduleTag] = (moduleTimeMap[moduleTag] ?? 0) + duration;

      String location = session['location']?.toString() ?? 'Unknown';
      if (location.isEmpty) location = 'Unspecified';
      locationMap[location] = (locationMap[location] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Focus', 
                '${(totalMinutes / 60).toStringAsFixed(1)} hrs', 
                Icons.timer_outlined, 
                Colors.blueAccent
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Sessions Run', 
                '${_myHistory.length} completed', 
                Icons.emoji_events_outlined, 
                Colors.orangeAccent
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Focus Allocation by Subject', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: moduleTimeMap.entries.map((entry) {
                double fraction = totalMinutes > 0 ? entry.value / totalMinutes : 0.0;
                Color tagColor = _getColorForModule(entry.key);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key, 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${entry.value} mins (${(fraction * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          backgroundColor: Colors.grey[200],
                          color: tagColor,
                          minHeight: 8,
                        ),
                      )
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Top Study Environments', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: locationMap.length > 3 ? 3 : locationMap.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, idx) {
              var sortedEntries = locationMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              var entry = sortedEntries[idx];
              return ListTile(
                leading: CircleAvatar(backgroundColor: Colors.grey[100], child: const Icon(Icons.place, color: Colors.blueGrey)),
                title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                trailing: Text('${entry.value} visits', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff5732a3))),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String val, IconData ico, Color col) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: col.withAlpha(25), child: Icon(ico, color: col)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title, 
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    val, 
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 2,
                  ),
                ],
              ),
            )
          ],
        ),
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
            Expanded(
              child: Text(
                taskName, 
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (moduleName.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getColorForModule(moduleName).withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _getColorForModule(moduleName)),
                ),
                child: Text(
                  moduleName, 
                  style: TextStyle(color: _getColorForModule(moduleName), fontWeight: FontWeight.bold, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ]
          ],
        ),
        subtitle: Text(
          '${session['duration_minutes']} mins • ${session['location']} • +${session['xp_earned']} XP', 
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _showEditDialog(session)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _deleteSession(session['id'])),
          ],
        ),
      ),
    );
  }
}