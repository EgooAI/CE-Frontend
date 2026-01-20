import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// 聊天输入栏组件
class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isListening;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback? onToggleListening;
  final VoidCallback? onStartListening;
  final VoidCallback? onStopListening;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isListening,
    required this.isSending,
    required this.onSend,
    this.onToggleListening,
    this.onStartListening,
    this.onStopListening,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late final FocusNode _focusNode;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_handleTextChange);
    _focusNode.addListener(_handleFocusChange);
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
    super.dispose();
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

    return Padding(
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
            if (!_hasText)
              IconButton(
                icon: const Icon(Icons.photo_camera_outlined, size: 20),
                onPressed: widget.isSending ? null : () {},
                tooltip: '拍照',
                color: Colors.black54,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            Expanded(
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
                    color: widget.isListening ? Colors.blue : Colors.black45,
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
            if (_hasText)
              SizedBox(
                width: 36,
                height: 36,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.black,
                    shape: const CircleBorder(),
                    elevation: 0,
                  ),
                  onPressed: widget.isSending ? null : widget.onSend,
                  child: const Icon(
                    Icons.arrow_upward,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              )
            else ...[
              if (!kIsWeb && widget.onToggleListening != null)
                GestureDetector(
                  onTap: widget.isSending ? null : widget.onToggleListening,
                  onLongPressStart: widget.isSending
                      ? null
                      : (_) => widget.onStartListening?.call(),
                  onLongPressEnd: widget.isSending
                      ? null
                      : (_) => widget.onStopListening?.call(),
                  child: Icon(
                    widget.isListening ? Icons.mic : Icons.mic_none,
                    color: widget.isListening ? Colors.red : Colors.black54,
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
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
