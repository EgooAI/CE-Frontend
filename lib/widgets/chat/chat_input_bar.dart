import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// 聊天输入栏组件
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback? onToggleListening;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isListening,
    required this.isSending,
    required this.onSend,
    this.onToggleListening,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: isListening ? '监听中...' : '输入消息...',
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: isListening ? Colors.blue : Colors.black38,
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                  borderSide: BorderSide(width: 1, color: Colors.black26),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                  borderSide: BorderSide(width: 1, color: Colors.black),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                // 添加麦克风按钮（Web 平台暂不支持）
                suffixIcon: kIsWeb || onToggleListening == null
                    ? null
                    : IconButton(
                        icon: Icon(
                          isListening ? Icons.mic : Icons.mic_none,
                          color: isListening ? Colors.red : Colors.grey,
                        ),
                        onPressed: isSending ? null : onToggleListening,
                        tooltip: '语音输入',
                      ),
              ),
              onSubmitted: (_) => onSend(),
              enabled: !isSending,
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: isSending ? null : onSend,
          ),
        ],
      ),
    );
  }
}
