import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/daily/daily_task.dart';
import '../models/sync/sync_task.dart';
import '../services/cache/cache_service.dart';
import '../services/cache/cache_keys.dart';
import '../services/cache/conditional_request_service.dart';
import '../services/daily/daily_task_service.dart';
import '../services/sync/sync_queue_service.dart';
import '../utils/service_locator.dart';

/// DailyTask 数据仓库
///
/// 职责：
/// - 封装日常任务的缓存和网络请求逻辑
/// - 实现缓存优先策略
/// - 提供离线访问能力
///
/// 使用示例：
/// ```dart
/// final repo = DailyTaskRepository();
/// final tasks = await repo.getDailyTasks(status: 'active');
/// ```
class DailyTaskRepository {
  final CacheService _cache = locator<CacheService>();
  final DailyTaskService _service = DailyTaskService();
  final SyncQueueService _syncQueue = locator<SyncQueueService>();
  final _uuid = const Uuid();

  /// 获取日常任务列表
  ///
  /// 缓存策略：
  /// 1. 先检查缓存是否存在且未过期
  /// 2. 如果缓存有效，直接返回
  /// 3. 如果缓存无效，请求 API 并更新缓存
  /// 4. 如果 API 请求失败，尝试返回过期缓存（降级方案）
  Future<List<DailyTask>> getDailyTasks({
    String status = 'active',
    bool forceRefresh = false,
  }) async {
    final cacheKey = _buildCacheKey(status);

    try {
      // 1. 检查缓存是否存在 & 是否过期
      final cacheTimestamp = await _cache.getTimestamp(cacheKey);
      final isCacheExpired = await _cache.isExpired(cacheKey);

      if (forceRefresh) {
        print('[DailyTaskRepository] 🔄 强制刷新，不发送 If-Modified-Since');
        final response = await _service.getDailyTasksWithResponse(
          status: status,
          skipConditionalRequest: true,
        );
        final data = response.data is List ? response.data : [];
        final tasks = (data as List)
            .map((json) => DailyTask.fromJson(json as Map<String, dynamic>))
            .toList();
        await _cache.setList(cacheKey, tasks);
        return tasks;
      }

      // TTL 未过期，直接返回缓存（可能是空列表）
      if (!forceRefresh && cacheTimestamp != null && !isCacheExpired) {
        final cachedTasks = await _cache.getList<DailyTask>(cacheKey);
        print(
          '[DailyTaskRepository] ✅ TTL 命中: $cacheKey, 数量: ${cachedTasks.length}',
        );
        return cachedTasks;
      }

      // 2. TTL 过期，但缓存存在，使用条件请求判断
      if (cacheTimestamp != null) {
        final cachedTasks = await _cache.getList<DailyTask>(cacheKey);
        print('[DailyTaskRepository] ⏰ TTL 过期，发送条件请求: $cacheKey');
        final response = await _service.getDailyTasksWithResponse(
          status: status,
        );

        if (ConditionalRequestService.isNotModified(response)) {
          print('[DailyTaskRepository] ✅ 304 Not Modified，刷新 TTL');
          await _cache.refreshTTL(cacheKey);
          return cachedTasks;
        }

        print('[DailyTaskRepository] 📥 数据已更新');
        final data = response.data is List ? response.data : [];
        final tasks = (data as List)
            .map((json) => DailyTask.fromJson(json as Map<String, dynamic>))
            .toList();
        await _cache.setList(cacheKey, tasks);
        return tasks;
      }

      // 3. 无缓存，请求 API
      print('[DailyTaskRepository] 🌐 无缓存，请求 API: $cacheKey');
      final response = await _service.getDailyTasksWithResponse(status: status);
      final data = response.data is List ? response.data : [];
      final tasks = (data as List)
          .map((json) => DailyTask.fromJson(json as Map<String, dynamic>))
          .toList();

      await _cache.setList(cacheKey, tasks);
      print('[DailyTaskRepository] 缓存已创建: $cacheKey, 数量: ${tasks.length}');

      return tasks;
    } catch (e) {
      print('[DailyTaskRepository] API 请求失败: $e');

      // 4. 降级方案：返回过期缓存（如果存在）
      final cacheTimestamp = await _cache.getTimestamp(cacheKey);
      if (cacheTimestamp != null) {
        final fallbackTasks = await _cache.getList<DailyTask>(cacheKey);
        print(
          '[DailyTaskRepository] ⚠️ 使用过期缓存作为降级方案, 数量: ${fallbackTasks.length}',
        );
        return fallbackTasks;
      }

      // 5. 无缓存且 API 失败，抛出异常
      rethrow;
    }
  }

  /// 获取缓存中的日常任务（即使已过期）
  ///
  /// 返回 null 表示没有缓存记录
  Future<List<DailyTask>?> getCachedDailyTasks({
    String status = 'active',
  }) async {
    final cacheKey = _buildCacheKey(status);
    final cacheTimestamp = await _cache.getTimestamp(cacheKey);
    if (cacheTimestamp == null) return null;
    return await _cache.getList<DailyTask>(cacheKey);
  }

  /// 获取所有日常任务（包括已暂停的）
  Future<List<DailyTask>> getAllDailyTasks() async {
    try {
      return await _service.getDailyTasks(status: '');
    } catch (e) {
      print('[DailyTaskRepository] 获取所有日常任务失败: $e');
      rethrow;
    }
  }

