// lib/widgets/glass_selection_dialog.dart
import 'package:flutter/material.dart';

class GlassSelectionDialog extends StatefulWidget {
  final List<String> allGlassNames;
  final String? currentSelectedGlass;

  const GlassSelectionDialog({
    super.key,
    required this.allGlassNames,
    this.currentSelectedGlass,
  });

  @override
  State<GlassSelectionDialog> createState() => _GlassSelectionDialogState();
}

class _GlassSelectionDialogState extends State<GlassSelectionDialog> {
  late List<String> _filteredGlassNames;
  String? _locallySelectedGlass;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 初始时，显示所有杯具，并选中当前已选的杯具（如果有）
    _filteredGlassNames = List.from(widget.allGlassNames); // 创建一个可修改的副本
    _locallySelectedGlass = widget.currentSelectedGlass;
    _searchController.addListener(_filterGlasses);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterGlasses);
    _searchController.dispose();
    super.dispose();
  }

  void _filterGlasses() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredGlassNames = List.from(widget.allGlassNames);
      } else {
        _filteredGlassNames = widget.allGlassNames.where((glass) {
          return glass.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择杯具类型'),
      contentPadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0), // 调整内边距
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6, // 限制对话框最大高度
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true, // 自动聚焦搜索框
              decoration: InputDecoration(
                labelText: '搜索杯具',
                hintText: '输入杯具名称...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                // 添加清除按钮
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    // _filterGlasses(); // _searchController 的监听器会自动调用
                  },
                )
                    : null,
              ),
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: _filteredGlassNames.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    '未找到匹配的杯具类型。',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredGlassNames.length,
                itemBuilder: (context, index) {
                  final glassName = _filteredGlassNames[index];
                  return RadioListTile<String>(
                    title: Text(glassName),
                    value: glassName,
                    groupValue: _locallySelectedGlass,
                    onChanged: (String? value) {
                      setState(() {
                        _locallySelectedGlass = value;
                      });
                      // 选中后可以直接关闭对话框并返回值
                      // Navigator.of(context).pop(_locallySelectedGlass);
                    },
                    // 增加选中时的视觉效果
                    selected: _locallySelectedGlass == glassName,
                    activeColor: Theme.of(context).primaryColor,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      actions: [
        TextButton(
          child: const Text('取消'),
          onPressed: () => Navigator.of(context).pop(), // 不返回任何值，保持原有选择
        ),
        FilledButton(
          child: const Text('确定'),
          onPressed: _locallySelectedGlass == null && widget.currentSelectedGlass == null
              ? null // 如果没有初始选择，且用户也没选，则禁用确定按钮
              : () {
            Navigator.of(context).pop(_locallySelectedGlass ?? widget.currentSelectedGlass);
          },
        ),
      ],
    );
  }
}
