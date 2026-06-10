// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'feed_screen.dart';     // 1. IMPORTED YOUR NEW FEED SCREEN HERE
import 'profile_screen.dart';
// import 'tasks_screen.dart'; 
// import 'record_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // 2. PLACED THE REALS SCREEN OBJECT AT INDEX 0 OF YOUR NAVIGATION LIST
    final List<Widget> pages = [
      const FeedScreen(),                                           // Tab 0 (Live Activity Feed!)
      const Center(child: Text('Tasks & Checklist Workspace')),      // Tab 1
      const Center(child: Text('Record Session Screen')),            // Tab 2
      const ProfileScreen(),                                        // Tab 3 (Houses Calendar inside)
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xff5732a3), // Your signature purple
        unselectedItemColor: Colors.black38,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.check_box_outlined), activeIcon: Icon(Icons.check_box), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.radio_button_checked), label: 'Record'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}