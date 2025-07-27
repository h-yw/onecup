// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
// [核心改造] 不再需要 AuthGate
// import 'package:onecup/screens/auth/auth_gate.dart';
import 'package:onecup/screens/home_screen.dart';
import 'package:onecup/screens/my_bar_screen.dart';
import 'package:onecup/screens/profile_screen.dart';
import 'package:onecup/screens/shopping_list_screen.dart';
import 'package:onecup/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://hwclphuicumabcijhtve.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3Y2xwaHVpY3VtYWJjaWpodHZlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI5NzM3NjUsImV4cCI6MjA2ODU0OTc2NX0.VsajfU3TA52CJ4r8mwAKZUm5rr89CdKTEVAHYdeGzw4',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneCup',
      theme: AppTheme.lightTheme,
      // [核心改造] 应用的 home 现在直接是 MainTabsScreen
      home: const MainTabsScreen(),
      localizationsDelegates: [
        FlutterQuillLocalizations.delegate
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}

// MainTabsScreen 类保持不变
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
    const ProfileScreen(),
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
      body: IndexedStack(
        index: _selectedPageIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: _selectPage,
        currentIndex: _selectedPageIndex,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.liquor_outlined),
            activeIcon: Icon(Icons.liquor),
            label: '我的酒柜',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: '购物清单',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}