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
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: isUser
            ? SelectableText(
                message.content,
                style: const TextStyle(color: Colors.white),
              )
            : _buildMessageContent(message.content),
      ),
    );
  }

  Widget _buildMessageContent(String content) {
    // 检查是否包含思考过程
    if (content.contains('**思考过程:**')) {
      final parts = content.split('\n---\n');
      if (parts.length >= 2) {
        final thinkingPart = parts[0]
            .replaceAll('**思考过程:**', '')
            .replaceAll('```', '')
            .trim();
        final contentPart = parts.sublist(1).join('\n---\n').trim();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 思考过程区域 - 可折叠
            Theme(
              data: ThemeData(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(left: 8, top: 4),
                title: Row(
                  children: [
                    Icon(Icons.psychology, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      '思考过程',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                initiallyExpanded: false,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _buildThinkingProcess(thinkingPart),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 实际回复内容
            MarkdownBody(
              data: contentPart,
              styleSheet: _getMarkdownStyleSheet(),
              selectable: true,
            ),
          ],
        );
      }
    }

    // 没有思考过程，直接显示内容
    return MarkdownBody(
      data: content,
      styleSheet: _getMarkdownStyleSheet(),
      selectable: true,
    );
  }

  Widget _buildThinkingProcess(String thinkingText) {
    final lines = thinkingText
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmedLine = line.trim();

        // 进度消息
        if (trimmedLine.startsWith('💭')) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Text('💭', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    trimmedLine.substring(2).trim(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // 工具调用
        if (trimmedLine.startsWith('🔧')) {
          final toolInfo = trimmedLine.substring(2).trim();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.build, size: 14, color: Colors.blue[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      toolInfo,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 工具结果
        if (trimmedLine.startsWith('✅')) {
          final resultInfo = trimmedLine.substring(2).trim();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: Colors.green[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      resultInfo,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.green[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 参数或结果详情（缩进的行）
        if (trimmedLine.startsWith('参数:') || trimmedLine.startsWith('结果:')) {
          return Padding(
            padding: const EdgeInsets.only(left: 20, top: 2, bottom: 2),
            child: Text(
              trimmedLine,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
          );
        }

        // 其他文本
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            trimmedLine,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        );
      }).toList(),
    );
  }

  MarkdownStyleSheet _getMarkdownStyleSheet() {
    return MarkdownStyleSheet(
      p: const TextStyle(color: Colors.black, fontSize: 14),
      h1: const TextStyle(
        color: Colors.black,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      h2: const TextStyle(
        color: Colors.black,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      h3: const TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      h4: const TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      h5: const TextStyle(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      h6: const TextStyle(
        color: Colors.black,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      code: TextStyle(
        backgroundColor: Colors.grey[200],
        fontFamily: 'monospace',
        color: Colors.black87,
        fontSize: 13,
      ),
      codeblockDecoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      codeblockPadding: const EdgeInsets.all(8),
      blockquote: const TextStyle(
        color: Colors.black87,
        fontStyle: FontStyle.italic,
      ),
      listBullet: const TextStyle(color: Colors.black),
      tableBody: const TextStyle(color: Colors.black),
      a: const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),
    );
  }
}
