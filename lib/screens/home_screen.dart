import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onecup/models/receip.dart';
import 'package:onecup/providers/cocktail_providers.dart';
import 'package:onecup/screens/recipe_detail_screen.dart';
import 'package:onecup/widgets/cocktail_card.dart';
import 'package:onecup/widgets/custom_search_bar.dart';
import 'package:onecup/widgets/recommendation_card.dart';
import 'package:sliver_tools/sliver_tools.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
  }

  void _navigateToDetail(Recipe recipe) async {
    final bool? shouldRefresh = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)),
    );
    if (shouldRefresh == true && mounted) {
      ref.invalidate(allRecipesProvider);
      ref.invalidate(flavorBasedRecommendationsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allRecipesAsync = ref.watch(allRecipesProvider);
    final recommendationsAsync = ref.watch(flavorBasedRecommendationsProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              CustomSearchBar(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onSearchChanged: (query) {
                  setState(() {
                    _searchQuery = query;
                  });
                },
              ),
              if (_searchQuery.isEmpty) ...[
                _buildForYouSection(recommendationsAsync),
                _buildSectionHeader('所有配方'),
                _buildAllRecipesList(allRecipesAsync),
              ] else ...[
                _buildSectionHeader('搜索结果'),
                _buildSearchResultsList(allRecipesAsync),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForYouSection(AsyncValue<List<Recipe>> recommendationsAsync) {
    return recommendationsAsync.when(
      data: (recipes) {
        if (recipes.isEmpty) {
          // 当没有推荐时，显示一个引导卡片而不是空白
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        '发现你的专属口味',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '收藏一些你喜欢的鸡尾酒，我们会在这里为你生成个性化推荐！',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return MultiSliver(
          children: [
            _buildSectionHeader('为你推荐'),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 16),
                  itemCount: recipes.length,
                  itemBuilder: (context, index) {
                    return RecommendationCard(
                      recipe: recipes[index],
                      onTap: () => _navigateToDetail(recipes[index]),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
      loading: () => SliverToBoxAdapter(
        child: Container(
            height: 250, child: const Center(child: CircularProgressIndicator())),
      ),
      error: (error, stackTrace) =>
          SliverToBoxAdapter(child: Center(child: Text('无法加载推荐: $error'))),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }

  Widget _buildAllRecipesList(AsyncValue<List<Recipe>> allRecipesAsync) {
    return allRecipesAsync.when(
      data: (recipes) {
        if (recipes.isEmpty) {
            return const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Text('没有找到任何配方...',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                ),
              ),
            );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => CocktailCard(
                recipe: recipes[index],
                onTap: () => _navigateToDetail(recipes[index])),
            childCount: recipes.length,
          ),
        );
      },
      loading: () =>
          const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          SliverToBoxAdapter(child: Center(child: Text('无法加载配方: $error'))),
    );
  }

  Widget _buildSearchResultsList(AsyncValue<List<Recipe>> allRecipesAsync) {
    return allRecipesAsync.when(
      data: (recipes) {
        final filteredRecipes = recipes
            .where((recipe) =>
                recipe.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

        if (filteredRecipes.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Text('没有找到匹配的鸡尾酒...',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => CocktailCard(
                recipe: filteredRecipes[index],
                onTap: () => _navigateToDetail(filteredRecipes[index])),
            childCount: filteredRecipes.length,
          ),
        );
      },
      loading: () =>
          const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => SliverToBoxAdapter(
          child: Center(child: Text('无法加载搜索结果: $error'))),
    );
  }
}
