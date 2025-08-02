// lib/screens/recipe_detail_screen.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecup/common/login_prompt_dialog.dart';
import 'package:onecup/common/show_top_banner.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/providers/auth_provider.dart';
import 'package:onecup/providers/cocktail_providers.dart';
import 'package:onecup/screens/batch_calculator_screen.dart';
import 'package:onecup/screens/edit_note_screen.dart';
import 'package:onecup/widgets/recipe_share_card.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase/supabase.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({Key? key, required this.recipe}) : super(key: key);

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  bool _isFavorited = false;
  bool _isUserCreated = false;
  bool _didFavoriteChange = false;
  bool _initialIsFavorited = false;
  bool _isToggleFavoriteInProgress = false;
  bool _isAddingToShoppingList = false;
  bool _isSharing = false;
  Map<String, dynamic>? _shareableRecipeData;

  final GlobalKey _shareBoundaryKey = GlobalKey();
  bool _canShare = false;

  @override
  void initState() {
    super.initState();
    _isUserCreated = widget.recipe.userId != null;
    // 初始加载收藏状态和笔记状态
    if (widget.recipe.id != null) {
      _checkIfFavorited();
      _updateCanShareStatus(); // 新增：更新分享状态
    }
  }

  void _updateCanShareStatus() {
    debugPrint('[_updateCanShareStatus] Called for recipe ID: ${widget.recipe.id}');
    if (widget.recipe.id == null) {
      debugPrint('[_updateCanShareStatus] recipe.id is null, returning.');
      return;
    }

    if (_isUserCreated) {
      final newCanShare = widget.recipe.instructions != null && widget.recipe.instructions!.isNotEmpty;
      debugPrint('[_updateCanShareStatus] User created recipe. _canShare will be: $newCanShare');
      setState(() {
        _canShare = newCanShare;
      });
    } else {
      // For non-user-created recipes, determine initial _canShare based on ingredients
      final initialIngredientsAsyncValue = ref.read(recipeIngredientsProvider(widget.recipe.id!));
      debugPrint('[_updateCanShareStatus] Non-user created recipe. Initial ingredients async value: $initialIngredientsAsyncValue');

      // Set initial _canShare state
      final initialCanShare = initialIngredientsAsyncValue.hasValue && initialIngredientsAsyncValue.value != null && initialIngredientsAsyncValue.value!.isNotEmpty;
      debugPrint('[_updateCanShareStatus] Initial _canShare based on ingredients: $initialCanShare');
      setState(() {
        _canShare = initialCanShare;
      });

      // Listen for subsequent changes
      ref.listenManual(recipeIngredientsProvider(widget.recipe.id!), (previous, next) {
        debugPrint('[_updateCanShareStatus] Listener triggered for recipeIngredientsProvider. Previous: $previous, Next: $next');
        final newCanShare = next.hasValue && next.value != null && next.value!.isNotEmpty;
        debugPrint('[_updateCanShareStatus] Listener calculated newCanShare: $newCanShare. Current _canShare: $_canShare');
        if (_canShare != newCanShare) { // Only update if the state actually changes
          setState(() {
            _canShare = newCanShare;
            debugPrint('[_updateCanShareStatus] _canShare updated to: $_canShare');
          });
        }
      });
    }
  }

  void _checkIfFavorited() async {
    if (ref.read(currentUserProvider) == null) return;
    if (widget.recipe.id == null) return;
    final isFav = await ref.read(cocktailRepositoryProvider).isRecipeFavorite(widget.recipe.id!);
    if (mounted) {
      setState(() {
        _isFavorited = isFav;
      });
    }
  }

  void _toggleFavorite() async {
    if (ref.read(currentUserProvider) == null) {
      showLoginPromptDialog(context);
      return;
    }
    if (_isToggleFavoriteInProgress) return;
    setState(() {
      _isToggleFavoriteInProgress = true;
    });
    final currentFavoritedStateBeforeToggle = _isFavorited;
    setState(() {
      _isFavorited = !currentFavoritedStateBeforeToggle;
    });
    try {
      if (widget.recipe.id == null) {
        return;
      }
      final cocktailRepository = ref.read(cocktailRepositoryProvider);
      if (currentFavoritedStateBeforeToggle) {
        await cocktailRepository.removeRecipeFromFavorites(widget.recipe.id!);
        if (mounted) showTopBanner(context, '已取消收藏');
      } else {
        await cocktailRepository.addRecipeToFavorites(widget.recipe.id!);
        if (mounted) showTopBanner(context, '已添加到收藏');
      }
      // 收藏状态改变后，刷新推荐列表
      ref.invalidate(flavorBasedRecommendationsProvider);
      // 新增：让收藏列表和收藏数量的 Provider 失效，以通知其他页面刷新
      ref.invalidate(favoriteRecipesProvider);
      ref.invalidate(favoritesCountProvider);
    } catch (e) {
      if (mounted) {
        showTopBanner(context, '操作失败，请重试', isError: true);
        if (e is PostgrestException &&
            e.code == '23505' &&
            !currentFavoritedStateBeforeToggle) {
          setState(() {
            _isFavorited = true;
          });
          showTopBanner(context, '已在您的收藏中');
        } else {
          setState(() {
            _isFavorited = currentFavoritedStateBeforeToggle;
          });
        }
      }
    } finally {      if (mounted) {
        setState(() {
          _isToggleFavoriteInProgress = false;
          _didFavoriteChange = (_isFavorited != _initialIsFavorited);
        });
      }
    }
  }

  void _addAllIngredientsToShoppingList() async {
    if (ref.read(currentUserProvider) == null) {
      showLoginPromptDialog(context);
      return;
    }
    if (_isAddingToShoppingList) return;
    setState(() {
      _isAddingToShoppingList = true;
    });
    try {
      if (widget.recipe.id == null) {
        return;
      }
      await ref.read(cocktailRepositoryProvider).addRecipeIngredientsToShoppingList(widget.recipe.id!);
      if (mounted) {
        showTopBanner(context, '“${widget.recipe.name}”的全部配料已添加到购物清单！');
        ref.invalidate(shoppingListProvider); // 刷新购物清单
      }
    } catch (e) {
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
    if (ref.read(currentUserProvider) == null) {
      showLoginPromptDialog(context);
      return;
    }
    final currentNoteAsyncValue = ref.read(recipeNoteProvider(widget.recipe.id!));
    final currentNote = currentNoteAsyncValue.value;
    if (widget.recipe.id == null) {
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
      ref.invalidate(recipeNoteProvider(widget.recipe.id!)); // 刷新笔记状态
      ref.invalidate(notesCountProvider); // 刷新笔记总数
      ref.invalidate(recipesWithNotesProvider); // 刷新带笔记的食谱列表
    }
  }

  Future<void> _shareRecipeAsImage() async {
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
    });

    try {
      List<Map<String, dynamic>> ingredientsList;

      if (_isUserCreated) {
        final ingredientsString = _parseUserIngredients(
          widget.recipe.instructions,
        );
        ingredientsList = ingredientsString
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .map((line) => {'name': line.trim(), 'amount': '', 'unit': ''})
            .toList();
      } else {
        final ingredientsAsyncValue = ref.read(recipeIngredientsProvider(widget.recipe.id!));
        ingredientsList = ingredientsAsyncValue.value ?? [];
      }

      final recipeMap = widget.recipe.toMap();
      recipeMap['ingredients'] = ingredientsList;
      setState(() {
        _shareableRecipeData = recipeMap;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      RenderRepaintBoundary boundary =
          _shareBoundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) throw Exception("无法生成图片数据");
      Uint8List pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File(
        '${tempDir.path}/recipe_${widget.recipe.id}.png',
      ).create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '看看这个很棒的鸡尾酒配方: ${widget.recipe.name}!',
        subject: '来自 OneCup App 的配方分享',
      );
    } catch (e) {
      if (mounted) {
        showTopBanner(context, '分享失败: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
          _shareableRecipeData = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isAddingToShoppingList,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _didFavoriteChange);
      },
      child: Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
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
                  leading: BackButton(
                    color: theme.appBarTheme.iconTheme?.color,
                    onPressed: () {
                      if (!_isAddingToShoppingList) {
                        Navigator.pop(context, _didFavoriteChange);
                      }
                    },
                  ),
                  title: Text(
                    widget.recipe.name,
                    style: theme.appBarTheme.titleTextStyle,
                  ),
                  actions: [
                    if (_canShare)
                      _isSharing
                          ? const Padding(
                              padding: EdgeInsets.all(14.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.share_outlined),
                              tooltip: '分享配方',
                              onPressed: _shareRecipeAsImage,
                            ),
                    Consumer(builder: (context, ref, child) {
                      final noteAsync = ref.watch(recipeNoteProvider(widget.recipe.id!));
                      final hasNote = noteAsync.when(
                        data: (note) => note != null && note.isNotEmpty && note != '[]',
                        loading: () => false,
                        error: (_, __) => false,
                      );
                      return IconButton(
                        icon: Icon(
                          hasNote ? Icons.speaker_notes : Icons.notes_outlined,
                        ),
                        tooltip: hasNote ? '查看/编辑笔记' : '添加笔记',
                        onPressed: _navigateToEditNote,
                      );
                    }),
                    IconButton(
                      icon: Icon(
                        _isFavorited ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorited
                            ? theme.colorScheme.secondary
                            : theme.appBarTheme.iconTheme?.color,
                      ),
                      onPressed: _toggleFavorite,
                    ),
                    if (_canShare)
                      IconButton(
                        icon: const Icon(Icons.calculate_outlined),
                        tooltip: '批量制作',
                        onPressed: () async {
                          final ingredientsAsyncValue = ref.read(recipeIngredientsProvider(widget.recipe.id!));
                          final ingredientsList = ingredientsAsyncValue.value;
                          final Map<String,dynamic> map = Map.from(widget.recipe.toMap());
                          map['ingredients'] = ingredientsList;
                          var recipe =Recipe.fromMap(map);
                          debugPrint("map====>$map");
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  BatchCalculatorScreen(recipe: recipe),
                            ),
                          );
                        },
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
                    delegate: SliverChildListDelegate([
                      _buildInfoCard(theme),
                      const SizedBox(height: 24),

                      if (!_isUserCreated) ...[
                        _buildFlavorTagsSection(theme),
                        const SizedBox(height: 24),
                      ],

                      _buildMakingProcessCard(theme),
                      const SizedBox(height: 24),

                      if (widget.recipe.description != null &&
                          widget.recipe.description!.isNotEmpty) ...[
                        _buildSectionHeader(theme, title: '关于 & 装饰'),
                        const SizedBox(height: 12),
                        Text(
                          widget.recipe.description!,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                      ],

                      if (!_isUserCreated) ...[
                        const SizedBox(height: 16),
                        _buildSourceFooter(theme),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
            if (_isSharing && _shareableRecipeData != null)
              Positioned(
                top: -10000,
                left: 0,
                child: RepaintBoundary(
                  key: _shareBoundaryKey,
                  child: RecipeShareCard(recipe: _shareableRecipeData!),
                ),
              ),
          ],
        ),
      ),
    );
  }

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
    final ingredientsAsyncValue = ref.watch(recipeIngredientsProvider(widget.recipe.id!));
    return ingredientsAsyncValue.when(
      data: (ingredients) {
        if (ingredients.isEmpty) {
          return const Text('暂无配方信息。');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInternalSectionHeader(
              theme,
              icon: Icons.format_list_bulleted_rounded,
              title: '配料清单',
            ),
            const SizedBox(height: 12),
            ...ingredients.map((ing) => _buildIngredientRow(theme, ing)),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: _isAddingToShoppingList
                    ? null
                    : _addAllIngredientsToShoppingList,
                icon: _isAddingToShoppingList
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.primaryColor,
                          ),
                        ),
                      )
                    : const Icon(Icons.add_shopping_cart_outlined, size: 18),
                label: const Text('全部加入购物清单'),
                style: TextButton.styleFrom(
                  disabledForegroundColor: Colors.grey.withOpacity(0.5),
                  foregroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const Divider(height: 32),

            _buildInternalSectionHeader(
              theme,
              icon: Icons.receipt_long_rounded,
              title: '调制步骤',
            ),
            const SizedBox(height: 12),
            Text(
              widget.recipe.instructions ?? '暂无详细步骤。',
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.6,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('加载配料失败: $error')),
    );
  }

  Widget _buildUserCreatedProcess(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInternalSectionHeader(
          theme,
          icon: Icons.format_list_bulleted_rounded,
          title: '配料清单',
        ),
        const SizedBox(height: 12),
        Text(
          _parseUserIngredients(widget.recipe.instructions),
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.6,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
        const Divider(height: 32),
        _buildInternalSectionHeader(
          theme,
          icon: Icons.receipt_long_rounded,
          title: '调制步骤',
        ),
        const SizedBox(height: 12),
        Text(
          _parseUserInstructions(widget.recipe.instructions),
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.6,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildInternalSectionHeader(
    ThemeData theme, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildIngredientRow(ThemeData theme, Map<String, dynamic> ing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: theme.primaryColor.withOpacity(0.5),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '${ing['name']} - ${ing['amount']} ${ing['unit'] ?? ''}'.trim(),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodyMedium?.color,
              ),
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
          _buildMetadataItem(
            theme,
            Icons.category_outlined,
            '分类',
            widget.recipe.category ?? '经典',
          ),
          _buildMetadataItem(
            theme,
            Icons.local_bar_outlined,
            '杯具',
            widget.recipe.glass ?? '鸡尾酒杯',
          ),
          if (!_isUserCreated)
            Consumer(builder: (context, watch, child) {
              final abvAsyncValue = watch.watch(recipeAbvProvider(widget.recipe.id!));
              return abvAsyncValue.when(
                data: (abv) {
                  if (abv == null) {
                    return const Expanded(child: SizedBox.shrink());
                  }
                  return _buildMetadataItem(
                    theme,
                    Icons.whatshot_outlined,
                    '酒精度',
                    '${abv.toStringAsFixed(1)}%',
                  );
                },
                loading: () => const Expanded(child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))),
                error: (error, stackTrace) => const Expanded(child: SizedBox.shrink()),
              );
            }),
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

  Widget _buildMetadataItem(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: theme.primaryColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme, {
    required String title,
    Widget? action,
  }) {
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
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.3),
                    BlendMode.darken,
                  ),
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
      return rawInstructions
          .split('---INSTRUCTIONS---')[0]
          .replaceFirst('---INGREDIENTS---', '')
          .trim();
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
    final tagsAsyncValue = ref.watch(recipeTagsProvider(widget.recipe.id!));
    return tagsAsyncValue.when(
      data: (tags) {
        if (tags.isEmpty) return Text('暂无', style: theme.textTheme.bodyMedium);
        return Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: tags
              .map(
                (tag) => Chip(
                  label: Text(tag),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    color: theme.textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w500,
                  ),
                  side: BorderSide.none,
                  backgroundColor: theme.primaryColor.withOpacity(0.08),
                ),
              )
              .toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Text('加载标签失败: $error', style: theme.textTheme.bodyMedium),
    );
  }
}
