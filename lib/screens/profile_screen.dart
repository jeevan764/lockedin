// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  List<dynamic> _myHistory = [];
  bool _isLoading = true;
  int _totalXp = 0;
  int _currentStreak = 0;
  String _username = "Loading...";
  int _followerCount = 0;
  int _followingCount = 0;
  Set<int> _activeDaysInMonth = {}; 

  final List<String> _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileDetails();
    syncProfileNotifier.addListener(_loadProfileDetails);
  }

  @override
  void dispose() {
    _tabController.dispose();
    syncProfileNotifier.removeListener(_loadProfileDetails);
    super.dispose();
  }

  Future<void> _loadProfileDetails() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // 1. Fetch Profile Info (Username)
      final profileData = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', currentUserId)
          .maybeSingle();
      
      if (profileData != null) {
        _username = profileData['username'] ?? 'User';
      }

      // 2. Fetch Social Metrics (Followers & Following counts)
      final followersData = await _supabase.from('follows').select('id').eq('following_id', currentUserId);
      final followingData = await _supabase.from('follows').select('id').eq('follower_id', currentUserId);

      // 3. Fetch Study History Rows
      final response = await _supabase
          .from('study_sessions')
          .select('*')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      int xpCounter = 0;
      Set<String> uniqueDates = {};
      Set<int> daysInMonth = {};

      for (var row in response) {
        xpCounter += (row['xp_earned'] as num).toInt();
        
        if (row['created_at'] != null) {
          DateTime date = DateTime.parse(row['created_at']).toLocal();
          String dateString = "${date.year}-${date.month}-${date.day}";
          uniqueDates.add(dateString);

          if (date.month == _now.month && date.year == _now.year) {
            daysInMonth.add(date.day);
          }
        }
      }

      if (mounted) {
        setState(() {
          _myHistory = response;
          _totalXp = xpCounter;
          _followerCount = followersData.length;
          _followingCount = followingData.length;
          _activeDaysInMonth = daysInMonth;
          _currentStreak = _calculateStreak(uniqueDates);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Profile metrics load issue: $e');
      if (mounted) setState(() => _isLoading = false);
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

  Widget _buildCalendarGrid() {
    int daysInMonth = DateUtils.getDaysInMonth(_now.year, _now.month);
    int firstWeekdayOfMonth = DateTime(_now.year, _now.month, 1).weekday;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${_getMonthName(_now.month)} ${_now.year}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("${_activeDaysInMonth.length} Days Active", style: const TextStyle(color: Color(0xff5732a3), fontWeight: FontWeight.w600, fontSize: 13))
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _weekdays.map((day) => Text(day, style: const TextStyle(color: Colors.black38, fontWeight: FontWeight.bold, fontSize: 12))).toList(),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: daysInMonth + (firstWeekdayOfMonth - 1),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
                itemBuilder: (context, index) {
                  int dayOffset = index - (firstWeekdayOfMonth - 1);
                  if (dayOffset < 0) return const SizedBox.shrink();

                  int dayNumber = dayOffset + 1;
                  bool isActive = _activeDaysInMonth.contains(dayNumber);
                  bool isToday = dayNumber == _now.day;

                  return Container(
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xff5732a3) : Colors.grey[100],
                      shape: BoxShape.circle,
                      border: isToday ? Border.all(color: const Color(0xff5732a3), width: 2) : null,
                    ),
                    child: Center(
                      child: Text(
                        "$dayNumber",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isActive || isToday ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Hero Section
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
                      
                      // Follower details count strip
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
                
                // Navigation segment selector
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
                
                // Displays active screen content panels
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCalendarGrid(), 
                      _myHistory.isEmpty   
                          ? const Center(child: Text('No study history recorded.'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _myHistory.length,
                              itemBuilder: (context, index) {
                                final session = _myHistory[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Colors.black12),
                                  ),
                                  child: ListTile(
                                    leading: const Icon(Icons.history, color: Colors.grey),
                                    title: Text(session['subject']),
                                    subtitle: Text('${session['duration_minutes']} mins at ${session['location']}'),
                                    trailing: Text('+${session['xp_earned']} XP', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                )
              ],
            ),
    );
  }
}