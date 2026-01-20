import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models/chat/conversation.dart';

/// 聊天消息气泡组件
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isUser;

  const MessageBubble({super.key, required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = MediaQuery.of(context).size.width - 32;
    final content = _sanitizeContent(message.content);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        decoration: BoxDecoration(
          color: isUser ? null : Colors.white,
          gradient: isUser
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF4A8DFF), Color(0xFF1F4DD9)],
                )
              : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: MarkdownBody(
          data: content,
          styleSheet: _getMarkdownStyleSheet(isUser: isUser),
          selectable: true,
        ),
      ),
    );
  }

  String _sanitizeContent(String content) {
    if (!content.contains('**思考过程:**')) return content;
    final parts = content.split('\n---\n');
    if (parts.length < 2) return content;
    return parts.sublist(1).join('\n---\n').trim();
  }

  MarkdownStyleSheet _getMarkdownStyleSheet({required bool isUser}) {
    final textColor = isUser ? Colors.white : const Color(0xFF111111);
    final mutedColor = isUser ? Colors.white70 : const Color(0xFF5F6368);
    final codeBg = isUser ? Colors.white12 : const Color(0xFFF2F3F5);

    return MarkdownStyleSheet(
      p: TextStyle(color: textColor, fontSize: 16, height: 1.5),
      h1: TextStyle(
        color: textColor,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      h2: TextStyle(
        color: textColor,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      h3: TextStyle(
        color: textColor,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      h4: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      h5: TextStyle(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
      h6: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      code: TextStyle(
        backgroundColor: codeBg,
        fontFamily: 'monospace',
        color: textColor,
        fontSize: 13,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBg,
        borderRadius: BorderRadius.circular(6),
      ),
      codeblockPadding: const EdgeInsets.all(8),
      blockquote: TextStyle(color: mutedColor, fontStyle: FontStyle.italic),
      listBullet: TextStyle(color: textColor),
      tableBody: TextStyle(color: textColor),
      a: TextStyle(
        color: isUser ? Colors.white : const Color(0xFF111111),
        decoration: TextDecoration.underline,
      ),
    );
  }
}
