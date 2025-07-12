// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:onecup/screens/home_screen.dart';
import 'package:onecup/screens/my_bar_screen.dart';
import 'package:onecup/screens/shopping_list_screen.dart';
import 'package:onecup/theme/app_theme.dart'; // 导入您的主题文件

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return  MaterialApp(
      title: 'OneCup',
      theme: AppTheme.lightTheme, // 应用您定义的浅色主题
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
  final List<Widget> _pages = [
    const HomeScreen(),
    const MyBarScreen(),
    const ShoppingListScreen(),
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
        // 主题已在MaterialApp中设置，这里的颜色会自动适配
        // backgroundColor: Theme.of(context).primaryColor, // 可以移除
        // unselectedItemColor: Colors.white70, // 可以移除
        // selectedItemColor: Colors.white, // 可以移除
        currentIndex: _selectedPageIndex,
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