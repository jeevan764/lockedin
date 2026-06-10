// lib/screens/feed_screen.dart
import 'package:flutter/material.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      // 1. ADDED AN APPBAR: Automatically pushes content safely below the notch/clock line
      appBar: AppBar(
        title: const Text(
          'Activity Feed',
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.bold, 
            color: Colors.white, // High contrast text for the purple background
          ),
        ),
        backgroundColor: const Color(0xff5732a3), // Your signature deep purple
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Removed the old naked text row from here since the AppBar handles it now!
            _buildPostCard(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard() {
    return Card(
      elevation: 2,
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
                  children: const [
                    Text('Jay Chong', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                    Text('Feb 1st, 2026 at 11:30 AM', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Linear Algebra Session: Tackling matrix!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
            ),
            const SizedBox(height: 16),
            
            Center(
              child: Container(
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xff5732a3), width: 2),
                ),
                child: const Center(
                  child: Text(
                    'NUS Central Library\nStudy Zone',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xff5732a3), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn('Duration', '2h 15m'),
                _buildVerticalDivider(),
                _buildStatColumn('Subject', 'Linear Algebra\n(MA1512)'),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn('XP', '+250 XP'),
                _buildVerticalDivider(),
                _buildStatColumn('Tasks/Hr', '8.5'),
              ],
            ),
            const Divider(),
            
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text(
                  'View Breakdown',
                  style: TextStyle(color: Color(0xffb73229), fontWeight: FontWeight.bold),
                ),
              ),
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
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 40, width: 1, color: Colors.grey[300]);
  }
}