  /// 创建日常任务
  ///
  /// 副作用：
  /// - 清除所有日常任务缓存（触发下次重新加载）
  /// - 网络失败时自动加入离线队列
  Future<DailyTask> createDailyTask({
    String? title,
    String? description,
    DateTime? startTime,
    String? category,
    String? color,
  }) async {
    try {
      final newTask = await _service.createDailyTask(
        title: title,
        description: description,
        startTime: startTime,
        category: category,
        color: color,
      );

      // 清除所有相关缓存
      await _invalidateAllCache();

      print('[DailyTaskRepository] 日常任务创建成功，已清除缓存');
      return newTask;
    } on DioException catch (e) {
      // 网络错误：加入离线队列
      if (_isNetworkError(e)) {
        print('[DailyTaskRepository] ⚠️ 网络错误，加入离线队列');

        final tempId = 'temp_${_uuid.v4()}';
        final syncTask = SyncTask.create(
          id: _uuid.v4(),
          resourceType: ResourceType.dailyTask,
          operation: SyncOperation.create,
          resourceId: tempId,
          payload: {
            'title': title,
            'description': description,
            'startTime': startTime?.toIso8601String(),
            'category': category,
            'color': color,
          },
          priority: 7,
        );

        await _syncQueue.addTask(syncTask);
        await _invalidateAllCache();

        print('[DailyTaskRepository] 已加入离线队列，任务ID: ${syncTask.id}');

        // 返回临时对象
        throw Exception('离线模式，已加入同步队列');
      }
      rethrow;
    } catch (e) {
      print('[DailyTaskRepository] 创建日常任务失败: $e');
      rethrow;
    }
  }

  /// 更新日常任务
  ///
  /// 副作用：
  /// - 清除所有日常任务缓存
  /// - 网络失败时自动加入离线队列
  Future<DailyTask> updateDailyTask(
    String id, {
    String? title,
    String? description,
    DateTime? startTime,
    String? category,
    String? color,
  }) async {
    try {
      final updatedTask = await _service.updateDailyTask(
        id,
        title: title,
        description: description,
        startTime: startTime,
        category: category,
        color: color,
      );

      // 清除所有相关缓存
      await _invalidateAllCache();

      print('[DailyTaskRepository] 日常任务更新成功，已清除缓存');
      return updatedTask;
    } on DioException catch (e) {
      // 网络错误：加入离线队列
      if (_isNetworkError(e)) {
        print('[DailyTaskRepository] ⚠️ 网络错误，加入离线队列');

        final syncTask = SyncTask.create(
          id: _uuid.v4(),
          resourceType: ResourceType.dailyTask,
          operation: SyncOperation.update,
          resourceId: id,
          payload: {
            'title': title,
            'description': description,
            'startTime': startTime?.toIso8601String(),
            'category': category,
            'color': color,
          },
          priority: 6,
        );

        await _syncQueue.addTask(syncTask);
        await _invalidateAllCache();

        print('[DailyTaskRepository] 已加入离线队列，任务ID: ${syncTask.id}');
        throw Exception('离线模式，已加入同步队列');
      }
      rethrow;
    } catch (e) {
      print('[DailyTaskRepository] 更新日常任务失败: $e');
      rethrow;
    }
  }

  /// 删除日常任务
  ///
  /// 副作用：
  /// - 清除所有日常任务缓存
  /// - 网络失败时自动加入离线队列
  Future<void> deleteDailyTask(String id) async {
    try {
      await _service.deleteDailyTask(id);

      // 清除所有相关缓存
      await _invalidateAllCache();

      print('[DailyTaskRepository] 日常任务删除成功，已清除缓存');
    } on DioException catch (e) {
      // 网络错误：加入离线队列
      if (_isNetworkError(e)) {
        print('[DailyTaskRepository] ⚠️ 网络错误，加入离线队列');

        final syncTask = SyncTask.create(
          id: _uuid.v4(),
          resourceType: ResourceType.dailyTask,
          operation: SyncOperation.delete,
          resourceId: id,
          payload: {},
          priority: 5,
        );

        await _syncQueue.addTask(syncTask);
        await _invalidateAllCache();

        print('[DailyTaskRepository] 已加入离线队列，任务ID: ${syncTask.id}');
        return;
      }
      rethrow;
    } catch (e) {
      print('[DailyTaskRepository] 删除日常任务失败: $e');
      rethrow;
    }
  }

  /// 获取单个日常任务（不使用缓存，确保实时性）
  Future<DailyTask> getDailyTaskById(String id) async {
    return await _service.getDailyTask(id);
  }

  /// 获取日常任务统计信息
  Future<DailyTaskStats> getDailyTaskStats(String taskId) async {
    try {
      // 统计信息不使用缓存（实时性要求高）
      return await _service.getDailyTaskStats(taskId);
    } catch (e) {
      print('[DailyTaskRepository] 获取统计信息失败: $e');
      rethrow;
    }
  }

  /// 手动刷新缓存
  Future<List<DailyTask>> refreshDailyTasks({String status = 'active'}) async {
    // 强制刷新（不清缓存，失败时仍可回退到缓存）
    return await getDailyTasks(status: status, forceRefresh: true);
  }

  /// 清除所有日常任务缓存
  Future<void> clearAllCache() async {
    await _invalidateAllCache();
    print('[DailyTaskRepository] 所有缓存已清除');
  }

  /// 构建缓存键
  String _buildCacheKey(String status) {
    if (status.isEmpty || status == '') {
      return '${CacheKeys.dailyTasks}_all';
    }
    return '${CacheKeys.dailyTasks}_$status';
  }

  /// 清除所有日常任务相关的缓存
  Future<void> _invalidateAllCache() async {
    // 清除所有可能的缓存键
    await _cache.delete('${CacheKeys.dailyTasks}_active');
    await _cache.delete('${CacheKeys.dailyTasks}_paused');
    await _cache.delete('${CacheKeys.dailyTasks}_all');
    await _cache.delete(CacheKeys.dailyTasks);
    print('[DailyTaskRepository] 日常任务缓存已清除');
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
