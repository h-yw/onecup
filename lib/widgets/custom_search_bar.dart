import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef SearchCallback = void Function(String query);

class CustomSearchBar extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final SearchCallback onSearchChanged;

  const CustomSearchBar({
    Key? key,
    required this.controller,
    required this.focusNode,
    required this.onSearchChanged,
  }) : super(key: key);

  @override
  ConsumerState<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends ConsumerState<CustomSearchBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {
        _hasText = widget.controller.text.isNotEmpty;
      });
    }
  }

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
    const double searchBarVPadding = 8.0;
    const double bottomAreaHeight = searchBarHeight + (searchBarVPadding * 2);

    return SliverAppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      pinned: true,
      floating: true,
      snap: false,
      elevation: 0,
      automaticallyImplyLeading: false,
      expandedHeight: 140.0,
      flexibleSpace: FlexibleSpaceBar(
        background: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              bottom: bottomAreaHeight + 8.0,
            ),
            child: Text(
              getGreeting(),
              style: theme.textTheme.headlineSmall,
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(bottomAreaHeight),
        child: Container(
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

  Widget _buildSearchBar(ThemeData theme, double height) {
    return SizedBox(
      height: height,
      child: TextField(
        focusNode: widget.focusNode,
        controller: widget.controller,
        onChanged: widget.onSearchChanged,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: '搜索鸡尾酒...',
          hintStyle: TextStyle(color: theme.hintColor),
          prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 24),
          suffixIcon: _hasText
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey, size: 22),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: theme.cardColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
          ),
        ),
      ),
    );
  }
}
