import 'package:dio/dio.dart';
import '../models/conversation.dart';
import 'api_client.dart';

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
      throw Exception('Failed to load conversations: ${e.response?.data ?? e.message}');
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
      throw Exception('Failed to create conversation: ${e.response?.data ?? e.message}');
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
      throw Exception('Failed to load conversation: ${e.response?.data ?? e.message}');
    }
  }

  Future<Message> sendMessage(String conversationId, String content) async {
    try {
      final response = await ApiClient.instance.post(
        '/conversations/$conversationId/messages',
        data: {
          'role': 'user',
          'content': content,
        },
      );

      if (response.statusCode == 201) {
        return Message.fromJson(response.data);
      } else {
        throw Exception('Failed to send message: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception('Failed to send message: ${e.response?.data ?? e.message}');
    }
  }
  
  Future<void> deleteConversation(String id) async {
    try {
      final response = await ApiClient.instance.delete('/conversations/$id');

      if (response.statusCode != 200) {
        throw Exception('Failed to delete conversation: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception('Failed to delete conversation: ${e.response?.data ?? e.message}');
    }
  }
}
