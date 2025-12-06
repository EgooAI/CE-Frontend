import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'sse_client.dart';
import '../models/conversation.dart';
import 'api_client.dart';
import 'auth_service.dart';

class ConversationService {
  ConversationService();

  Future<List<Conversation>> getConversations() async {
    try {
      final response = await ApiClient.instance.get('/conversations');
      final List<dynamic> body = response.data;
      return body.map((e) => Conversation.fromJson(e)).toList();
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load conversations');
    }
  }

  Future<Conversation> createConversation(String title) async {
    try {
      final response = await ApiClient.instance.post(
        '/conversations',
        data: {'title': title},
      );
      return Conversation.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to create conversation');
    }
  }

  Future<Conversation> getConversation(String id) async {
    try {
      final response = await ApiClient.instance.get('/conversations/$id');
      return Conversation.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load conversation');
    }
  }

  Future<Message> sendMessage(String conversationId, String content) async {
    try {
      final response = await ApiClient.instance.post(
        '/conversations/$conversationId/messages',
        data: {'role': 'user', 'content': content},
      );
      return Message.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to send message');
    }
  }

  Future<void> deleteConversation(String id) async {
    try {
      await ApiClient.instance.delete('/conversations/$id');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to delete conversation');
    }
  }

  Future<Conversation> updateConversationTitle(String id, String title) async {
    try {
      final response = await ApiClient.instance.put(
        '/conversations/$id/title',
        data: {'title': title},
      );
      return Conversation.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to update conversation title');
    }
  }

  // 流式发送消息
  Stream<StreamEvent> sendMessageStream(
    String conversationId,
    String content,
  ) async* {
    final authService = AuthService();
    final token = await authService.getToken();

    if (token == null) {
      yield StreamEvent(type: 'error', data: {'message': 'No auth token'});
      return;
    }

    const baseurl = String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://localhost:8080/api',
    );

    final url = '$baseurl/conversations/$conversationId/messages/stream';

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final body = json.encode({'role': 'user', 'content': content});

    // Use cross-platform SSE connector
    await for (final ev in connect(url, headers, body)) {
      final eventName = ev['event'] as String? ?? 'message';
      final data = ev['data'];

      try {
        if (eventName == 'user_message') {
          // data should be a map representing a Message
          yield StreamEvent(
            type: 'user_message',
            data: Message.fromJson(Map<String, dynamic>.from(data)),
          );
        } else if (eventName == 'progress') {
          yield StreamEvent(type: 'progress', data: data);
        } else if (eventName == 'content') {
          // streaming content chunk
          yield StreamEvent(type: 'content', data: data);
        } else if (eventName == 'tool_call') {
          yield StreamEvent(type: 'tool_call', data: data);
        } else if (eventName == 'tool_result') {
          yield StreamEvent(type: 'tool_result', data: data);
        } else if (eventName == 'schedule_parsed') {
          // AI 解析出的日程数据
          yield StreamEvent(type: 'schedule_parsed', data: data);
        } else if (eventName == 'done') {
          // data is the final Message object
          if (data is Map) {
            yield StreamEvent(
              type: 'done',
              data: Message.fromJson(Map<String, dynamic>.from(data)),
            );
          } else {
            yield StreamEvent(type: 'done', data: data);
          }
        } else if (eventName == 'error') {
          yield StreamEvent(type: 'error', data: data);
        } else {
          yield StreamEvent(type: 'message', data: data);
        }
      } catch (e) {
        yield StreamEvent(
          type: 'error',
          data: {'message': 'Parsing error: $e'},
        );
      }
    }
  }
}

class StreamEvent {
  final String type;
  final dynamic data;

  StreamEvent({required this.type, required this.data});
}
