// lib/screens/recipe_detail_screen.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onecup/common/login_prompt_dialog.dart';
import 'package:onecup/common/show_top_banner.dart';
import 'package:onecup/database/supabase_service.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/screens/edit_note_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({Key? key, required this.recipe}) : super(key: key);

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final SupabaseService _dbHelper = SupabaseService();
  late Future<List<Map<String, dynamic>>> _ingredientsFuture;
  late Future<List<String>> _tagsFuture;
  late Future<double?> _abvFuture;
  late Future<String?> _noteFuture;

  bool _isFavorited = false;
  bool _isUserCreated = false;
  bool _hasNote = false;
  // 收藏状态最终是否变
  bool _didFavoriteChange = false;
  // 存储进入页面时的收藏状态
  bool _initialIsFavorited = false;
  bool _isToggleFavoriteInProgress = false;
  bool _isAddingToShoppingList = false;

  @override
  void initState() {
    super.initState();
    _isUserCreated = widget.recipe.userId != null;
    _loadAllAsyncData();
    _fetchInitialFavoriteStatus();
  }

  void _loadAllAsyncData() {
    if (!mounted) return;
    if(widget.recipe.id==null)   return;
    setState(() {
      if (!_isUserCreated) {
        _ingredientsFuture = _dbHelper.getIngredientsForRecipe(widget.recipe.id!);
        _tagsFuture = _dbHelper.getRecipeTags(widget.recipe.id!);
        _abvFuture = _dbHelper.getRecipeABV(widget.recipe.id!);
      }
      if (_dbHelper.currentUser != null) {
        _checkIfFavorited();
        _loadNoteStatus();
      }
    });
  }

  void _checkIfFavorited() async {
    if (_dbHelper.currentUser == null) return;
    if(widget.recipe.id==null)   return;
    final isFav = await _dbHelper.isRecipeFavorite(widget.recipe.id!);
    if (mounted) {
      setState(() {
        _isFavorited = isFav;
      });
    }
  }

  void _loadNoteStatus() async {
    if (_dbHelper.currentUser == null) return;
    if(widget.recipe.id==null)   return;
    _noteFuture = _dbHelper.getRecipeNote(widget.recipe.id!);
    final noteContent = await _noteFuture;
    if (mounted) {
      setState(() {
        _hasNote = noteContent != null && noteContent.isNotEmpty && noteContent != '[]';
      });
    }
  }

  void _fetchInitialFavoriteStatus() async {
    if (mounted) {
      setState(() {
        _initialIsFavorited = _isFavorited; // 在 _isFavorited 初始化后记录初始状态
        _didFavoriteChange = false; // 初始时，当然没有变化
      });
    }
  }
  // 统一的乐观更新逻辑
  void _toggleFavorite() async {
    if (_dbHelper.currentUser == null) {
      showLoginPromptDialog(context);
      return;
    }
    if (_isToggleFavoriteInProgress)  return;
    setState(() {
      _isToggleFavoriteInProgress = true;
    });
    // 当前的 _isFavorited 值
    final currentFavoritedStateBeforeToggle = _isFavorited;
    // 乐观更新
    setState(() {
      _isFavorited = !currentFavoritedStateBeforeToggle;
      // _didFavoriteChange 在操作完成后根据 _initialIsFavorited 更新
    });
    // 在后台执行数据库操作
    try {
      if(widget.recipe.id==null){
        return;
      }
      if (currentFavoritedStateBeforeToggle) {
        // 如果之前是已收藏，则执行移除操作
        await _dbHelper.removeRecipeFromFavorites(widget.recipe.id!);
        // 为成功操作提供一个可选的、非阻塞的提示
        if (mounted) showTopBanner(context, '已取消收藏');
      } else {
        // 如果之前是未收藏，则执行添加操作
        await _dbHelper.addRecipeToFavorites(widget.recipe.id!);
        if (mounted) showTopBanner(context, '已添加到收藏');
      }
    } catch (e) {
      if (mounted) {
        showTopBanner(context, '操作失败，请重试', isError: true);
        if (e is PostgrestException && e.code == '23505' && !currentFavoritedStateBeforeToggle) {
          // 尝试添加时遇到重复键，说明已存在
          setState(() {
            _isFavorited = true; // 同步为已收藏
          });
          showTopBanner(context, '已在您的收藏中');
        } else {
          // 其他错误，回滚到操作前的状态
          setState(() {
            _isFavorited = currentFavoritedStateBeforeToggle;
          });
        }
      }
    }finally{
      if (mounted) {
        setState(() {
          _isToggleFavoriteInProgress = false;
          // 关键：在所有操作完成后，根据初始状态决定 _didFavoriteChange
          _didFavoriteChange = (_isFavorited != _initialIsFavorited);
        });
      }
    }
  }

  void _addAllIngredientsToShoppingList() async {
    if (_dbHelper.currentUser == null) {
      showLoginPromptDialog(context);
      return;
    }
    if (_isAddingToShoppingList) return;
    setState(() {
      _isAddingToShoppingList = true;
    });
    try {
      if(widget.recipe.id==null){
        return;
      }
      await _dbHelper.addRecipeIngredientsToShoppingList(widget.recipe.id!);
      if (mounted) {
        showTopBanner(context, '“${widget.recipe.name}”的全部配料已添加到购物清单！');
      }
    } catch (e) {
      // 可以在这里处理特定的错误，或者显示一个通用的错误提示
      if (mounted) {
        showTopBanner(context, '添加到购物清单失败，请稍后重试。', isError: true);
        if (kDebugMode) {
          print('添加到购物清单时发生错误: $e');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToShoppingList = false;
        });
      }
    }
  }

  void _navigateToEditNote() async {
    if (_dbHelper.currentUser == null) {
      showLoginPromptDialog(context);
      return;
    }
    final currentNote = await _noteFuture;
    if(widget.recipe.id==null){
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditNoteScreen(
          recipeId: widget.recipe.id!,
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

    return PopScope(
      canPop: !_isAddingToShoppingList,
      onPopInvokedWithResult: (didPop,result){
        if(didPop) return;
        Navigator.pop(context, _didFavoriteChange);
      },
      child: Scaffold(
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
            leading: BackButton(color: theme.appBarTheme.iconTheme?.color,onPressed: (){
              if (!_isAddingToShoppingList) {
                Navigator.pop(context, _didFavoriteChange);
              }
            },),
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
      )
    );
  }

  // ... 其他所有 _build... 辅助方法保持不变 ...
  Widget _buildMakingProcessCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: _isUserCreated
          ? _buildUserCreatedProcess(theme)
          : _buildStandardProcess(theme),
    );
  }

  Widget _buildStandardProcess(ThemeData theme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
        future: _ingredientsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) { // 添加错误处理
            return Center(child: Text('加载配料失败: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Text('暂无配方信息。');
          }

          final ingredients = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInternalSectionHeader(theme, icon: Icons.format_list_bulleted_rounded, title: '配料清单'),
              const SizedBox(height: 12),
              ...ingredients.map((ing) => _buildIngredientRow(theme, ing)),
              const SizedBox(height: 16),
              Center(
                child:TextButton.icon(
                  onPressed:_isAddingToShoppingList ? null : _addAllIngredientsToShoppingList,
                  icon:  _isAddingToShoppingList
                      ? SizedBox( // 使用 Container 来约束加载指示器的大小
                    width: 18, // 与原始图标大小相似
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0, // 可以调整线条粗细
                      valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor), // 与主题颜色一致
                    ),
                  )
                      : const Icon(Icons.add_shopping_cart_outlined, size: 18),
                  label: const Text('全部加入购物清单'),
                  style: TextButton.styleFrom(
                    disabledForegroundColor:Colors.grey.withValues(alpha: 0.5) ,
                      foregroundColor: theme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                ),
              ),
              const Divider(height: 32),

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

  Widget _buildInternalSectionHeader(ThemeData theme, {required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.primaryColor),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontSize: 18)),
      ],
    );
  }

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
    final imagePath = widget.recipe.imageUrl;
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