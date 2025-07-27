// lib/widgets/searchable_selection_dialog.dart
import 'package:flutter/material.dart';

class SearchableSelectionDialog extends StatefulWidget {
  final List<String> allItems;
  final String? currentSelectedItem;
  final String title;
  final String searchHintText;
  final String noResultsText;

  const SearchableSelectionDialog({
    Key? key,
    required this.allItems,
    this.currentSelectedItem,
    required this.title,
    this.searchHintText = '搜索...',
    this.noResultsText = '未找到匹配项。',
  }) : super(key: key);

  @override
  State<SearchableSelectionDialog> createState() => _SearchableSelectionDialogState();
}

class _SearchableSelectionDialogState extends State<SearchableSelectionDialog> {
  late List<String> _filteredItems;
  String? _locallySelectedItem;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(widget.allItems);
    _locallySelectedItem = widget.currentSelectedItem;
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(widget.allItems);
      } else {
        _filteredItems = widget.allItems.where((item) {
          return item.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: widget.searchHintText,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                )
                    : null,
              ),
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: _filteredItems.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    widget.noResultsText,
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final itemName = _filteredItems[index];
                  return RadioListTile<String>(
                    title: Text(itemName),
                    value: itemName,
                    groupValue: _locallySelectedItem,
                    onChanged: (String? value) {
                      setState(() {
                        _locallySelectedItem = value;
                      });
                      // Optional: Select and immediately pop
                      // Navigator.of(context).pop(_locallySelectedItem);
                    },
                    selected: _locallySelectedItem == itemName,
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          child: const Text('确定'),
          onPressed: _locallySelectedItem == null && widget.currentSelectedItem == null
              ? null
              : () => Navigator.of(context).pop(_locallySelectedItem ?? widget.currentSelectedItem),
        ),
      ],
    );
  }
}
