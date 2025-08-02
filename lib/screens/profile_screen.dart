
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecup/screens/settings_screen.dart';
import 'package:onecup/screens/syrup_calculator_screen.dart';
import 'package:supabase/supabase.dart';

import '../common/show_top_banner.dart';
import '../providers/auth_provider.dart';
import '../providers/cocktail_providers.dart';
import '../widgets/app_error_widget.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/common_list_tile.dart';
import '../widgets/profile_animated_header.dart';
import '../widgets/profile_stat_card.dart';
import 'abv_calculator_screen.dart';
import 'auth/auth_screen.dart';
import 'batch_calculator_screen.dart';
import 'my_creations_screen.dart';
import 'my_favorites_screen.dart';
import 'my_notes_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (state) {
        final user = state.session?.user;
        if (user != null) {
          return _buildLoggedInProfile(context, ref, user);
        } else {
          return _buildGuestProfile(context);
        }
      },
      loading: () => const Scaffold(body: AppLoadingIndicator()),
      error: (err, stack) => Scaffold(body: AppErrorWidget(error: err, stackTrace: stack)),
    );
  }

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

  Widget _buildLoggedInProfile(BuildContext context, WidgetRef ref, User user) {
    void navigateAndReload(Widget page) async {
      await Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      // No longer need to invalidate here, the source of truth will do it.
    }

    Future<void> signOut() async {
      try {
        await ref.read(authRepositoryProvider).signOut();
      } catch (e) {
        if (context.mounted) {
          showTopBanner(context, '登出失败: $e', isError: true);
        }
      }
    }

    final theme = Theme.of(context);
    final double topPadding = MediaQuery.of(context).padding.top;
    final double collapsedHeight = kToolbarHeight;
    const double expandedHeight = 220.0 - 80;

    final authRepository = ref.read(authRepositoryProvider);
    final String? nickname = authRepository.getUserNickname(user);
    final String? avatarUrl = authRepository.getAvatarUrl(user);
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
                
                return ProfileAnimatedHeader(
                  scrollProgress: scrollProgress,
                  user: user,
                  displayName: displayName,
                  avatarUrl: avatarUrl,
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsSection(ref, navigateAndReload),
                  const SizedBox(height: 24),
                  _buildSectionTitle(theme, '我的内容'),
                  _buildContentManagementList(context,theme, navigateAndReload),
                  const SizedBox(height: 24),
                  _buildSectionTitle(theme, '专业工具箱'),
                  _buildProToolsList(context),
                  const SizedBox(height: 24),
                  _buildSectionTitle(theme, '应用'),
                  _buildAppSettingsList(context, signOut),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatsSection(WidgetRef ref, void Function(Widget) navigateAndReload) {
    final favoritesCount = ref.watch(favoritesCountProvider);
    final creationsCount = ref.watch(creationsCountProvider);
    final notesCount = ref.watch(notesCountProvider);

    return Row(
      children: [
        _buildStatCard(
          icon: Icons.favorite_border,
          label: '我的收藏',
          asyncValue: favoritesCount,
          onTap: () => navigateAndReload(const MyFavoritesScreen()),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          icon: Icons.edit_note_outlined,
          label: '我的创作',
          asyncValue: creationsCount,
          onTap: () => navigateAndReload(const MyCreationsScreen()),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          icon: Icons.notes_outlined,
          label: '我的笔记',
          asyncValue: notesCount,
          onTap: () => navigateAndReload(const MyNotesScreen()),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required AsyncValue<int> asyncValue,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: asyncValue.when(
        data: (count) => ProfileStatCard(
          icon: icon,
          label: label,
          count: count.toString(),
          onTap: onTap,
        ),
        loading: () => ProfileStatCard(
          icon: icon,
          label: label,
          count: '-',
          onTap: onTap,
        ),
        error: (err, stack) => ProfileStatCard(
          icon: icon,
          label: label,
          count: '!',
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildContentManagementList(BuildContext context, ThemeData theme, void Function(Widget) navigateAndReload) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          CommonListTile(
            icon: Icons.favorite_border,
            title: '我的收藏',
            onTap: () => navigateAndReload(const MyFavoritesScreen()),
          ),
          CommonListTile(
            icon: Icons.edit_note_outlined,
            title: '我的创作',
            onTap: () => navigateAndReload(const MyCreationsScreen()),
          ),
          CommonListTile(
            icon: Icons.notes_outlined,
            title: '我的笔记',
            onTap: () => navigateAndReload(const MyNotesScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildProToolsList(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          CommonListTile(
            icon: Icons.science_outlined,
            title: 'ABV 计算器',
            onTap: () => {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AbvCalculatorScreen()),
              )
            },
          ),
          CommonListTile(
            icon: Icons.calculate_outlined,
            title: '批量计算器',
            onTap: () => {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BatchCalculatorScreen()),
              )
            },
          ),
          CommonListTile(
            icon: Icons.water_drop_outlined,
            title: '糖浆计算器',
            onTap: () => {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SyrupCalculatorScreen()),
              )
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAppSettingsList(BuildContext context, VoidCallback onSignOut) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          CommonListTile(
            icon: Icons.settings_outlined,
            title: '设置',
            onTap: () =>
            {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) {
                // No need to call setState in a stateless widget
              })
            },
          )
        ],
      ),
    );
  }
}
