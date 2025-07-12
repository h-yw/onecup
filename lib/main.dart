// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:onecup/screens/home_screen.dart';
import 'package:onecup/screens/my_bar_screen.dart';
import 'package:onecup/screens/shopping_list_screen.dart'; // 导入新页面

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
  // FIX: 定义了BottomNavigationBar的页面列表。
  final List<Widget> _pages = [
    const HomeScreen(),
    const MyBarScreen(),
    const ShoppingListScreen(), // 添加新页面
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
        // FIX: 添加了BottomNavigationBar的item。
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