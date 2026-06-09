// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'feed_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Sets 'Feed' (index 0) as the initial view right after authentication
  int _currentIndex = 0;

  // Reordered array matching your layout preference
  final List<Widget> _pages = [
    const FeedScreen(), // Index 0: Feed
    const Center(child: Text('Calendar Screen\n(Coming in Milestone 2)', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.black54))), // Index 1: Calendar
    const Center(child: Text('Record Screen\n(Coming in Milestone 2)', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.black54))),   // Index 2: Record
    const Center(child: Text('Profile Screen\n(Coming in Milestone 2)', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.black54))),  // Index 3: Profile
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                style: TextStyle(color: Color(0xffb73229)), 
              ),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xff5732a3), 
        elevation: 0,
      ),
      
      body: _pages[_currentIndex],
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xff5732a3), 
        unselectedItemColor: Colors.black38,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline), 
            activeIcon: Icon(Icons.people),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined), 
            activeIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radio_button_checked), 
            label: 'Record',
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