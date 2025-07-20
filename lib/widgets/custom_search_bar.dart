// lib/widgets/custom_search_bar.dart

import 'package:flutter/material.dart';

// 回调函数类型定义保持不变
typedef SearchCallback = void Function(String query);

class CustomSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final SearchCallback onSearchChanged;

  const CustomSearchBar({
    Key? key,
    required this.controller,
    required this.onSearchChanged,
  }) : super(key: key);

  // 获取问候语的逻辑保持不变
  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return '早上好, 调酒师!';
    } else if (hour < 18) {
      return '下午好, 今天喝点什么?';
    } else {
      return '晚上好, 来一杯放松一下?';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const double searchBarHeight = 50.0;
    // 定义搜索栏上下的垂直间距
    const double searchBarVPadding = 8.0;

    // 计算SliverAppBar底部固定区域的总高度
    const double bottomAreaHeight = searchBarHeight + (searchBarVPadding * 2);

    return SliverAppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      pinned: true,
      floating: true,
      snap: false,
      elevation: 0,
      automaticallyImplyLeading: false,
      // [核心修复] 展开高度现在是一个合理固定的值，它包含了问候语和搜索栏区域
      // 这个高度不再受Padding的影响，从而解决了顶部巨大间距的问题
      expandedHeight: 140.0,

      // [核心修复] 可折叠空间现在只负责显示问候语
      // 我们使用Align来精确定位问候语，而不是用巨大的Padding
      flexibleSpace: FlexibleSpaceBar(
        background: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              // 在问候语下方留出空间给固定的搜索栏区域
              bottom: bottomAreaHeight + 8.0, // 额外8像素的舒适距离
            ),
            child: Text(
              getGreeting(),
              style: theme.textTheme.headlineSmall,
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        // `bottom`区域的高度保持不变
        preferredSize: const Size.fromHeight(bottomAreaHeight),
        child: Container(
          // [核心修复] 将垂直内边距应用到Container上
          // 这样既能保证搜索栏上下有间距，又不影响外部布局
          padding: EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: searchBarVPadding,
          ),
          alignment: Alignment.center,
          child: _buildSearchBar(theme, searchBarHeight),
        ),
      ),
    );
  }

  // 构建搜索框UI的方法（此部分无需修改）
  Widget _buildSearchBar(ThemeData theme, double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.0),
            child: Icon(Icons.search, color: Colors.grey, size: 22),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: '搜索鸡尾酒...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey, size: 22),
              onPressed: () {
                controller.clear();
                onSearchChanged('');
              },
            ),
        ],
      ),
    );
  }
}