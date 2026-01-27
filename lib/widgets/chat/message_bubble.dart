import 'dart:convert';
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
    final images = _parseAttachments();

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片附件
            if (images.isNotEmpty) ...[
              _buildImageGrid(images),
              if (content.isNotEmpty) const SizedBox(height: 8),
            ],
            // 文本内容
            if (content.isNotEmpty)
              MarkdownBody(
                data: content,
                styleSheet: _getMarkdownStyleSheet(isUser: isUser),
                selectable: true,
              ),
          ],
        ),
      ),
    );
  }

  /// 解析附件 JSON
  List<Map<String, dynamic>> _parseAttachments() {
    if (message.attachments == null || message.attachments!.isEmpty) {
      return [];
    }

    try {
      final data = jsonDecode(message.attachments!);
      if (data is Map<String, dynamic> && data.containsKey('images')) {
        final images = data['images'] as List?;
        if (images != null) {
          return images.cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      print('解析附件失败: $e');
    }
    return [];
  }

  /// 构建图片网格
  Widget _buildImageGrid(List<Map<String, dynamic>> images) {
    // 单张图片
    if (images.length == 1) {
      return _buildSingleImage(images[0]);
    }

    // 多张图片网格布局（2列）
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: images.map((img) => _buildGridImage(img)).toList(),
    );
  }

  /// 构建单张图片（较大显示）
  Widget _buildSingleImage(Map<String, dynamic> imageData) {
    final url = imageData['url'] as String?;
    final key = imageData['key'] as String?;
    final name = imageData['name'] as String? ?? '图片';

    if (url == null && key == null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('⚠️ 图片数据缺失', style: TextStyle(color: Colors.grey[600])),
      );
    }

    return GestureDetector(
      onTap: url != null ? () => _showImagePreview(url, name) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url ?? '', // 后端会自动添加 url 字段
          width: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 200,
              height: 150,
              color: Colors.grey[300],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image, size: 50),
                  const SizedBox(height: 8),
                  Text(
                    'URL已过期',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (key != null)
                    Text(
                      'Key: ${key.split('/').last}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                    ),
                ],
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 200,
              height: 150,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }

  /// 构建网格图片（固定尺寸）
  Widget _buildGridImage(Map<String, dynamic> imageData) {
    final url = imageData['url'] as String?;
    final key = imageData['key'] as String?;
    final name = imageData['name'] as String? ?? '图片';

    if (url == null && key == null) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.error_outline),
      );
    }

    return GestureDetector(
      onTap: url != null ? () => _showImagePreview(url, name) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url ?? '',
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 100,
              height: 100,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 100,
              height: 100,
              color: Colors.grey[200],
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 显示图片预览（全屏查看）
  void _showImagePreview(String url, String name) {
    // TODO: 实现全屏图片预览功能
    // 可以使用 photo_view 包或自定义 Dialog
    print('点击查看图片: $name - $url');
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
