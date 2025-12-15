import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/conversation.dart';
import '../models/sync_task.dart';
import '../services/cache/cache_service.dart';
import '../services/cache/cache_keys.dart';
import '../services/conversation_service.dart';
import '../services/sync_queue_service.dart';
import '../utils/service_locator.dart';

/// Conversation 数据仓库
///
/// 职责：
/// - 封装会话的缓存和网络请求逻辑
/// - 实现缓存优先策略
/// - 管理会话消息
/// - 提供离线访问能力
///
/// 使用示例：
/// ```dart
/// final repo = ConversationRepository();
/// final conversations = await repo.getConversations();
/// ```
class ConversationRepository {
  final CacheService _cache = locator<CacheService>();
  final ConversationService _service = ConversationService();
  final SyncQueueService _syncQueue = locator<SyncQueueService>();
  final _uuid = const Uuid();

  /// 获取会话列表
  ///
  /// 缓存策略：
  /// 1. 先检查缓存是否存在且未过期
  /// 2. 如果缓存有效，直接返回
  /// 3. 如果缓存无效，请求 API 并更新缓存
  /// 4. 如果 API 请求失败，尝试返回过期缓存（降级方案）
  Future<List<Conversation>> getConversations() async {
    final cacheKey = CacheKeys.conversations;

    try {
      // 1. 尝试读取缓存
      final cachedConversations = await _cache.getList<Conversation>(cacheKey);
      final isCacheValid =
          cachedConversations.isNotEmpty && !(await _cache.isExpired(cacheKey));

      if (isCacheValid) {
        print(
          '[ConversationRepository] 命中缓存: $cacheKey, 数量: ${cachedConversations.length}',
        );
        return cachedConversations;
      }

      // 2. 缓存无效，请求 API
      print('[ConversationRepository] 缓存未命中，请求 API: $cacheKey');
      final conversations = await _service.getConversations();

      // 3. 更新缓存
      await _cache.setList(cacheKey, conversations);
      print(
        '[ConversationRepository] 缓存已更新: $cacheKey, 数量: ${conversations.length}',
      );

      return conversations;
    } catch (e) {
      print('[ConversationRepository] API 请求失败: $e');

      // 4. 降级方案：返回过期缓存（如果存在）
      final fallbackConversations = await _cache.getList<Conversation>(
        cacheKey,
      );
      if (fallbackConversations.isNotEmpty) {
        print(
          '[ConversationRepository] ⚠️ 使用过期缓存作为降级方案, 数量: ${fallbackConversations.length}',
        );
        return fallbackConversations;
      }

      // 5. 无缓存且 API 失败，抛出异常
      rethrow;
    }
  }

  /// 获取单个会话详情（不使用缓存，确保实时性）
  Future<Conversation> getConversationById(String id) async {
    return await _service.getConversation(id);
  }

  /// 获取会话详情（包含消息信息）
  ///
  /// 会话详情缓存独立管理
  Future<Conversation> getConversationDetail(String conversationId) async {
    final conversationDetailKey = CacheKeys.getConversationDetailKey(
      conversationId,
    );

    try {
      // 检查缓存
      final cachedConversation = await _cache.get<Conversation>(
        conversationDetailKey,
      );
      final isCacheValid =
          cachedConversation != null &&
          !(await _cache.isExpired(conversationDetailKey));

      if (isCacheValid) {
        print('[ConversationRepository] 命中会话详情缓存: $conversationDetailKey');
        return cachedConversation;
      }

      // 请求 API
      print('[ConversationRepository] 缓存未命中，请求会话详情: $conversationDetailKey');
      final conversation = await _service.getConversation(conversationId);

      // 更新缓存
      await _cache.set(conversationDetailKey, conversation);
      print('[ConversationRepository] 会话详情缓存已更新: $conversationDetailKey');

      return conversation;
    } catch (e) {
      print('[ConversationRepository] 获取会话详情失败: $e');
      rethrow;
    }
  }

  /// 创建新会话
  ///
  /// 副作用：
  /// - 清除会话列表缓存（触发下次重新加载）
  Future<Conversation> createConversation(String title) async {
    try {
      final newConversation = await _service.createConversation(title);

      // 清除会话列表缓存
      await _invalidateConversationListCache();

      print('[ConversationRepository] 会话创建成功，已清除缓存');
      return newConversation;
    } catch (e) {
      print('[ConversationRepository] 创建会话失败: $e');
      rethrow;
    }
  }

