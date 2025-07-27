
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:onecup/database/supabase_service.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/screens/my_bar_screen.dart';
import 'package:onecup/screens/profile_screen.dart';
import 'package:onecup/screens/recipe_detail_screen.dart';
import 'package:onecup/screens/auth/auth_gate.dart';
import 'package:onecup/screens/home_screen.dart';
import 'package:onecup/screens/shopping_list_screen.dart';
import 'package:onecup/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart'; // Using app_links

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://hwclphuicumabcijhtve.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3Y2xwaHVpY3VtYWJjaWpodHZlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI5NzM3NjUsImV4cCI6MjA2ODU0OTc2NX0.VsajfU3TA52CJ4r8mwAKZUm5rr89CdKTEVAHYdeGzw4',
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle links when the app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _navigateToRecipe(uri);
    });

    // Handle the link that opened the app
    final initialUri = await _appLinks.getInitialAppLink();
    if (initialUri != null) {
      _navigateToRecipe(initialUri);
    }
  }

  void _navigateToRecipe(Uri uri) async {
    if (uri.host == 'recipe' && uri.pathSegments.isNotEmpty) {
      final recipeId = int.tryParse(uri.pathSegments.first);
      if (recipeId != null) {
        try {
          final supabaseService = SupabaseService();
          final recipe = await supabaseService.getRecipeById(recipeId);
          if (recipe != null && navigatorKey.currentState != null) {
            navigatorKey.currentState!.push(
              MaterialPageRoute(
                builder: (context) => RecipeDetailScreen(recipe: recipe),
              ),
            );
          }
        } catch (e) {
          // Handle error
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneCup',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
      localizationsDelegates: [
        FlutterQuillLocalizations.delegate
      ],
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
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
