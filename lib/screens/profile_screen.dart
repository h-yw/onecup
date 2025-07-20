// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:onecup/common/show_top_banner.dart';
import 'package:onecup/database/supabase_service.dart';
import 'package:onecup/screens/auth/auth_screen.dart'; // [新增] 导入 AuthScreen
import 'package:onecup/screens/my_creations_screen.dart';
import 'package:onecup/screens/my_favorites_screen.dart';
import 'package:onecup/screens/my_notes_screen.dart';
import 'package:onecup/widgets/profile_stat_card.dart';
import 'package:onecup/screens/create_recipe_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // [新增] 导入 Supabase

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseService _dbHelper = SupabaseService();

  // [修改] 将 Future 声明移至需要它们的地方
  // late Future<int> _favoritesCountFuture;
  // late Future<int> _creationsCountFuture;
  // late Future<int> _notesCountFuture;

  @override
  Widget build(BuildContext context) {
    // [核心改造] 使用 StreamBuilder 监听登录状态
    return StreamBuilder<AuthState>(
      stream: _dbHelper.authStateChanges,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;

        if (session != null) {
          // 如果已登录，显示完整的个人资料页面
          return _buildLoggedInProfile(context, session.user);
        } else {
          // 如果是游客，显示游客专用的登录提示页面
          return _buildGuestProfile(context);
        }
      },
    );
  }

  // --- 游客视图 ---
  Widget _buildGuestProfile(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.person_pin_circle_outlined, size: 80, color: theme.primaryColor),
              const SizedBox(height: 24),
              Text(
                '登录以解锁全部功能',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                '创建和收藏您自己的鸡尾酒配方，并同步您的酒柜库存。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('登录或注册'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 登录用户视图 (大部分是您之前的代码) ---
  Widget _buildLoggedInProfile(BuildContext context, User user) {
    // 将状态加载逻辑移到这里，确保只在登录后执行
    final Future<int> favoritesCountFuture = _dbHelper.getFavoritesCount();
    final Future<int> creationsCountFuture = _dbHelper.getCreationsCount();
    final Future<int> notesCountFuture = _dbHelper.getNotesCount();

    // 在 State 中重新加载统计数据
    void reloadStats() {
      setState(() {
        // 这个 setState 只是为了触发 FutureBuilder 重建
      });
    }

    // 导航并刷新的辅助函数
    void navigateAndReload(Widget page) async {
      await Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      reloadStats();
    }

    // 登出方法
    Future<void> signOut() async {
      try {
        await _dbHelper.signOut();
        // 因为 StreamBuilder 在监听，UI会自动切换到游客视图
      } catch (e) {
        if (mounted) {
          showTopBanner(context, '登出失败: $e', isError: true);
        }
      }
    }

    final theme = Theme.of(context);
    final double topPadding = MediaQuery.of(context).padding.top;
    final double collapsedHeight = kToolbarHeight;
    const double expandedHeight = 220.0 - 80;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: expandedHeight,
            collapsedHeight: collapsedHeight,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // ... 这部分动画头部的逻辑保持不变 ...
                final double currentHeight = constraints.maxHeight;
                final double scrollProgress = ((currentHeight - collapsedHeight - topPadding) / (expandedHeight - collapsedHeight - topPadding)).clamp(0.0, 1.0);
                final baseExpandedStyle = theme.textTheme.headlineSmall ?? const TextStyle();
                final baseCollapsedStyle = theme.appBarTheme.titleTextStyle ?? const TextStyle();
                final expandedStyle = baseExpandedStyle.copyWith(inherit: false);
                final collapsedStyle = baseCollapsedStyle.copyWith(inherit: false);
                final userEmail = user.email ?? '已登录用户';
                final userSignature = '祝你调酒愉快！';

                return _buildAnimatedHeader(theme, scrollProgress, expandedStyle, collapsedStyle, userEmail, userSignature);
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsSection(favoritesCountFuture, creationsCountFuture, notesCountFuture, navigateAndReload),
                  const SizedBox(height: 24),
                  _buildSectionTitle(theme, '我的内容'),
                  _buildContentManagementList(theme, navigateAndReload),
                  const SizedBox(height: 24),
                  _buildSectionTitle(theme, '专业工具箱'),
                  _buildProToolsList(),
                  const SizedBox(height: 24),
                  _buildSectionTitle(theme, '应用'),
                  _buildAppSettingsList(signOut), // 传入登出方法
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // 其他所有 _build... 辅助方法保持不变 (仅需接收所需参数)
  Widget _buildStatsSection(
      Future<int> favoritesFuture, Future<int> creationsFuture, Future<int> notesFuture, Function(Widget) navigateAndReload) {
    return Row(
      children: [
        _buildStatFutureCard(
          icon: Icons.favorite_border,
          label: '我的收藏',
          future: favoritesFuture,
          onTap: () => navigateAndReload(const MyFavoritesScreen()),
        ),
        const SizedBox(width: 12),
        _buildStatFutureCard(
          icon: Icons.edit_note_outlined,
          label: '我的创作',
          future: creationsFuture,
          onTap: () => navigateAndReload(const MyCreationsScreen()),
        ),
        const SizedBox(width: 12),
        _buildStatFutureCard(
          icon: Icons.notes_outlined,
          label: '我的笔记',
          future: notesFuture,
          onTap: () => navigateAndReload(const MyNotesScreen()),
        ),
      ],
    );
  }

  Widget _buildStatFutureCard({
    required IconData icon,
    required String label,
    required Future<int> future,
    required VoidCallback onTap,
  }) {
    return FutureBuilder<int>(
      future: future,
      builder: (context, snapshot) {
        final count = snapshot.connectionState == ConnectionState.done && snapshot.hasData
            ? snapshot.data!.toString()
            : '-';
        return ProfileStatCard(
          icon: icon,
          label: label,
          count: count,
          onTap: onTap,
        );
      },
    );
  }

  Widget _buildContentManagementList(ThemeData theme, Function(Widget) navigateAndReload) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(
            icon: Icons.favorite_border,
            title: '我的收藏',
            onTap: () => navigateAndReload(const MyFavoritesScreen()),
          ),
          _buildListTile(
            icon: Icons.edit_note_outlined,
            title: '我的创作',
            onTap: () => navigateAndReload(const MyCreationsScreen()),
          ),
          _buildListTile(
            icon: Icons.notes_outlined,
            title: '我的笔记',
            onTap: () => navigateAndReload(const MyNotesScreen()),
          ),
          Divider(height: 1, indent: 16, endIndent: 16,color: Colors.grey[200],),
          ListTile(
            leading: Icon(Icons.add_circle_outline, color: theme.primaryColor),
            title: Text(
              '创建新配方',
              style: TextStyle(fontSize: 16, color: theme.primaryColor, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRecipeScreen()));
              setState((){});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedHeader(ThemeData theme, double scrollProgress, TextStyle expandedStyle, TextStyle collapsedStyle, String userName, String userSignature) {
    // ... 此方法实现完全不变 ...
    final double avatarStartSize = 80.0;
    final double avatarEndSize = 36.0;
    final double avatarStartTop = 50.0 - 10;
    final double avatarEndTop = MediaQuery.of(context).padding.top + (kToolbarHeight - avatarEndSize) / 2;
    final double avatarStartLeft = (MediaQuery.of(context).size.width - avatarStartSize) / 2;
    final double avatarEndLeft = 16.0;

    final double titleStartTop = avatarStartTop + avatarStartSize -8;
    final double titleEndTop = MediaQuery.of(context).padding.top;
    final double titleStartLeft = 0;
    final double titleEndLeft = avatarEndLeft + avatarEndSize + 12;

    final double signatureStartTop = titleStartTop + 36+12;

    final double currentAvatarSize = lerpDouble(avatarStartSize, avatarEndSize, 1 - scrollProgress)!;
    final double currentAvatarTop = lerpDouble(avatarStartTop, avatarEndTop, 1 - scrollProgress)!;
    final double currentAvatarLeft = lerpDouble(avatarStartLeft, avatarEndLeft, 1 - scrollProgress)!;
    final double currentTitleTop = lerpDouble(titleStartTop, titleEndTop, 1 - scrollProgress)! ;
    final double currentTitleLeft = lerpDouble(titleStartLeft, titleEndLeft, 1 - scrollProgress)!;
    final double signatureOpacity = scrollProgress > 0.5 ? (scrollProgress - 0.5) * 2 : 0;

    return Stack(
      children: [
        Positioned(
          top: currentAvatarTop,
          left: currentAvatarLeft,
          child: CircleAvatar(
            radius: currentAvatarSize / 2,
            backgroundColor: theme.primaryColor.withOpacity(0.1),
            child: Icon(Icons.person_outline, size: currentAvatarSize * 0.5, color: theme.primaryColor),
          ),
        ),
        Positioned(
          top: currentTitleTop,
          left: currentTitleLeft,
          right: (1 - scrollProgress) * 16.0,
          height: kToolbarHeight,
          child: Align(
            alignment: Alignment.lerp(Alignment.center, Alignment.centerLeft, 1 - scrollProgress)!,
            child: Text(
              userName, // 使用动态用户名
              style: TextStyle.lerp(expandedStyle, collapsedStyle, 1 - scrollProgress),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Positioned(
          top: signatureStartTop,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: signatureOpacity,
            child: Text(
              userSignature, // 使用动态签名
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildProToolsList() {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(
            icon: Icons.science_outlined,
            title: 'ABV 计算器',
            onTap: () => showTopBanner(context, 'ABV 计算器正在开发中，敬请期待！'),
          ),
          _buildListTile(
            icon: Icons.calculate_outlined,
            title: '批量计算器',
            onTap: () => showTopBanner(context, '批量计算器正在开发中，敬请期待！'),
          ),
          _buildListTile(
            icon: Icons.water_drop_outlined,
            title: '糖浆计算器',
            onTap: () => showTopBanner(context, '糖浆计算器正在开发中，敬请期待！'),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({ required IconData icon, required String title, required VoidCallback onTap, Color? color}) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: color ?? theme.primaryColor),
      title: Text(title, style: TextStyle(fontSize: 16, color: color)),
      trailing: color == null ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey) : null,
      onTap: onTap,
    );
  }
  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.textTheme.bodySmall?.color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAppSettingsList(VoidCallback onSignOut) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(
            icon: Icons.settings_outlined,
            title: '设置',
            onTap: () => showTopBanner(context, '“设置”功能正在开发中，敬请期待！'),
          ),
          _buildListTile(
            icon: Icons.share_outlined,
            title: '分享应用',
            onTap: () => showTopBanner(context, '“分享”功能正在开发中，敬请期待！'),
          ),
          _buildListTile(
            icon: Icons.info_outline,
            title: '关于',
            onTap: () => showTopBanner(context, '“关于”功能正在开发中，敬请期待！'),
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[200]),
          _buildListTile(
            icon: Icons.logout,
            title: '退出登录',
            onTap: onSignOut,
            color: theme.colorScheme.error,
          ),
        ],
      ),
    );
  }

}