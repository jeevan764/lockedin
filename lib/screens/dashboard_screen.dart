// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'feed_screen.dart';     
import 'tasks_screen.dart';    
import 'profile_screen.dart';
import 'record_screen.dart';

// Central notification bus that signals background views to invalidate memory caches
final ValueNotifier<int> syncFeedNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> syncProfileNotifier = ValueNotifier<int>(0);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const FeedScreen(),                                           
      const TasksScreen(),                                          
      const RecordScreen(),            
      const ProfileScreen(),                                        
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xff5732a3), 
        unselectedItemColor: Colors.black38,
        onTap: (index) {
          setState(() => _currentIndex = index);
          // Fallback force-updates active screens on manual tap events
          if (index == 0) syncFeedNotifier.value++;
          if (index == 3) syncProfileNotifier.value++;
        },
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