// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:onecup/screens/home_screen.dart';
import 'package:onecup/screens/my_bar_screen.dart';
import 'package:onecup/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return  MaterialApp(
      title: '鸡尾酒App',
      // theme:AppTheme.lightTheme,
      home: const MainTabsScreen(),
    );
  }
}

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({Key? key}) : super(key: key);

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  // FIX: Defined the list of pages for the BottomNavigationBar.
  final List<Widget> _pages = [
    const HomeScreen(),
    const MyBarScreen()
  ];
  int _selectedPageIndex = 0;

  void _selectPage(int index) {
    setState(() {
      _selectedPageIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedPageIndex],
      bottomNavigationBar: BottomNavigationBar(
        onTap: _selectPage,
        backgroundColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.white70,
        selectedItemColor: Colors.white,
        currentIndex: _selectedPageIndex,
        // FIX: Added the items for the BottomNavigationBar.
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_bar),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.liquor),
            label: '我的酒柜',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: '购物清单',
          ),
        ],
      ),
    );
  }
}
