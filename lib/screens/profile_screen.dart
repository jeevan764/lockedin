// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  
  List<dynamic> _recentSessions = [];
  bool _isLoadingSessions = true;

  // Social metrics state variables
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchRecentSessions();
    _fetchSocialMetrics(); // Fetch follow graph counts on startup
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
      setState(() {
        _username = "Academic Athlete";
        _email = _supabase.auth.currentUser?.email ?? "student@u.nus.edu";
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _fetchRecentSessions() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('study_sessions')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(5);

        setState(() {
          _recentSessions = response;
          _isLoadingSessions = false;
        });
      }
    } catch (e) {
      print('Error fetching personal sessions: $e');
      setState(() => _isLoadingSessions = false);
    }
  }

  // Safe and compatible implementation to fetch follower and following counts
  Future<void> _fetchSocialMetrics() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Fetch the raw rows and determine count from list length to avoid PostgrestList type errors
      final List<dynamic> followersList = await _supabase
          .from('follows')
          .select('id')
          .eq('following_id', user.id);

      final List<dynamic> followingList = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', user.id);

      setState(() {
        _followersCount = followersList.length;
        _followingCount = followingList.length;
      });
    } catch (e) {
      print('Error parsing follower metrics: $e');
    }
  }

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
                expandedHeight: 210.0, // Height expanded to neatly fit the social metrics row
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xff5732a3), 
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    padding: const EdgeInsets.only(top: 40.0), 
                    color: const Color(0xff5732a3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            const SizedBox(
                              width: 84, height: 84,
                              child: CircularProgressIndicator(
                                value: 0.74, strokeWidth: 5,
                                backgroundColor: Colors.white24, 
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white), 
                              ),
                            ),
                            const CircleAvatar(
                              radius: 35, 
                              backgroundColor: Color(0xfff1edfa), 
                              child: Icon(Icons.school, size: 32, color: Color(0xff5732a3))
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _username, 
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
                        ),
                        Text(
                          _email, 
                          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w400)
                        ),
                        const SizedBox(height: 10),
                        
                        // Follower / Following Metric Display Counters
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$_followingCount',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Following',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                            ),
                            const SizedBox(width: 20),
                            Text(
                              '$_followersCount',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Followers',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  const TabBar(
                    labelColor: Color(0xff5732a3),
                    unselectedLabelColor: Colors.black38,
                    indicatorColor: Color(0xff5732a3),
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                      Tab(icon: Icon(Icons.analytics_outlined), text: "Overview"),
                      Tab(icon: Icon(Icons.calendar_month_outlined), text: "Calendar"),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildOverviewTab(),
              _buildCalendarTab(),
            ],
          ),
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
              _buildMetricCard('Current Streak', '12 Days', Icons.local_fire_department, Colors.orange),
              _buildMetricCard('Focus Hours', '42.5 hrs', Icons.timer_outlined, Colors.blue),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Recent Sessions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          if (_isLoadingSessions)
            const Center(child: CircularProgressIndicator(color: Color(0xff5732a3)))
          else if (_recentSessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No logged sessions yet. Time to get to work!', style: TextStyle(color: Colors.grey)),
            )
          else
            ..._recentSessions.map((session) {
              final subject = session['subject'] ?? 'Unknown';
              final durationMins = session['duration_minutes'] ?? 0;
              
              final durationStr = durationMins >= 60 
                  ? '${(durationMins / 60).toStringAsFixed(1)} hrs' 
                  : '$durationMins mins';
              
              String timeAgo = 'Recently';
              if (session['created_at'] != null) {
                final diff = DateTime.now().difference(DateTime.parse(session['created_at']));
                if (diff.inDays > 1) timeAgo = '${diff.inDays} days ago';
                else if (diff.inDays == 1) timeAgo = 'Yesterday';
                else if (diff.inHours > 0) timeAgo = '${diff.inHours} hrs ago';
                else if (diff.inMinutes > 0) timeAgo = '${diff.inMinutes} mins ago';
                else timeAgo = 'Just now';
              }

              return _buildActivityItem(subject, durationStr, timeAgo);
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.black)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('June 2026', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Icon(Icons.chevron_right, color: Colors.black54),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 200,
                    color: Colors.black.withOpacity(0.03),
                    child: const Center(child: Text('Calendar Grid Injects Here', style: TextStyle(color: Colors.black38))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildActivityItem(String title, String duration, String timeAgo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8), elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black)),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.history_edu, color: Color(0xff5732a3)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(duration),
        trailing: Text(timeAgo, style: const TextStyle(fontSize: 11, color: Colors.black38)),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: const Color(0xfff8f9fa), child: _tabBar);
  }

  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}