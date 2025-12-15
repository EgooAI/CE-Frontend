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

      // 检查响应数据
      if (response.data == null) {
        return []; // 返回空列表而不是抛出异常
      }

      // 确保是列表类型
      if (response.data is! List) {
        print('getConversations 响应数据类型错误: ${response.data.runtimeType}');
        print('响应数据: ${response.data}');
        return [];
      }

      final List<dynamic> body = response.data;
      return body.map((e) => Conversation.fromJson(e)).toList();
    } on DioException catch (e) {
      print('获取对话列表失败: ${e.message}');
      throw Exception(e.message ?? 'Failed to load conversations');
    }
  }

  Future<Conversation> createConversation(String title) async {
    try {
      final response = await ApiClient.instance.post(
        '/conversations',
        data: {'title': title},
      );

      if (response.data == null) {
        throw Exception('服务器返回空数据');
      }

      if (response.data is! Map<String, dynamic>) {
        print('createConversation 响应数据类型错误: ${response.data.runtimeType}');
        throw Exception('服务器返回数据格式错误');
      }

      return Conversation.fromJson(response.data);
    } on DioException catch (e) {
      print('创建对话失败: ${e.message}');
      throw Exception(e.message ?? 'Failed to create conversation');
    }
  }

  Future<Conversation> getConversation(String id) async {
    try {
      print('正在获取对话详情: $id');
      final response = await ApiClient.instance.get('/conversations/$id');
      print('对话详情响应: ${response.data}');

      // 检查响应数据是否为空
      if (response.data == null) {
        throw Exception('服务器返回空数据');
      }

      // 检查是否是 Map 类型
      if (response.data is! Map<String, dynamic>) {
        print('响应数据类型错误: ${response.data.runtimeType}');
        throw Exception('服务器返回数据格式错误');
      }

      final conversation = Conversation.fromJson(response.data);
      print('解析成功，消息数量: ${conversation.messages?.length ?? 0}');
      return conversation;
    } on DioException catch (e) {
      print('获取对话详情失败 (DioException): ${e.message}');
      print('响应状态: ${e.response?.statusCode}');
      print('响应数据: ${e.response?.data}');
      throw Exception(e.message ?? 'Failed to load conversation');
    } catch (e) {
      print('获取对话详情失败 (Other): $e');
      rethrow;
    }
  }

  Future<Message> sendMessage(String conversationId, String content) async {
    try {
      final response = await ApiClient.instance.post(
        '/conversations/$conversationId/messages',
        data: {'role': 'user', 'content': content},
      );

      if (response.data == null) {
        throw Exception('服务器返回空数据');
      }

      if (response.data is! Map<String, dynamic>) {
        print('sendMessage 响应数据类型错误: ${response.data.runtimeType}');
        throw Exception('服务器返回数据格式错误');
      }

      return Message.fromJson(response.data);
    } on DioException catch (e) {
      print('发送消息失败: ${e.message}');
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

  /// 根据内容生成对话标题
  ///
  /// 调用 AI 服务自动生成简短、准确的会话标题
  ///
  /// 参数：
  ///   - content: 用于生成标题的文本内容（建议 10-500 字符）
  ///
  /// 返回：生成的标题文本
  ///
  /// 异常：如果请求失败会抛出 Exception
  Future<String> generateTitle(String content) async {
    try {
      if (content.trim().isEmpty) {
        throw Exception('内容不能为空');
      }

      final response = await ApiClient.instance.post(
        '/conversations/generate-title',
        data: {'content': content},
      );

      if (response.data == null || response.data is! Map) {
        throw Exception('服务器返回数据格式错误');
      }

      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      print('[GenerateTitle] 📥 API 响应 (拦截器已提取 data): $data');

      // 拦截器已经提取了原始响应中的 data 字段，直接获取 title
      final title = data['title'] as String?;
      print('[GenerateTitle] 📝 提取的标题: $title');

      if (title == null || title.isEmpty) {
        throw Exception('生成标题为空');
      }

      print('[GenerateTitle] ✅ 标题提取成功: $title');
      return title;
    } on DioException catch (e) {
      print('[GenerateTitle] 📡 DioException: ${e.message}');
      print('[GenerateTitle] 📡 状态码: ${e.response?.statusCode}');
      print('[GenerateTitle] 📡 响应体: ${e.response?.data}');
      throw Exception(e.message ?? 'Failed to generate title');
    } catch (e) {
      print('[GenerateTitle] ❌ 异常: $e');
      rethrow;
    }
  }

  /// 搜索会话
  ///
  /// [keyword] 搜索关键词
  /// 返回匹配的会话列表
  Future<List<Conversation>> searchConversations(String keyword) async {
    try {
      print('[SearchConversations] 🔍 开始搜索: $keyword');

      final response = await ApiClient.instance.get(
        '/conversations/search',
        queryParameters: {'q': keyword},
      );

      if (response.data == null) {
        print('[SearchConversations] ⚠️ 响应数据为空');
        return [];
      }

      if (response.data is! List) {
        print(
          '[SearchConversations] ⚠️ 响应数据类型错误: ${response.data.runtimeType}',
        );
        return [];
      }

      final List<dynamic> results = response.data;
      print('[SearchConversations] ✅ 搜索成功，找到 ${results.length} 个结果');

      return results.map((e) => Conversation.fromJson(e)).toList();
    } on DioException catch (e) {
      print('[SearchConversations] ❌ 搜索失败: ${e.message}');
      throw Exception(e.message ?? '搜索会话失败');
    } catch (e) {
      print('[SearchConversations] ❌ 异常: $e');
      rethrow;
    }
  }
}

class StreamEvent {
  final String type;
  final dynamic data;

  StreamEvent({required this.type, required this.data});
}
