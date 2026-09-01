// lib/screens/profile_screen.dart
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late final SupabaseClient _supabase;
  final ImagePicker picker = ImagePicker();
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

  String _selectedTimeframe = 'Week'; 
  List<dynamic> _currentPeriodSessions = [];
  List<dynamic> _previousPeriodSessions = [];
  bool _isLoadingAnalytics = false;

  @override
  void initState() {
    _supabase = Supabase.instance.client;
    super.initState();
    
    _subTabController = TabController(length: 2, vsync: this);
    _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
    
    _fetchProfileMetrics();
    _fetchModules();
    
    syncProfileNotifier.addListener(_fetchProfileMetrics);
    syncProfileNotifier.addListener(_fetchModules);
    syncProfileNotifier.addListener(_fetchAnalyticsData);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    syncProfileNotifier.removeListener(_fetchProfileMetrics);
    syncProfileNotifier.removeListener(_fetchModules);
    syncProfileNotifier.removeListener(_fetchAnalyticsData);
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
    if (!mounted) return;
    setState(() { 
      _isLoading = true; 
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

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
        final int duration = int.tryParse(row['duration_minutes']?.toString() ?? '0') ?? 0;
        xpCounter += duration;

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
          _currentStreak = calculateStreak(uniqueDates);
          _isLoading = false;
        });
        _fetchAnalyticsData();
      }
    } catch (e) {
      debugPrint("Profile Fetch Error: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingAnalytics = false;
        });
      }
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
      debugPrint('Error fetching modules: $e');
    }
  }

  Future<void> _fetchAnalyticsData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingAnalytics = true;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      DateTime currentStart;
      DateTime currentEnd = now;
      DateTime previousStart;
      DateTime previousEnd;

      switch (_selectedTimeframe) {
        case 'Day':
          currentStart = DateTime(now.year, now.month, now.day);
          previousStart = currentStart.subtract(const Duration(days: 1));
          previousEnd = currentStart;
          break;
        case 'Week':
          final todayMidnight = DateTime(now.year, now.month, now.day);
          currentStart = todayMidnight.subtract(Duration(days: todayMidnight.weekday - 1));
          previousStart = currentStart.subtract(const Duration(days: 7));
          previousEnd = currentStart;
          break;
        case 'Month':
          currentStart = DateTime(now.year, now.month, 1);
          previousStart = DateTime(now.year, now.month - 1, 1);
          previousEnd = currentStart;
          break;
        case 'Year':
        default:
          currentStart = DateTime(now.year, 1, 1);
          previousStart = DateTime(now.year - 1, 1, 1);
          previousEnd = currentStart;
          break;
      }

      final List<dynamic> currentData = await _supabase
          .from('study_sessions')
          .select()
          .eq('user_id', user.id)
          .gte('created_at', currentStart.toUtc().toIso8601String())
          .lte('created_at', currentEnd.toUtc().toIso8601String());

      final List<dynamic> previousData = await _supabase
          .from('study_sessions')
          .select()
          .eq('user_id', user.id)
          .gte('created_at', previousStart.toUtc().toIso8601String())
          .lt('created_at', previousEnd.toUtc().toIso8601String());

      if (mounted) {
        setState(() {
          _currentPeriodSessions = currentData;
          _previousPeriodSessions = previousData;
          _isLoadingAnalytics = false;
        });
      }
    } catch (e) {
      debugPrint('Analytics Fetch Error: $e');
      if (mounted) {
        setState(() {
          _isLoadingAnalytics = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? pickedFile = await picker.pickImage(
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

      final bytes = await pickedFile.readAsBytes();
      final String fileExtension = pickedFile.name.split('.').last;
      final String filePath = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      await _supabase.storage.from('avatars').uploadBinary(
        filePath,
        bytes,
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

  Future<void> _deleteProfilePicture() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);
    try {
      if (_avatarUrl != null) {
        final uri = Uri.parse(_avatarUrl!);
        final fileName = '${user.id}/${uri.pathSegments.last}';
        try {
          await _supabase.storage.from('avatars').remove([fileName]);
        } catch (_) {}
      }

      await _supabase.from('profiles').update({'avatar_url': null}).eq('id', user.id);

      if (mounted) {
        setState(() {
          _avatarUrl = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture removed successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear profile picture: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  int calculateStreak(Set<String> uniqueDates) {
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

    final colors = [
      const Color(0xff5732a3), Colors.blueAccent, Colors.tealAccent,
      Colors.orangeAccent, Colors.pinkAccent, Colors.redAccent, Colors.indigoAccent, const Color(0xff2d4059)
    ];
    int hash = moduleName.hashCode;
    return colors[hash.abs() % colors.length];
  }

  void _showSocialListModal(String title, List<String> usernames) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: const Color(0xff1e1e24),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const Divider(height: 24, color: Colors.white24),
            usernames.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text("No users found here yet.", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic))),
                  )
                : Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: usernames.length,
                      itemBuilder: (ctx, i) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          child: const Icon(Icons.person, color: Colors.white70, size: 20),
                        ),
                        title: Text('@${usernames[i]}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white)),
                        trailing: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('View Profile', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> deleteSession(dynamic sessionId) async {
    try {
      await _supabase.from('study_sessions').delete().eq('id', sessionId);
      _fetchProfileMetrics();
      syncFeedNotifier.value++;
    } catch (e) {
      if (!mounted) return;
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
            backgroundColor: const Color(0xff1e1e24),
            title: const Text('Edit Session', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: taskNameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Task Name', labelStyle: TextStyle(color: Colors.white54))),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        dropdownColor: const Color(0xff2d2d34),
                        hint: const Text('Add/Change Tag...', style: TextStyle(color: Colors.white54)),
                        value: selectedModuleId,
                        items: _modules.map((m) => DropdownMenuItem(value: m['id'].toString(), child: Text(m['name'].toString(), style: const TextStyle(color: Colors.white)))).toList(),
                        onChanged: (val) => setModalState(() => selectedModuleId = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: durationController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Duration (Minutes)', labelStyle: TextStyle(color: Colors.white54))),
                  const SizedBox(height: 10),
                  TextField(controller: locationController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Location', labelStyle: TextStyle(color: Colors.white54))),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
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
                    'xp_earned': minutes,
                  }).eq('id', sessionId);

                  if (!mounted) return;
                  Navigator.pop(context);
                  _fetchProfileMetrics();
                  syncFeedNotifier.value++;
                },
                child: const Text('Save Changes', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTierProgressCard() {
    int currentLevel = GamificationEngine.getLevel(_totalXp);
    int currentLevelMinXp = GamificationEngine.getXpThresholdForCurrentLevel(currentLevel);
    int nextLevelMaxXp = GamificationEngine.getXpNeededForNextLevel(currentLevel);
    int xpInCurrentLevel = _totalXp - currentLevelMinXp;
    
    int xpRequiredForLevelUp = nextLevelMaxXp - currentLevelMinXp;
    
    double progressFraction = xpRequiredForLevelUp > 0 ? (xpInCurrentLevel / xpRequiredForLevelUp).clamp(0.0, 1.0) : 1.0;
    var tier = GamificationEngine.getTierDetails(currentLevel);

    return GestureDetector(
      onTap: () => _showTierInfoModal(context, currentLevel),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: tier['color'],
                    child: Text('$currentLevel', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tier['name'].toUpperCase(),
                          style: TextStyle(color: tier['color'], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_totalXp / $nextLevelMaxXp XP to Level ${currentLevel + 1}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(tier['icon'], color: Colors.white60, size: 18),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressFraction,
                  backgroundColor: Colors.white12,
                  color: tier['color'],
                  minHeight: 5,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showTierInfoModal(BuildContext context, int userCurrentLevel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: const BoxDecoration(
            color: Color(0xff1e1e24),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('LockedIn Productivity Tiers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              const Text('Level up your focus to unlock elite status metrics.', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const Divider(height: 24, color: Colors.white24),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const Text('How to Earn XP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    const SizedBox(height: 8),
                    _buildXpRuleRow(Icons.timer_outlined, 'Focus Sessions', 'Earn XP directly matching minutes inside deep study layouts.'),
                    _buildXpRuleRow(Icons.local_fire_department_outlined, 'Streak Multipliers', 'Keep up your daily streak to trigger bonus XP payouts.'),
                    _buildXpRuleRow(Icons.task_alt_rounded, 'Task Completions', 'Finish prioritized tasks on your checklist for direct bundles.'),
                    const SizedBox(height: 24),
                    const Text('Ranked Tiers & Perks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    const SizedBox(height: 12),
                    _buildTierDetailItem('Novice Spark', 'Levels 1-5', 'Habit Foundations', Colors.grey, Icons.child_care, userCurrentLevel <= 5),
                    _buildTierDetailItem('Deep Focuser', 'Levels 6-15', 'Access to custom study analytics summaries', Colors.blueAccent, Icons.trending_up, userCurrentLevel >= 6 && userCurrentLevel <= 15),
                    _buildTierDetailItem('Flow Master', 'Levels 16-30', 'Unlocks 1x Monthly Auto-Streak Shield protector', Colors.tealAccent, Icons.bolt, userCurrentLevel >= 16 && userCurrentLevel <= 30),
                    _buildTierDetailItem('Productivity Titan', 'Levels 31-50', 'Custom profile themes & exclusive badge flare rings', Colors.orangeAccent, Icons.emoji_events, userCurrentLevel >= 31 && userCurrentLevel <= 50),
                    _buildTierDetailItem('LockedIn Legend', 'Levels 51+', 'Elite Leaderboard status & Golden avatar aura frame', Colors.amberAccent, Icons.diamond, userCurrentLevel >= 51),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildXpRuleRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          CircleAvatar(radius: 16, backgroundColor: Colors.white.withOpacity(0.1), child: Icon(icon, size: 16, color: Colors.white70)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierDetailItem(String name, String levels, String perk, Color color, IconData icon, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? color.withOpacity(0.15) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCurrent ? color : Colors.white12, width: isCurrent ? 1.5 : 1),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color, radius: 16, child: Icon(icon, color: Colors.white, size: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                    const SizedBox(width: 6),
                    Text('($levels)', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    if (isCurrent) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                        child: const Text('CURRENT', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 2),
                Text('Perk: $perk', style: TextStyle(color: isCurrent ? Colors.white : Colors.white54, fontSize: 11, fontStyle: FontStyle.italic)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCalendarViewTab() {
    final List<dynamic> selectedSessions = _sessionsByDay[_selectedDay] ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.white.withOpacity(0.1),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                _focusedDay = focusedDay;
              });
            },
            eventLoader: (day) {
              final cleanDay = DateTime(day.year, day.month, day.day);
              return _sessionsByDay[cleanDay] ?? [];
            },
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true, titleTextStyle: TextStyle(color: Colors.white, fontSize: 16)),
            daysOfWeekStyle: const DaysOfWeekStyle(weekdayStyle: TextStyle(color: Colors.white70), weekendStyle: TextStyle(color: Colors.white70)),
            calendarStyle: CalendarStyle(
              defaultTextStyle: const TextStyle(color: Colors.white),
              weekendTextStyle: const TextStyle(color: Colors.white70),
              outsideTextStyle: const TextStyle(color: Colors.white30),
              todayDecoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              selectedDecoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              markerDecoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Sessions on ${_selectedDay?.day}/${_selectedDay?.month}/${_selectedDay?.year}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        const SizedBox(height: 10),
        selectedSessions.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Text('No focus logs found for this calendar date.', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: selectedSessions.length,
                itemBuilder: (context, idx) {
                  final item = selectedSessions[idx];
                  final String subjectFull = item['subject']?.toString() ?? 'Study Task';
                  final String location = item['location']?.toString() ?? 'Campus';
                  final int duration = int.tryParse(item['duration_minutes']?.toString() ?? '0') ?? 0;
                  
                  String taskName = subjectFull;
                  String tag = "";
                  
                  if (subjectFull.contains('(') && subjectFull.endsWith(')')) {
                    int openParen = subjectFull.lastIndexOf('(');
                    taskName = subjectFull.substring(0, openParen).trim();
                    tag = subjectFull.substring(openParen + 1, subjectFull.length - 1).trim();
                  }

                  return Card(
                    color: Colors.white.withOpacity(0.1),
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
                    child: ListTile(
                      title: Text(taskName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      subtitle: Text('$location • $duration mins', style: const TextStyle(color: Colors.white70)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (tag.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: _getColorForModule(tag).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(tag, style: TextStyle(color: _getColorForModule(tag), fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          IconButton(icon: const Icon(Icons.edit_note_rounded, color: Colors.white54), onPressed: () => _showEditDialog(item)),
                          IconButton(icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent), onPressed: () => deleteSession(item['id'])),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildAnalyticsViewTab() {
    if (_isLoadingAnalytics) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final currentTotalMins = _currentPeriodSessions.fold<int>(0, (sum, item) => sum + (int.tryParse(item['duration_minutes']?.toString() ?? '0') ?? 0));
    final previousTotalMins = _previousPeriodSessions.fold<int>(0, (sum, item) => sum + (int.tryParse(item['duration_minutes']?.toString() ?? '0') ?? 0));
    
    final currentTotalXp = currentTotalMins;
    final previousTotalXp = previousTotalMins;

    double durationChangePercent = 0.0;
    if (previousTotalMins > 0) {
      durationChangePercent = ((currentTotalMins - previousTotalMins) / previousTotalMins) * 100;
    }
    
    double xpChangePercent = 0.0;
    if (previousTotalXp > 0) {
      xpChangePercent = ((currentTotalXp - previousTotalXp) / previousTotalXp) * 100;
    }

    final Map<String, int> locationDurations = {};
    for (var session in _currentPeriodSessions) {
      final loc = session['location']?.toString() ?? 'Other';
      final mins = int.tryParse(session['duration_minutes']?.toString() ?? '0') ?? 0;
      locationDurations[loc] = (locationDurations[loc] ?? 0) + mins;
    }
    
    final sortedLocations = locationDurations.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: Colors.white,
      onRefresh: _fetchAnalyticsData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ToggleButtons(
                isSelected: [
                  _selectedTimeframe == 'Day',
                  _selectedTimeframe == 'Week',
                  _selectedTimeframe == 'Month',
                  _selectedTimeframe == 'Year',
                ],
                onPressed: (index) {
                  final list = ['Day', 'Week', 'Month', 'Year'];
                  setState(() {
                    _selectedTimeframe = list[index];
                  });
                  _fetchAnalyticsData();
                },
                borderRadius: BorderRadius.circular(20),
                selectedColor: Colors.black,
                fillColor: Colors.white,
                color: Colors.white54,
                borderColor: Colors.white24,
                selectedBorderColor: Colors.white,
                constraints: const BoxConstraints(minHeight: 36, minWidth: 70),
                children: const [
                  Text('Day'),
                  Text('Week'),
                  Text('Month'),
                  Text('Year'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMetricComparisonCard(
                  title: 'Study Duration',
                  value: '${(currentTotalMins / 60).toStringAsFixed(1)} hrs',
                  percentChange: durationChangePercent,
                  isIncreasePositive: true,
                  subtitle: '${currentTotalMins}m vs ${previousTotalMins}m prior',
                  icon: Icons.timer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricComparisonCard(
                  title: 'XP Growth',
                  value: '+$currentTotalXp XP',
                  percentChange: xpChangePercent,
                  isIncreasePositive: true,
                  subtitle: 'vs +$previousTotalXp XP prior',
                  icon: Icons.insights_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.white.withOpacity(0.1),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Focus Spots Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Where you spent your study sessions during this $_selectedTimeframe.', style: const TextStyle(fontSize: 12, color: Colors.white54, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 16),
                  if (sortedLocations.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(child: Text('No session data recorded.', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic))),
                    )
                  else
                    ...sortedLocations.map((entry) {
                      final index = sortedLocations.indexOf(entry);
                      final locationName = entry.key;
                      final duration = entry.value;
                      final percentage = currentTotalMins > 0 ? (duration / currentTotalMins) : 0.0;
                      
                      final List<Color> palette = [Colors.blueAccent, Colors.tealAccent, Colors.orangeAccent, Colors.purpleAccent];
                      final barColor = palette[index % palette.length];
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_on_rounded, size: 16, color: barColor),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          locationName, 
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8), 
                                Text(
                                  '${(percentage * 100).toStringAsFixed(0)}% (${duration}m)', 
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage,
                                minHeight: 8,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildMetricComparisonCard({
    required String title,
    required String value,
    required double percentChange,
    required bool isIncreasePositive,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isNoPriorData = _previousPeriodSessions.isEmpty;
    final bool isPositive = percentChange >= 0;
    final bool isGoodChange = (isPositive && isIncreasePositive) || (!isPositive && !isIncreasePositive);
    
    Color badgeColor = Colors.white54;
    IconData arrowIcon = Icons.trending_flat_rounded;
    
    if (!isNoPriorData) {
      badgeColor = isGoodChange ? Colors.greenAccent : Colors.redAccent;
      arrowIcon = isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    }

    return Card(
      color: Colors.white.withOpacity(0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white70, size: 22),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!isNoPriorData) ...[
                  Icon(arrowIcon, color: badgeColor, size: 16),
                  const SizedBox(width: 2),
                  Text('${percentChange.abs().toStringAsFixed(1)}%', style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ] else
                  const Text('N/A', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(width: 4),
                const Text('vs prior', style: TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white30, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = _supabase.auth.currentUser?.email ?? 'User Account';
    
    return Scaffold(
      backgroundColor: Colors.transparent, // FIX: Transparent for full background
      extendBodyBehindAppBar: true,      // FIX: Extend into app bar area
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, // FIX: Transparent app bar
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Log Out',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xff1e1e24),
                  title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  content: const Text('Are you sure you want to log out of LockedIn?', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleSignOut();
                      },
                      child: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Container( // FIX: Universal Background Wrapper applied
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/background.jpeg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.2), 
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                                child: _avatarUrl == null ? const Icon(Icons.person, size: 40, color: Colors.white70) : null,
                              ),
                              if (_isUploading)
                                Positioned.fill(
                                  child: Container(
                                    decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                    child: const Center(
                                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _isUploading ? null : () {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: const Color(0xff1e1e24),
                                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                                      builder: (context) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(Icons.photo_library, color: Colors.white),
                                              title: const Text('Upload New Photo', style: TextStyle(color: Colors.white)),
                                              onTap: () {
                                                Navigator.pop(context);
                                                _pickAndUploadImage();
                                              },
                                            ),
                                            if (_avatarUrl != null)
                                              ListTile(
                                                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                                title: const Text('Remove Current Photo', style: TextStyle(color: Colors.redAccent)),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _deleteProfilePicture();
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.white,
                                    child: Icon(Icons.camera_alt, size: 12, color: Colors.black),
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
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
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
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
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
                          _buildTierProgressCard(),
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
                      color: Colors.black.withOpacity(0.3), // FIX: Translucent tab bar
                      child: TabBar(
                        controller: _subTabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        indicatorColor: Colors.white,
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
        ),
      ),
    );
  }
}

class GamificationEngine {
  static int getLevel(int totalXp) {
    if (totalXp < 2500) return (totalXp / 500).floor() + 1;
    if (totalXp < 12500) return ((totalXp - 2500) / 1000).floor() + 6;
    if (totalXp < 42500) return ((totalXp - 12500) / 2000).floor() + 16;
    if (totalXp < 122500) return ((totalXp - 42500) / 4000).floor() + 31;
    return ((totalXp - 122500) / 8000).floor() + 51;
  }

  static int getXpNeededForNextLevel(int currentLevel) {
    if (currentLevel < 5) return currentLevel * 500;
    if (currentLevel < 15) return 2500 + ((currentLevel - 5) * 1000);
    if (currentLevel < 30) return 12500 + ((currentLevel - 15) * 2000);
    if (currentLevel < 50) return 42500 + ((currentLevel - 30) * 4000);
    return 122500 + ((currentLevel - 50) * 8000);
  }

  static int getXpThresholdForCurrentLevel(int currentLevel) {
    if (currentLevel <= 1) return 0;
    return getXpNeededForNextLevel(currentLevel - 1);
  }

  static Map<String, dynamic> getTierDetails(int level) {
    if (level <= 5) return {'name': 'Novice Spark', 'color': Colors.grey, 'icon': Icons.child_care};
    if (level <= 15) return {'name': 'Deep Focuser', 'color': Colors.blueAccent, 'icon': Icons.trending_up};
    if (level <= 30) return {'name': 'Flow Master', 'color': Colors.tealAccent, 'icon': Icons.bolt};
    if (level <= 50) return {'name': 'Productivity Titan', 'color': Colors.orangeAccent, 'icon': Icons.emoji_events};
    return {'name': 'LockedIn Legend', 'color': Colors.amberAccent, 'icon': Icons.diamond};
  }
}