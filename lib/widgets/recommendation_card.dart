import 'package:flutter/material.dart';
import 'package:onecup/models/receip.dart';

class RecommendationCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecommendationCard({
    super.key,
    required this.recipe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imagePath = recipe.imageUrl;
    final isUrl = imagePath != null && imagePath.startsWith('http');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(left: 16),
        // [核心升级] 使用 ClipRRect 和 Stack 结构来实现图片和文字的叠加
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Stack(
            alignment: Alignment.bottomLeft, // 将子组件对齐到左下角
            children: [
              // 1. 图片部分 (作为背景)
              Positioned.fill(
                child: Hero(
                  tag: 'recipe_${recipe.id}',
                  child: isUrl
                      ? Image.network(
                    imagePath!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.local_bar, size: 40, color: Colors.grey),
                      );
                    },
                  )
                      : Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.local_bar, size: 40, color: Colors.grey),
                  ),
                ),
              ),
              // 2. [新] 渐变遮罩层
              //    这个遮罩从底部（黑色，70%不透明度）向上渐变到透明，
              //    确保下方的文字在任何图片背景下都清晰可读。
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.0),
                    ],
                    stops: const [0.0, 0.6], // 渐变范围控制在底部60%
                  ),
                ),
              ),
              // 3. 文字部分 (放置在最上层)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  recipe.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white, // 文字颜色改为白色
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    shadows: [ // 给文字添加轻微阴影，增加立体感
                      const Shadow(
                        blurRadius: 4.0,
                        color: Colors.black54,
                        offset: Offset(1.0, 1.0),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}