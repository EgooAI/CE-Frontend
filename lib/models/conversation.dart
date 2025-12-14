import 'package:hive/hive.dart';

part 'conversation.g.dart';

@HiveType(typeId: 4)
class Conversation {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String? summary;
  @HiveField(3)
  final bool isActive;
  @HiveField(4)
  final bool isPinned;
  @HiveField(5)
  final int messageCount;
  @HiveField(6)
  final DateTime? lastMessageAt;
  @HiveField(7)
  final DateTime createdAt;
  @HiveField(8)
  final DateTime updatedAt;
  @HiveField(9)
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

@HiveType(typeId: 7)
class Message {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String role;
  @HiveField(2)
  final String content;
  @HiveField(3)
  final String? attachments;
  @HiveField(4)
  final String? metadata;
  @HiveField(5)
  final String conversationId;
  @HiveField(6)
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