  /// 发送消息
  ///
  /// 副作用：
  /// - 清除会话列表缓存（lastMessageAt 会更新）
  /// - 清除会话详情缓存
  Future<Message> sendMessage(String conversationId, String content) async {
    try {
      final message = await _service.sendMessage(conversationId, content);

      // 清除相关缓存
      final conversationDetailKey = CacheKeys.getConversationDetailKey(
        conversationId,
      );
      await _cache.delete(conversationDetailKey);
      await _invalidateConversationListCache();

      print('[ConversationRepository] 消息发送成功，已清除缓存');
      return message;
    } catch (e) {
      print('[ConversationRepository] 发送消息失败: $e');
      rethrow;
    }
  }

  /// 删除会话
  ///
  /// 副作用：
  /// - 清除会话列表缓存
  /// - 清除该会话的消息缓存
  /// - 网络失败时自动加入离线队列
  Future<void> deleteConversation(String id) async {
    try {
      await _service.deleteConversation(id);

      // 清除相关缓存
      final messagesCacheKey = CacheKeys.getConversationMessagesKey(id);
      await _cache.delete(messagesCacheKey);
      await _invalidateConversationListCache();

      print('[ConversationRepository] 会话删除成功，已清除缓存');
    } on DioException catch (e) {
      // 网络错误：加入离线队列
      if (_isNetworkError(e)) {
        print('[ConversationRepository] ⚠️ 网络错误，加入离线队列');

        final syncTask = SyncTask.create(
          id: _uuid.v4(),
          resourceType: ResourceType.conversation,
          operation: SyncOperation.delete,
          resourceId: id,
          payload: {},
          priority: 5,
        );

        await _syncQueue.addTask(syncTask);

        // 乐观更新：立即清除缓存
        final messagesCacheKey = CacheKeys.getConversationMessagesKey(id);
        await _cache.delete(messagesCacheKey);
        await _invalidateConversationListCache();

        print('[ConversationRepository] 已加入离线队列，任务ID: ${syncTask.id}');
        return;
      }
      rethrow;
    } catch (e) {
      print('[ConversationRepository] 删除会话失败: $e');
      rethrow;
    }
  }

  /// 更新会话标题
  ///
  /// 副作用：
  /// - 清除会话详情缓存
  /// - 清除会话列表缓存
  /// - 网络失败时自动加入离线队列
  Future<Conversation> updateConversationTitle(
    String id,
    String newTitle,
  ) async {
    try {
      final updated = await _service.updateConversationTitle(id, newTitle);

      // 清除相关缓存
      final conversationDetailKey = CacheKeys.getConversationDetailKey(id);
      await _cache.delete(conversationDetailKey);
      await _invalidateConversationListCache();

      print('[ConversationRepository] 会话标题更新成功，已清除缓存');
      return updated;
    } on DioException catch (e) {
      // 网络错误：加入离线队列
      if (_isNetworkError(e)) {
        print('[ConversationRepository] ⚠️ 网络错误，加入离线队列');

        final syncTask = SyncTask.create(
          id: _uuid.v4(),
          resourceType: ResourceType.conversation,
          operation: SyncOperation.update,
          resourceId: id,
          payload: {'title': newTitle},
          priority: 6,
        );

        await _syncQueue.addTask(syncTask);

        // 乐观更新：清除缓存
        final conversationDetailKey = CacheKeys.getConversationDetailKey(id);
        await _cache.delete(conversationDetailKey);
        await _invalidateConversationListCache();

        print('[ConversationRepository] 已加入离线队列，任务ID: ${syncTask.id}');

        // 返回一个临时对象（实际标题将在同步后更新）
        throw Exception('离线模式，已加入同步队列');
      }
      rethrow;
    } catch (e) {
      print('[ConversationRepository] 更新会话标题失败: $e');
      rethrow;
    }
  }

  /// 手动刷新缓存
  Future<List<Conversation>> refreshConversations() async {
    // 先清除缓存
    await _invalidateConversationListCache();

    // 重新加载
    return await getConversations();
  }

  /// 清除所有会话缓存
  Future<void> clearAllCache() async {
    // 清除列表缓存
    await _invalidateConversationListCache();

    print('[ConversationRepository] 所有缓存已清除');
  }

  /// 清除会话列表缓存
  Future<void> _invalidateConversationListCache() async {
    await _cache.delete(CacheKeys.conversations);
    print('[ConversationRepository] 会话列表缓存已清除');
  }

  /// 清除特定会话的缓存
  Future<void> invalidateConversationCache(String conversationId) async {
    final conversationDetailKey = CacheKeys.getConversationDetailKey(
      conversationId,
    );
    await _cache.delete(conversationDetailKey);
    print('[ConversationRepository] 会话详情缓存已清除: $conversationId');
  }

  /// 判断是否为网络错误
  bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown;
  }

  /// 清空所有缓存
  Future<void> clearCache() async {
    await _cache.clear();
  }
}
