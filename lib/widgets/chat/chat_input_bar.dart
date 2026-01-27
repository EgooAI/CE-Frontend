import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_clipboard/super_clipboard.dart';
import './image_preview_widget.dart';

/// 聊天输入栏组件
class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isListening;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback? onToggleListening;
  final VoidCallback? onStartListening;
  final VoidCallback? onStopListening;
  final VoidCallback? onPickImage; // 选择图片回调
  final VoidCallback? onTakePhoto; // 拍照回调
  final Future<void> Function(Uint8List bytes, {String? filename})?
  onPasteImage; // 粘贴图片回调
  final List<ImageAttachment> images; // 已选择的图片
  final Function(int index)? onRemoveImage; // 删除图片回调

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isListening,
    required this.isSending,
    required this.onSend,
    this.onToggleListening,
    this.onStartListening,
    this.onStopListening,
    this.onPickImage,
    this.onTakePhoto,
    this.onPasteImage,
    this.images = const [],
    this.onRemoveImage,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late final FocusNode _focusNode;
  late final FocusNode _keyboardFocusNode;
  bool _hasText = false;
  bool _isPasteHandling = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _keyboardFocusNode = FocusNode();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_handleTextChange);
    _focusNode.addListener(_handleFocusChange);
    _registerWebPasteListener();
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChange);
      widget.controller.addListener(_handleTextChange);
      _hasText = widget.controller.text.trim().isNotEmpty;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _registerWebPasteListener() {
    if (!kIsWeb) return;
    final events = ClipboardEvents.instance;
    if (events == null) return;

    events.registerPasteEventListener((event) async {
      if (widget.onPasteImage == null || _isPasteHandling) return;
      _isPasteHandling = true;
      try {
        final reader = await event.getClipboardReader();
        if (reader.canProvide(Formats.png)) {
          reader.getFile(Formats.png, (file) async {
            final data = await file.readAll();
            await widget.onPasteImage!(
              data,
              filename: 'paste_${DateTime.now().millisecondsSinceEpoch}.png',
            );
          });
          return;
        }

        if (reader.canProvide(Formats.plainText)) {
          final text = await reader.readValue(Formats.plainText);
          if (text != null) {
            _insertTextAtCursor(text);
          }
        }
      } finally {
        _isPasteHandling = false;
      }
    });
  }

  Future<void> _tryPasteImageFromClipboard() async {
    if (widget.onPasteImage == null || _isPasteHandling) return;
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return;

    _isPasteHandling = true;
    try {
      final reader = await clipboard.read();
      if (reader.canProvide(Formats.png)) {
        reader.getFile(Formats.png, (file) async {
          final data = await file.readAll();
          await widget.onPasteImage!(
            data,
            filename: 'paste_${DateTime.now().millisecondsSinceEpoch}.png',
          );
        });
      }
    } finally {
      _isPasteHandling = false;
    }
  }

  void _insertTextAtCursor(String text) {
    final selection = widget.controller.selection;
    final currentText = widget.controller.text;
    final start = selection.start >= 0 ? selection.start : currentText.length;
    final end = selection.end >= 0 ? selection.end : currentText.length;
    final newText = currentText.replaceRange(start, end, text);
    widget.controller.text = newText;
    widget.controller.selection = TextSelection.collapsed(
      offset: start + text.length,
    );
  }

  bool _isPasteShortcut(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return false;
    final isCtrlOrMeta = event.isControlPressed || event.isMetaPressed;
    return isCtrlOrMeta && event.logicalKey == LogicalKeyboardKey.keyV;
  }

  void _handleTextChange() {
    final nextHasText = widget.controller.text.trim().isNotEmpty;
    if (nextHasText != _hasText) {
      setState(() {
        _hasText = nextHasText;
      });
    }
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final hintText = widget.isListening
        ? '监听中...'
        : (_focusNode.hasFocus ? '发消息...' : '发消息...');
    final hasImages = widget.images.isNotEmpty;
    final hasBlockingImages = widget.images.any(
      (img) => img.isUploading || img.error != null,
    );
    final canSend = hasImages ? !hasBlockingImages : _hasText;
    final hasContent = _hasText || hasImages;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 图片预览区域
        if (widget.images.isNotEmpty)
          ImagePreviewWidget(
            images: widget.images,
            onAddImage: () {
              if (widget.onPickImage != null) {
                widget.onPickImage!();
              }
            },
            onRemoveImage: (index) {
              if (widget.onRemoveImage != null) {
                widget.onRemoveImage!(index);
              }
            },
          ),

        // 输入栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 相机按钮（使用 Visibility 而不是条件渲染，避免 TextField 重建）
                Visibility(
                  visible: !hasContent,
                  maintainSize: false,
                  maintainAnimation: false,
                  maintainState: false,
                  child: IconButton(
                    icon: const Icon(Icons.photo_camera_outlined, size: 20),
                    onPressed: widget.isSending
                        ? null
                        : () {
                            // 显示选择菜单
                            _showImageSourceMenu(context);
                          },
                    tooltip: '图片',
                    color: Colors.black54,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ),
                // 输入框（添加 key 防止重建）
                Expanded(
                  key: const ValueKey('chat_text_field'),
                  child: RawKeyboardListener(
                    focusNode: _keyboardFocusNode,
                    onKey: (event) {
                      if (_isPasteShortcut(event)) {
                        _tryPasteImageFromClipboard();
                      }
                    },
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textAlign: TextAlign.left,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: TextStyle(
                          fontSize: 15,
                          color: widget.isListening
                              ? Colors.blue
                              : Colors.black45,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      onSubmitted: (_) => widget.onSend(),
                      enabled: !widget.isSending,
                    ),
                  ),
                ),
                // 发送按钮（使用 Visibility）
                Visibility(
                  visible: hasContent,
                  maintainSize: false,
                  maintainAnimation: false,
                  maintainState: false,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.black,
                        shape: const CircleBorder(),
                        elevation: 0,
                      ),
                      onPressed: (widget.isSending || !canSend)
                          ? null
                          : widget.onSend,
                      child: const Icon(
                        Icons.arrow_upward,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // 麦克风和更多按钮（使用 Visibility）
                Visibility(
                  visible: !hasContent,
                  maintainSize: false,
                  maintainAnimation: false,
                  maintainState: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!kIsWeb && widget.onToggleListening != null)
                        GestureDetector(
                          onTap: widget.isSending
                              ? null
                              : widget.onToggleListening,
                          onLongPressStart: widget.isSending
                              ? null
                              : (_) => widget.onStartListening?.call(),
                          onLongPressEnd: widget.isSending
                              ? null
                              : (_) => widget.onStopListening?.call(),
                          child: Icon(
                            widget.isListening ? Icons.mic : Icons.mic_none,
                            color: widget.isListening
                                ? Colors.red
                                : Colors.black54,
                            size: 20,
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: widget.isSending ? null : () {},
                        tooltip: '更多',
                        color: Colors.black54,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 显示图片来源选择菜单
  void _showImageSourceMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册选择'),
                onTap: () {
                  Navigator.pop(context);
                  if (widget.onPickImage != null) {
                    widget.onPickImage!();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('拍照'),
                onTap: () {
                  Navigator.pop(context);
                  if (widget.onTakePhoto != null) {
                    widget.onTakePhoto!();
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
