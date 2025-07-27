// lib/screens/profile_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui';
import 'package:onecup/common/show_top_banner.dart';
import 'package:onecup/database/supabase_service.dart';
import 'package:onecup/screens/abv_calculator_screen.dart';
import 'package:onecup/screens/auth/auth_screen.dart';
import 'package:onecup/screens/batch_calculator_screen.dart';
import 'package:onecup/screens/my_creations_screen.dart';
import 'package:onecup/screens/my_favorites_screen.dart';
import 'package:onecup/screens/my_notes_screen.dart';
import 'package:onecup/screens/settings_screen.dart';
import 'package:onecup/widgets/profile_stat_card.dart';
import 'package:onecup/screens/create_recipe_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseService _dbHelper = SupabaseService();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用 StreamBuilder 监听登录状态
    return StreamBuilder<AuthState>(
      stream: _dbHelper.authStateChanges,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        final user = session?.user;
        if (user != null) {
          // 如果已登录，显示完整的个人资料页面
          return _buildLoggedInProfile(context, user);
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

    // 从 userMetadata 获取昵称和头像 URL
    final String? nickname = _dbHelper.getUserNickname(user);
    final String? avatarUrl = _dbHelper.getAvatarUrl(user);
    final String displayName = nickname ?? user.email?.split('@').first ?? '用户';

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
                final double currentHeight = constraints.maxHeight;
                final double scrollProgress = ((currentHeight - collapsedHeight - topPadding) / (expandedHeight - collapsedHeight - topPadding)).clamp(0.0, 1.0);
                final baseExpandedStyle = theme.textTheme.headlineSmall ?? const TextStyle();
                final baseCollapsedStyle = theme.appBarTheme.titleTextStyle ?? const TextStyle();
                final expandedStyle = baseExpandedStyle.copyWith(inherit: false);
                final collapsedStyle = baseCollapsedStyle.copyWith(inherit: false);
                final userEmail = user.email ?? '已登录用户';
                final userSignature = '祝你调酒愉快！';

                return _buildAnimatedHeader(
                  context: context, // 传递 context
                  theme: theme,
                  scrollProgress: scrollProgress,
                  expandedStyle: expandedStyle,
                  collapsedStyle: collapsedStyle,
                  user: user, // 传递整个 User 对象
                  displayName: displayName,
                  avatarUrl: avatarUrl,
                );
                // return _buildAnimatedHeader(theme, scrollProgress, expandedStyle, collapsedStyle, userEmail, userSignature);
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
          /*ListTile(
            leading: Icon(Icons.add_circle_outline, color: theme.primaryColor),
            title: Text(
              '创建新配方',
              style: TextStyle(fontSize: 16, color: theme.primaryColor, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRecipeScreen()));
              setState((){});
            },
          ),*/
        ],
      ),
    );
  }

  Widget _buildAnimatedHeader({
    required BuildContext context, // 新增
    required ThemeData theme,
    required double scrollProgress,
    required TextStyle expandedStyle,
    required TextStyle collapsedStyle,
    required User user, // 接收 User 对象
    required String displayName,
    required String? avatarUrl,
  }) {
    final double avatarStartSize = 80.0;
    final double avatarEndSize = 36.0;
    final double avatarStartTop = 40.0; // 调整起始位置
    final double avatarEndTop = MediaQuery.of(context).padding.top + (kToolbarHeight - avatarEndSize) / 2;
    final double avatarStartLeft = (MediaQuery.of(context).size.width - avatarStartSize) / 2;
    final double avatarEndLeft = 16.0;

    final double titleStartTop = avatarStartTop + avatarStartSize + 8;
    final double titleEndTop = MediaQuery.of(context).padding.top;
    final double titleStartLeft = 0; // 居中
    final double titleEndLeft = avatarEndLeft + avatarEndSize + 12;

    final double editIconOpacity = scrollProgress; // 编辑按钮只在展开时明显可见

    final double currentAvatarSize = lerpDouble(avatarStartSize, avatarEndSize, 1 - scrollProgress)!;
    final double currentAvatarTop = lerpDouble(avatarStartTop, avatarEndTop, 1 - scrollProgress)!;
    final double currentAvatarLeft = lerpDouble(avatarStartLeft, avatarEndLeft, 1 - scrollProgress)!;
    final double currentTitleTop = lerpDouble(titleStartTop, titleEndTop, 1 - scrollProgress)!;
    final double currentTitleLeft = lerpDouble(titleStartLeft, titleEndLeft, 1 - scrollProgress)!;
    final double currentTitleContainerWidth = lerpDouble(MediaQuery.of(context).size.width, MediaQuery.of(context).size.width - titleEndLeft - 16, 1 - scrollProgress)!;


    Widget avatarWidget;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarWidget = CircleAvatar(
        radius: currentAvatarSize / 2,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: theme.primaryColor.withOpacity(0.1),
      );
    } else {
      avatarWidget = CircleAvatar(
        radius: currentAvatarSize / 2,
        backgroundColor: theme.primaryColor.withOpacity(0.1),
        child: Icon(Icons.person_outline, size: currentAvatarSize * 0.5, color: theme.primaryColor),
      );
    }

    return Stack(
      children: [
        // 头像
        Positioned(
          top: currentAvatarTop,
          left: currentAvatarLeft,
          child:  avatarWidget,
        ),

        // 用户名和编辑按钮
        Positioned(
          top: currentTitleTop,
          left: currentTitleLeft,
          width: currentTitleContainerWidth,
          height: kToolbarHeight, // 保持与 AppBar 标题区域同高
          child: Row(
            mainAxisAlignment: scrollProgress > 0.5 ? MainAxisAlignment.center : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center, // 垂直居中
            children: [
              Flexible( // 确保文本不会溢出
                child: Text(
                  displayName,
                  style: TextStyle.lerp(expandedStyle, collapsedStyle, 1 - scrollProgress),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // 签名 (如果需要，之前的逻辑)
        // Positioned(
        //   top: signatureStartTop,
        //   left: 0,
        //   right: 0,
        //   child: Opacity(
        //     opacity: signatureOpacity,
        //     child: Text(
        //       userSignature,
        //       textAlign: TextAlign.center,
        //       style: theme.textTheme.bodyMedium,
        //     ),
        //   ),
        // ),
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
            onTap: () => {
            //   AbvCalculatorScreen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AbvCalculatorScreen()),
              )
            },
          ),
          _buildListTile(
            icon: Icons.calculate_outlined,
            title: '批量计算器',
            onTap: () => {

              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BatchCalculatorScreen()),
              )
            },
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
            onTap: () =>
            {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) {
                // 当从 SettingsScreen (或其子页面如 EditProfileScreen) 返回时，
                // authStateChanges stream 应该会处理用户数据的更新。
                // 如果有其他需要在 ProfileScreen 上立即刷新的数据，可以在这里处理。
                // 例如，如果 EditProfileScreen 改变了用户数据，StreamBuilder 应该会自动重建。
                setState(() {}); // 强制重建以获取最新的 user metadata (如果 stream 不够快)
              })
            },
          )
        ],
      ),
    );
  }

}