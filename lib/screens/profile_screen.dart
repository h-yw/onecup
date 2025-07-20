// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:onecup/common/show_top_banner.dart';
import 'package:onecup/database/database_helper.dart';
import 'package:onecup/screens/my_creations_screen.dart';
import 'package:onecup/screens/my_favorites_screen.dart';
import 'package:onecup/screens/my_notes_screen.dart';
import 'package:onecup/widgets/profile_stat_card.dart';
import 'package:onecup/screens/create_recipe_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  late Future<int> _favoritesCountFuture;
  late Future<int> _creationsCountFuture;
  late Future<int> _notesCountFuture;

  final String _userName = '调酒师';
  final IconData _userAvatarIcon = Icons.person_outline;
  final String _userSignature = '开始你的第一杯创作吧！';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    setState(() {
      _favoritesCountFuture = _dbHelper.getFavoriteRecipes().then((l) => l.length);
      _creationsCountFuture = _dbHelper.getUserCreatedRecipes().then((l) => l.length);
      _notesCountFuture = _dbHelper.getRecipesWithNotes().then((l) => l.length);
    });
  }

  void _navigateAndReload(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    _loadStats();
  }

  void _navigateToCreateRecipe() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRecipeScreen()));
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double topPadding = MediaQuery.of(context).padding.top;
    final double collapsedHeight = kToolbarHeight;
    const double expandedHeight = 220.0 - 80;

    return Scaffold(
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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

                return _buildAnimatedHeader(theme, scrollProgress, expandedStyle, collapsedStyle);
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsSection(),
                  // [修复2] 调整内容区域间距
                  const SizedBox(height: 24),
                  _buildSectionTitle(theme, '我的内容'),
                  _buildContentManagementList(theme), // 传入theme以供样式使用
                  const SizedBox(height: 24),
                  _buildSectionTitle(theme, '专业工具箱'),
                  _buildProToolsList(),
                  const SizedBox(height: 24),
                  _buildSectionTitle(theme, '应用'),
                  _buildAppSettingsList(),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // [修复3] 重构“我的内容”列表，将创建按钮变为独立的操作行
  Widget _buildContentManagementList(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(
            icon: Icons.favorite_border,
            title: '我的收藏',
            onTap: () => _navigateAndReload(const MyFavoritesScreen()),
          ),
          _buildListTile(
            icon: Icons.edit_note_outlined,
            title: '我的创作',
            onTap: () => _navigateAndReload(const MyCreationsScreen()),
          ),
          _buildListTile(
            icon: Icons.notes_outlined,
            title: '我的笔记',
            onTap: () => _navigateAndReload(const MyNotesScreen()),
          ),
          // 分割线，将操作与导航分开
          Divider(height: 1, indent: 16, endIndent: 16,color: Colors.grey[200],),
          // 一个样式独特的“创建”操作行
          ListTile(
            leading: Icon(Icons.add_circle_outline, color: theme.primaryColor),
            title: Text(
              '创建新配方',
              style: TextStyle(fontSize: 16, color: theme.primaryColor, fontWeight: FontWeight.bold),
            ),
            onTap: _navigateToCreateRecipe,
          ),
        ],
      ),
    );
  }

  // [修复1 & 3] 优化后的头部动画
  Widget _buildAnimatedHeader(ThemeData theme, double scrollProgress, TextStyle expandedStyle, TextStyle collapsedStyle) {
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

    // [修复1] 调整签名的垂直位置，增加与用户名的间距
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
            child: Icon(_userAvatarIcon, size: currentAvatarSize * 0.5, color: theme.primaryColor),
          ),
        ),
        Positioned(
          top: currentTitleTop,
          left: currentTitleLeft,
          // [修复3] 确保标题容器在折叠时有正确的宽度和高度
          right: (1 - scrollProgress) * 16.0,
          height: kToolbarHeight,
          child: Align(
            alignment: Alignment.lerp(Alignment.center, Alignment.centerLeft, 1 - scrollProgress)!,
            child: Text(
              _userName,
              style: TextStyle.lerp(expandedStyle, collapsedStyle, 1 - scrollProgress),
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
              _userSignature,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }

  // --- 其余所有 build 辅助方法保持不变 ---

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

  Widget _buildListTile({ required IconData icon, required String title, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.primaryColor),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        _buildStatFutureCard(
          icon: Icons.favorite_border,
          label: '我的收藏',
          future: _favoritesCountFuture,
          onTap: () => _navigateAndReload(const MyFavoritesScreen()),
        ),
        const SizedBox(width: 12),
        _buildStatFutureCard(
          icon: Icons.edit_note_outlined,
          label: '我的创作',
          future: _creationsCountFuture,
          onTap: () => _navigateAndReload(const MyCreationsScreen()),
        ),
        const SizedBox(width: 12),
        _buildStatFutureCard(
          icon: Icons.notes_outlined,
          label: '我的笔记',
          future: _notesCountFuture,
          onTap: () => _navigateAndReload(const MyNotesScreen()),
        ),
      ],
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

  Widget _buildAppSettingsList() {
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
        ],
      ),
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
}