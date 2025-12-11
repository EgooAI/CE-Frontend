class Conversation {
  final String id;
  final String title;
  final String? summary;
  final bool isActive;
  final bool isPinned;
  final int messageCount;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Message>? messages;

  Conversation({
    required this.id,
    required this.title,
    this.summary,
    required this.isActive,
    required this.isPinned,
    required this.messageCount,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
    this.messages,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    try {
      return Conversation(
        id: json['id'] ?? '',
        title: json['title'] ?? '未命名对话',
        summary: json['summary'],
        isActive: json['isActive'] ?? true,
        isPinned: json['isPinned'] ?? false,
        messageCount: json['messageCount'] ?? 0,
        lastMessageAt: json['lastMessageAt'] != null
            ? DateTime.parse(json['lastMessageAt'])
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : DateTime.now(),
        messages: json['messages'] != null
            ? (json['messages'] as List)
                  .map((e) => Message.fromJson(e as Map<String, dynamic>))
                  .toList()
            : null,
      );
    } catch (e) {
      print('解析 Conversation 失败: $e');
      print('原始数据: $json');
      rethrow;
    }
  }
}

class Message {
  final String id;
  final String role;
  final String content;
  final String? attachments;
  final String? metadata;
  final String conversationId;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.role,
    required this.content,
    this.attachments,
    this.metadata,
    required this.conversationId,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    try {
      return Message(
        id: json['id'] ?? '',
        role: json['role'] ?? 'user',
        content: json['content'] ?? '',
        attachments: json['attachments'],
        metadata: json['metadata'],
        conversationId: json['conversationId'] ?? json['conversation_id'] ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
      );
    } catch (e) {
      print('解析 Message 失败: $e');
      print('原始数据: $json');
      rethrow;
    }
  }
}
