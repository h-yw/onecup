// lib/screens/recipe_detail_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onecup/common/show_top_banner.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/database/database_helper.dart';
import 'package:onecup/screens/edit_note_screen.dart';
import 'package:flutter_quill/flutter_quill.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({Key? key, required this.recipe}) : super(key: key);

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Map<String, dynamic>>> _ingredientsFuture;
  late Future<List<String>> _tagsFuture;
  late Future<double?> _abvFuture;
  late Future<String?> _noteFuture;

  bool _isFavorited = false;
  bool _isUserCreated = false;
  bool _hasNote = false;

  @override
  void initState() {
    super.initState();
    _isUserCreated = widget.recipe.userId != null;
    _loadAllAsyncData();
  }

  void _loadAllAsyncData() {
    if (!mounted) return;
    setState(() {
      if (!_isUserCreated) {
        _ingredientsFuture = _dbHelper.getIngredientsForRecipe(widget.recipe.id);
        _tagsFuture = _dbHelper.getRecipeTags(widget.recipe.id);
        _abvFuture = _dbHelper.getRecipeABV(widget.recipe.id);
      }
      _checkIfFavorited();
      _loadNoteStatus();
    });
  }

  void _checkIfFavorited() async {
    final isFav = await _dbHelper.isRecipeFavorite(widget.recipe.id);
    if (mounted) {
      setState(() {
        _isFavorited = isFav;
      });
    }
  }

  void _loadNoteStatus() async {
    _noteFuture = _dbHelper.getRecipeNote(widget.recipe.id);
    final noteContent = await _noteFuture;
    if (mounted) {
      setState(() {
        _hasNote = noteContent != null && noteContent.isNotEmpty && noteContent != '[]';
      });
    }
  }

  void _toggleFavorite() async {
    if (_isFavorited) {
      await _dbHelper.removeRecipeFromFavorites(widget.recipe.id);
    } else {
      await _dbHelper.addRecipeToFavorites(widget.recipe.id);
    }
    _checkIfFavorited();
  }

  void _addAllIngredientsToShoppingList() async {
    await _dbHelper.addRecipeIngredientsToShoppingList(widget.recipe.id);
    if (mounted) {
      showTopBanner(context,'“${widget.recipe.name}”的全部配料已添加到购物清单！');
    }
  }

  void _navigateToEditNote() async {
    final currentNote = await _noteFuture;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditNoteScreen(
          recipeId: widget.recipe.id,
          recipeName: widget.recipe.name,
          initialNote: currentNote,
        ),
      ),
    );

    if (result == true && mounted) {
      _loadNoteStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: true,
            stretch: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0.8,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarBrightness: Brightness.dark,
              statusBarIconBrightness: Brightness.dark,
            ),
            leading: BackButton(color: theme.appBarTheme.iconTheme?.color),
            title: Text(widget.recipe.name, style: theme.appBarTheme.titleTextStyle),
            actions: [
              IconButton(
                icon: Icon(_hasNote ? Icons.speaker_notes : Icons.notes_outlined),
                tooltip: _hasNote ? '查看/编辑笔记' : '添加笔记',
                onPressed: _navigateToEditNote,
              ),
              IconButton(
                icon: Icon(
                  _isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorited ? theme.colorScheme.secondary : theme.appBarTheme.iconTheme?.color,
                ),
                onPressed: _toggleFavorite,
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeaderImage(),
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 40.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _buildInfoCard(theme),
                  const SizedBox(height: 24),

                  if (!_isUserCreated) ...[
                    _buildFlavorTagsSection(theme),
                    const SizedBox(height: 24),
                  ],

                  // [核心优化] 页面主体现在是一个统一的“制作流程”卡片
                  _buildMakingProcessCard(theme),
                  const SizedBox(height: 24),

                  if (widget.recipe.description != null && widget.recipe.description!.isNotEmpty) ...[
                    _buildSectionHeader(theme, title: '关于 & 装饰'),
                    const SizedBox(height: 12),
                    Text(widget.recipe.description!, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 24),
                  ],

                  if (!_isUserCreated) ...[
                    const SizedBox(height: 16),
                    _buildSourceFooter(theme),
                  ],
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // [新] 统一的制作流程卡片
  Widget _buildMakingProcessCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: _isUserCreated
          ? _buildUserCreatedProcess(theme) // 用户创建的配方使用简化版
          : _buildStandardProcess(theme),  // 标准配方使用完整版
    );
  }

  // [新] 构建标准配方的制作流程
  Widget _buildStandardProcess(ThemeData theme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
        future: _ingredientsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Text('暂无配方信息。');
          }

          final ingredients = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 配料部分
              _buildInternalSectionHeader(theme, icon: Icons.format_list_bulleted_rounded, title: '配料清单'),
              const SizedBox(height: 12),
              ...ingredients.map((ing) => _buildIngredientRow(theme, ing)),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _addAllIngredientsToShoppingList,
                  icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                  label: const Text('全部加入购物清单'),
                  style: TextButton.styleFrom(
                      foregroundColor: theme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                ),
              ),
              const Divider(height: 32),

              // 2. 步骤部分
              _buildInternalSectionHeader(theme, icon: Icons.receipt_long_rounded, title: '调制步骤'),
              const SizedBox(height: 12),
              Text(
                widget.recipe.instructions ?? '暂无详细步骤。',
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6, color: theme.textTheme.bodyMedium?.color),
              ),
            ],
          );
        });
  }

  // [新] 构建用户自创配方的制作流程
  Widget _buildUserCreatedProcess(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInternalSectionHeader(theme, icon: Icons.format_list_bulleted_rounded, title: '配料清单'),
        const SizedBox(height: 12),
        Text(
          _parseUserIngredients(widget.recipe.instructions),
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.6, color: theme.textTheme.bodyMedium?.color),
        ),
        const Divider(height: 32),
        _buildInternalSectionHeader(theme, icon: Icons.receipt_long_rounded, title: '调制步骤'),
        const SizedBox(height: 12),
        Text(
          _parseUserInstructions(widget.recipe.instructions),
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.6, color: theme.textTheme.bodyMedium?.color),
        ),
      ],
    );
  }

  // [新] 卡片内部使用的、更柔和的小标题
  Widget _buildInternalSectionHeader(ThemeData theme, {required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.primaryColor),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontSize: 18)),
      ],
    );
  }

  // [新] 构建单行配料的辅助方法
  Widget _buildIngredientRow(ThemeData theme, Map<String, dynamic> ing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: theme.primaryColor.withOpacity(0.5)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '${ing['name']} - ${ing['amount']} ${ing['unit'] ?? ''}'.trim(),
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.textTheme.bodyMedium?.color),
            ),
          ),
        ],
      ),
    );
  }

  // --- 其他所有 build 辅助方法保持不变 ---

  Widget _buildInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetadataItem(theme, Icons.category_outlined, '分类', widget.recipe.category ?? '经典'),
          _buildMetadataItem(theme, Icons.local_bar_outlined, '杯具', widget.recipe.glass ?? '鸡尾酒杯'),
          if (!_isUserCreated)
            FutureBuilder<double?>(
              future: _abvFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == null) {
                  return const Expanded(child: SizedBox.shrink());
                }
                return _buildMetadataItem(theme, Icons.whatshot_outlined, '酒精度', '${snapshot.data!.toStringAsFixed(1)}%');
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFlavorTagsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('风味标签', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _buildTagsList(theme),
      ],
    );
  }

  Widget _buildSourceFooter(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '配方来源: ${_isUserCreated ? '我的创作' : 'IBA 官方'}',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildMetadataItem(ThemeData theme, IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: theme.primaryColor, size: 24),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, {required String title, Widget? action}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        if (action != null) action,
      ],
    );
  }

  Widget _buildHeaderImage() {
    final imagePath = widget.recipe.imagePath;
    final isUrl = imagePath != null && imagePath.startsWith('http');
    return Hero(
      tag: 'recipe_${widget.recipe.id}',
      child: Container(
        decoration: BoxDecoration(
          image: isUrl
              ? DecorationImage(
            image: NetworkImage(imagePath!),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
          )
              : null,
          color: isUrl ? null : Colors.grey[200],
        ),
        child: !isUrl
            ? Icon(Icons.local_bar, size: 100, color: Colors.grey[400])
            : null,
      ),
    );
  }

  String _parseUserIngredients(String? rawInstructions) {
    if (rawInstructions == null) return '暂无配料信息。';
    try {
      return rawInstructions.split('---INSTRUCTIONS---')[0].replaceFirst('---INGREDIENTS---', '').trim();
    } catch (e) {
      return '暂无配料信息。';
    }
  }

  String _parseUserInstructions(String? rawInstructions) {
    if (rawInstructions == null) return '暂无详细步骤。';
    try {
      return rawInstructions.split('---INSTRUCTIONS---')[1].trim();
    } catch (e) {
      return rawInstructions;
    }
  }

  Widget _buildTagsList(ThemeData theme) {
    return FutureBuilder<List<String>>(
      future: _tagsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return Text('暂无', style: theme.textTheme.bodyMedium);
        return Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: snapshot.data!.map((tag) => Chip(
            label: Text(tag),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            labelStyle: TextStyle(fontSize: 13, color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.w500),
            side: BorderSide.none,
            backgroundColor: theme.primaryColor.withOpacity(0.08),
          )).toList(),
        );
      },
    );
  }
}