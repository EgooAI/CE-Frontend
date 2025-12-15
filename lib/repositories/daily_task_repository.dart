import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/daily_task.dart';
import '../models/sync_task.dart';
import '../services/cache/cache_service.dart';
import '../services/cache/cache_keys.dart';
import '../services/daily_task_service.dart';
import '../services/sync_queue_service.dart';
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
  Future<List<DailyTask>> getDailyTasks({String status = 'active'}) async {
    final cacheKey = _buildCacheKey(status);

    try {
      // 1. 尝试读取缓存
      final cachedTasks = await _cache.getList<DailyTask>(cacheKey);
      final isCacheValid =
          cachedTasks.isNotEmpty && !(await _cache.isExpired(cacheKey));

      if (isCacheValid) {
        print(
          '[DailyTaskRepository] 命中缓存: $cacheKey, 数量: ${cachedTasks.length}',
        );
        return cachedTasks;
      }

      // 2. 缓存无效，请求 API
      print('[DailyTaskRepository] 缓存未命中，请求 API: $cacheKey');
      final tasks = await _service.getDailyTasks(status: status);

      // 3. 更新缓存
      await _cache.setList(cacheKey, tasks);
      print('[DailyTaskRepository] 缓存已更新: $cacheKey, 数量: ${tasks.length}');

      return tasks;
    } catch (e) {
      print('[DailyTaskRepository] API 请求失败: $e');

      // 4. 降级方案：返回过期缓存（如果存在）
      final fallbackTasks = await _cache.getList<DailyTask>(cacheKey);
      if (fallbackTasks.isNotEmpty) {
        print(
          '[DailyTaskRepository] ⚠️ 使用过期缓存作为降级方案, 数量: ${fallbackTasks.length}',
        );
        return fallbackTasks;
      }

      // 5. 无缓存且 API 失败，抛出异常
      rethrow;
    }
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
    // 先清除缓存
    await _invalidateAllCache();

    // 重新加载
    return await getDailyTasks(status: status);
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
