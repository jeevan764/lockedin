// lib/screens/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _feedData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchActivityFeed();
  }

  Future<void> _fetchActivityFeed() async {
    try {
      // Fetches sessions and joins with the profiles table to get the username
      final response = await _supabase
          .from('study_sessions')
          .select('*, profiles(username)')
          .order('created_at', ascending: false);

      setState(() {
        _feedData = response;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading feed: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Activity Feed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xff5732a3),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchActivityFeed();
            },
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xff5732a3)))
          : _feedData.isEmpty
              ? const Center(child: Text('No activity yet. Go record a session!', style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _fetchActivityFeed,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _feedData.length,
                    itemBuilder: (context, index) {
                      final session = _feedData[index];
                      // Safely extract username or default to 'Fellow Student'
                      final username = session['profiles'] != null ? session['profiles']['username'] : 'Fellow Student';
                      
                      return _buildPostCard(
                        username: username,
                        subject: session['subject'],
                        durationMins: session['duration_minutes'].toString(),
                        location: session['location'],
                        xp: session['xp_earned'].toString(),
                      );
                    },
                  ),
                ),
    );
  }

  // Updated to accept dynamic parameters
  Widget _buildPostCard({
    required String username, 
    required String subject, 
    required String durationMins, 
    required String location, 
    required String xp
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xff3f6b8e),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                    const Text('Recently completed', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Text(
              '$subject Session',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
            ),
            const SizedBox(height: 16),
            
            Center(
              child: Container(
                height: 130,
                width: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xff5732a3), width: 2),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      location,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xff5732a3), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn('Duration', '${durationMins}m'),
                _buildVerticalDivider(),
                _buildStatColumn('Subject', subject),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn('XP Earned', '+$xp XP'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 40, width: 1, color: Colors.grey[300]);
  }
}