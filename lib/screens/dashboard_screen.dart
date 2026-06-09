// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'feed_screen.dart';
//import 'tasks_screen.dart'; // Ensure this file exists in the same directory

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Sets 'Tasks' (index 0) as the initial view right after logging/signing up
  int _currentIndex = 0;

  // Managed array holding your four primary app screens
  final List<Widget> _pages = [
    //const TasksScreen(), // Loads the dropdown module workspace by default
    const Center(child: Text('Record Screen\n(Coming in Milestone 2)', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.black54))),
    const FeedScreen(),
    const Center(child: Text('Profile Screen\n(Coming in Milestone 2)', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.black54))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Unified deep purple header themed directly from the Welcome Screen branding
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold, 
              fontFamily: 'sans-serif',
              letterSpacing: 0.5
            ),
            children: [
              TextSpan(
                text: 'Locked',
                style: TextStyle(color: Color.fromARGB(255, 240, 241, 243)),
              ),
              TextSpan(
                text: 'In',
                style: TextStyle(color: Color(0xffb73229)), // Red accent match
              ),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xff5732a3), // Deep Purple Branding Theme
        elevation: 0,
      ),
      
      // Displays the active selected view layout
      body: _pages[_currentIndex],
      
      // Bottom Navigation Framework
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xff5732a3), // Active selection highlight
        unselectedItemColor: Colors.black38,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline), 
            activeIcon: Icon(Icons.check_circle),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radio_button_checked), 
            label: 'Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline), 
            activeIcon: Icon(Icons.people),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), 
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}