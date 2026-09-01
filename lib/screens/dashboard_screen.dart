// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'feed_screen.dart';
import 'tasks_screen.dart';
import 'profile_screen.dart';
import 'record_screen.dart';

// Central notification bus that signals background views to invalidate memory caches
final ValueNotifier<int> syncFeedNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> syncProfileNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> syncTasksNotifier = ValueNotifier<int>(0); // Sync bus added for Tasks view tracking

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  // Storing the page instances directly within the State block ensures they don't 
  // break context history tracking during hot reloads or state changes.
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const FeedScreen(),
      const TasksScreen(),
      const RecordScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xff1e1e24), // ADD THIS: Dark slate background
        selectedItemColor: Colors.blueAccent,     // CHANGED: From purple to Blue Accent
        unselectedItemColor: Colors.white54,      // CHANGED: From black38 to light grey
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          // Safety Check: If there's an active dialog overlaying the viewport when the user 
          // taps a bottom tab navigation switch button, safely clear the dialogue history stack 
          // before moving indices to prevent throwing structural assertion history errors.
          while (Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          setState(() => _currentIndex = index);
          
          // Force-updates target screens on manual tap events
          if (index == 0) syncFeedNotifier.value++;
          if (index == 1) syncTasksNotifier.value++;    // Invalidates Tasks page layout instantly
          if (index == 3) syncProfileNotifier.value++;  // Re-fetches fresh user metrics historical rows
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