import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import '../models/conversation.dart';
import 'api_client.dart';
import 'auth_service.dart';

class ConversationService {
  ConversationService();

  Future<List<Conversation>> getConversations() async {
    try {
      final response = await ApiClient.instance.get('/conversations');

      if (response.statusCode == 200) {
        final List<dynamic> body = response.data;
        return body.map((e) => Conversation.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load conversations: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception(
        'Failed to load conversations: ${e.response?.data ?? e.message}',
      );
    }
  }

  Future<Conversation> createConversation(String title) async {
    try {
      final response = await ApiClient.instance.post(
        '/conversations',
        data: {'title': title},
      );

      if (response.statusCode == 201) {
        return Conversation.fromJson(response.data);
      } else {
        throw Exception('Failed to create conversation: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception(
        'Failed to create conversation: ${e.response?.data ?? e.message}',
      );
    }
  }

  Future<Conversation> getConversation(String id) async {
    try {
      final response = await ApiClient.instance.get('/conversations/$id');

      if (response.statusCode == 200) {
        return Conversation.fromJson(response.data);
      } else {
        throw Exception('Failed to load conversation: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception(
        'Failed to load conversation: ${e.response?.data ?? e.message}',
      );
    }
  }

  Future<Message> sendMessage(String conversationId, String content) async {
    try {
      final response = await ApiClient.instance.post(
        '/conversations/$conversationId/messages',
        data: {'role': 'user', 'content': content},
      );

      if (response.statusCode == 201) {
        return Message.fromJson(response.data);
      } else {
        throw Exception('Failed to send message: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception(
        'Failed to send message: ${e.response?.data ?? e.message}',
      );
    }
  }

  Future<void> deleteConversation(String id) async {
    try {
      final response = await ApiClient.instance.delete('/conversations/$id');

      if (response.statusCode != 200) {
        throw Exception('Failed to delete conversation: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception(
        'Failed to delete conversation: ${e.response?.data ?? e.message}',
      );
    }
  }

  // 流式发送消息
  Stream<StreamEvent> sendMessageStream(
    String conversationId,
    String content,
  ) async* {
    try {
      final authService = AuthService();
      final token = await authService.getToken();

      if (token == null) {
        throw Exception('No auth token found');
      }

      final request = http.Request(
        'POST',
        Uri.parse(
          'http://localhost:8080/api/conversations/$conversationId/messages/stream',
        ),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode({'role': 'user', 'content': content});

      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to send message: ${response.statusCode}');
      }

      String? currentEvent;
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        // 解析 SSE 数据
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('event:')) {
            currentEvent = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            final data = line.substring(5).trim();
            if (data.isEmpty || currentEvent == null) continue;

            try {
              final jsonData = json.decode(data);

              // 根据事件类型解析数据
              if (currentEvent == 'user_message') {
                yield StreamEvent(
                  type: 'user_message',
                  data: Message.fromJson(jsonData),
                );
              } else if (currentEvent == 'progress') {
                yield StreamEvent(type: 'progress', data: jsonData);
              } else if (currentEvent == 'tool_call') {
                yield StreamEvent(type: 'tool_call', data: jsonData);
              } else if (currentEvent == 'tool_result') {
                yield StreamEvent(type: 'tool_result', data: jsonData);
              } else if (currentEvent == 'done') {
                yield StreamEvent(
                  type: 'done',
                  data: Message.fromJson(jsonData),
                );
              } else if (currentEvent == 'error') {
                yield StreamEvent(type: 'error', data: jsonData);
              }

              currentEvent = null; // 重置事件类型
            } catch (e) {
              // 跳过无法解析的数据
              print('Error parsing SSE data: $e, data: $data');
              continue;
            }
          }
        }
      }

      client.close();
    } catch (e) {
      yield StreamEvent(type: 'error', data: {'message': 'Stream error: $e'});
    }
  }
}

class StreamEvent {
  final String type;
  final dynamic data;

  StreamEvent({required this.type, required this.data});
}
