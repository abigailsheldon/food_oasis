import 'package:flutter/material.dart';
import 'home_page.dart';
import 'discover_page.dart';
import 'navigate_page.dart';
import 'shop_page.dart';
import 'dashboard_page.dart';

/// A reusable bottom navigation bar that can be added to any page.
/// 
/// Usage:
/// ```dart
/// Scaffold(
///   body: ...,
///   bottomNavigationBar: const AppBottomNavBar(currentIndex: -1),
/// )
/// ```
/// 
/// Set currentIndex to highlight the correct tab:
/// - 0: Home
/// - 1: Discover
/// - 2: Navigate
/// - 3: Shop
/// - 4: Dashboard
/// - -1: None (for pages not in the main nav)
class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const AppBottomNavBar({
    super.key,
    this.currentIndex = -1,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex == -1 ? 0 : currentIndex,
      selectedItemColor: currentIndex == -1 ? Colors.grey : Colors.green,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      onTap: (index) => _onItemTapped(context, index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.explore),
          label: 'Discover',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.navigation),
          label: 'Navigate',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.store),
          label: 'Shop',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Dashboard',
        ),
      ],
    );
  }

  void _onItemTapped(BuildContext context, int index) {
    // Pop all routes and go to the main page with selected tab
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => MainPageWithIndex(initialIndex: index),
      ),
      (route) => false,
    );
  }
}

/// Helper widget that wraps MainPage with a specific starting index.
/// This allows us to navigate directly to a specific tab.
class MainPageWithIndex extends StatefulWidget {
  final int initialIndex;

  const MainPageWithIndex({
    super.key,
    required this.initialIndex,
  });

  @override
  State<MainPageWithIndex> createState() => _MainPageWithIndexState();
}

class _MainPageWithIndexState extends State<MainPageWithIndex> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  final List<Widget> _pages = [
    const HomePage(),
    const DiscoverPage(),
    const NavigatePage(),
    const ShopPage(),
    const DashboardPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.navigation),
            label: 'Navigate',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}