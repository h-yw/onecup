
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:onecup/screens/my_bar_screen.dart';
import 'package:onecup/screens/profile_screen.dart';
import 'package:onecup/screens/recipe_detail_screen.dart';
import 'package:onecup/screens/auth/auth_gate.dart';
import 'package:onecup/screens/home_screen.dart';
import 'package:onecup/screens/shopping_list_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecup/providers/theme_provider.dart'; // 导入主题提供者
import 'package:onecup/repositories/cocktail_repository.dart';
import 'package:onecup/repositories/supabase_repository.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

final cocktailRepositoryProvider = Provider<CocktailRepository>((ref) {
  return SupabaseRepository(Supabase.instance.client);
});

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await dotenv.load(fileName: ".env"); // 加载 .env 文件
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!, // 从 .env 读取
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!, // 从 .env 读取
  );
  FlutterNativeSplash.remove();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
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

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _navigateToRecipe(uri);
    });

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
          final cocktailRepository = ref.read(cocktailRepositoryProvider);
          final recipe = await cocktailRepository.getRecipeById(recipeId);
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
    ref.watch(themeProvider); // 直接监听主题模式的变化
    final ThemeData currentThemeData = ref.read(themeProvider.notifier).currentTheme; // 根据当前主题模式获取 ThemeData

    return MaterialApp(
      title: 'OneCup',
      theme: currentThemeData, // 使用获取到的 ThemeData
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
