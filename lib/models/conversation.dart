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
    return Conversation(
      id: json['id'],
      title: json['title'],
      summary: json['summary'],
      isActive: json['isActive'] ?? true,
      isPinned: json['isPinned'] ?? false,
      messageCount: json['messageCount'] ?? 0,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      messages: json['messages'] != null
          ? (json['messages'] as List).map((e) => Message.fromJson(e)).toList()
          : null,
    );
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
    return Message(
      id: json['id'],
      role: json['role'],
      content: json['content'],
      attachments: json['attachments'],
      metadata: json['metadata'],
      conversationId: json['conversationId'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
