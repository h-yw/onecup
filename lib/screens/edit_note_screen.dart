// lib/screens/edit_note_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:onecup/common/show_top_banner.dart';
import 'package:onecup/database/supabase_service.dart';

class EditNoteScreen extends StatefulWidget {
  final int recipeId;
  final String recipeName;
  final String? initialNote;

  const EditNoteScreen({
    super.key,
    required this.recipeId,
    required this.recipeName,
    this.initialNote,
  });

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  late QuillController _controller;
  final _dbHelper = SupabaseService();
  bool _isSaving = false;
  bool _isToolbarExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    Document document;
    if (widget.initialNote != null && widget.initialNote!.isNotEmpty) {
      try {
        final List<dynamic> jsonData = jsonDecode(widget.initialNote!);
        document = Document.fromJson(jsonData);
      } catch (e) {
        document = Document()..insert(0, widget.initialNote!);
      }
    } else {
      document = Document();
    }
    _controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final noteJson = jsonEncode(_controller.document.toDelta().toJson());

    try {
      if (_controller.document.isEmpty()) {
        await _dbHelper.deleteRecipeNote(widget.recipeId);
        if (mounted) {
          showTopBanner(context, '笔记已删除');
          Navigator.pop(context, true);
        }
      } else {
        await _dbHelper.saveRecipeNote(widget.recipeId, noteJson);
        if (mounted) {
          showTopBanner(context, '笔记已保存');
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        showTopBanner(context, '保存失败: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('编辑“${widget.recipeName}”的笔记'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isSaving
                ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ))
                : IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: '保存',
              onPressed: _saveNote,
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: QuillEditor(
                scrollController: ScrollController(),
                controller: _controller,
                focusNode: FocusNode(),
                config: const QuillEditorConfig(
                  scrollable: true,
                  padding: EdgeInsets.only(top: 16, bottom: 24),
                  placeholder: '开始记录你的品酒心得、配方改良或任何想法...',

                ),
              ),
            ),
          ),
          // [修复] 使用经过修正的、稳定的可折叠工具栏
          _buildCollapsibleToolbar(Theme.of(context)),
        ],
      ),
    );
  }

  /// [核心修复] 构建一个稳定的、可折叠的、吸底的工具栏
  Widget _buildCollapsibleToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 第二行：扩展工具栏 (使用动画和Visibility)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: Visibility(
                visible: _isToolbarExpanded,
                // [修复] 使用配置好的 QuillToolbar.simple
                child: QuillSimpleToolbar(
                  controller: _controller,
                  config:const QuillSimpleToolbarConfig(
                    // --- 开启所有在第一行关闭的工具 ---

                    showColorButton: true,
                    showBackgroundColorButton: true,
                    showClearFormat: true,
                    showQuote: true,
                    showCodeBlock: true,
                    showIndent: true,
                    showLink: true,
                    showListCheck: true,
                    showSubscript: true,
                    showSuperscript: true,
                    showSearchButton: true,
                    showFontFamily: true,
                    showFontSize: true,
                    showHeaderStyle: true,


                    // --- 关闭所有在第一行已开启的工具，避免重复 ---
                    showBoldButton: false,
                    showListBullets: false,
                    showListNumbers: false,
                    showItalicButton: false,
                    showUnderLineButton: false, // [修正] 修正了拼写错误
                    showStrikeThrough: false,
                    showInlineCode: false,
                    // --- 强制单行显示 ---
                    multiRowsDisplay: false,
                  )
                ),
              ),
            ),
            // 第一行：常用工具栏
            Row(
              children: [
                Expanded(
                  // [修复] 使用配置好的 QuillToolbar.simple
                  child: QuillSimpleToolbar(
                    controller: _controller,
                    config: // 用于第一行（固定行）的配置
                    const QuillSimpleToolbarConfig(
                      // --- 第一行只显示这几个最高频工具 ---
                      showStrikeThrough: true,
                      showBoldButton: true,
                      showListBullets: true,
                      showListNumbers: true,
                      showItalicButton: true,
                      showUnderLineButton: true, // [修正] 修正了拼写错误
                      showFontSize: false,
                      showFontFamily: false,

                      // --- 关闭所有其他可能引起重复的按钮 ---
                      showHeaderStyle: false,
                      showSuperscript: false,
                      showSubscript: false,
                      showInlineCode: false,
                      showQuote: false,
                      showClearFormat: false,
                      showColorButton: false,
                      showBackgroundColorButton: false,
                      showListCheck: false,
                      showCodeBlock: false,
                      showIndent: false,
                      showLink: false,
                      showSearchButton: false,

                      // --- 强制单行显示 ---
                      multiRowsDisplay: false,
                    )
                  ),
                ),
                // "更多"按钮
                IconButton(
                  icon: Icon(
                    _isToolbarExpanded ? Icons.expand_less : Icons.more_horiz,
                    color: theme.primaryColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _isToolbarExpanded = !_isToolbarExpanded;
                    });
                  },
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  
}