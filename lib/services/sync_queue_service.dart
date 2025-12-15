import 'dart:async';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:synchronized/synchronized.dart';
import '../models/sync_task.dart';
import '../models/schedule.dart';
import 'schedule_service.dart';
import 'conversation_service.dart';
import 'daily_task_service.dart';

/// 同步队列服务
/// 管理离线编辑队列，支持自动重试、冲突解决、后台同步
class SyncQueueService {
  static const String _boxName = 'sync_queue';
  late Box<SyncTask> _queueBox;
  final _lock = Lock();
  bool _isProcessing = false;
  StreamController<int>? _pendingCountController;

  // 服务依赖
  final ScheduleService _scheduleService;
  final ConversationService _conversationService;

  SyncQueueService({
    required ScheduleService scheduleService,
    required ConversationService conversationService,
  }) : _scheduleService = scheduleService,
       _conversationService = conversationService;

  /// 初始化队列（需要先初始化 Hive）
  Future<void> init() async {
    _queueBox = await Hive.openBox<SyncTask>(_boxName);
    _pendingCountController = StreamController<int>.broadcast();
    _emitPendingCount();
    developer.log('✅ SyncQueueService 初始化完成，队列大小: ${_queueBox.length}');
  }

  /// 关闭服务
  Future<void> dispose() async {
    await _pendingCountController?.close();
    await _queueBox.close();
  }

  /// 监听待同步任务数量
  Stream<int> get pendingCountStream =>
      _pendingCountController?.stream ?? Stream.value(0);

  /// 当前待同步任务数量
  int get pendingCount => _queueBox.values
      .where((task) => task.status == SyncStatus.pending)
      .length;

  /// 添加任务到队列
  Future<void> addTask(SyncTask task) async {
    await _lock.synchronized(() async {
      await _queueBox.put(task.id, task);
      developer.log('📥 添加同步任务: $task');
      _emitPendingCount();
    });
  }

  /// 处理所有待同步任务
  /// 返回成功/失败的任务数量
  Future<Map<String, int>> processPendingTasks({
    bool highPriorityOnly = false,
    int maxConcurrent = 3,
  }) async {
    if (_isProcessing) {
      developer.log('⚠️ 同步已在进行中，跳过');
      return {'success': 0, 'failed': 0, 'skipped': 0};
    }

    return await _lock.synchronized(() async {
      _isProcessing = true;
      int successCount = 0;
      int failedCount = 0;
      int skippedCount = 0;

      try {
        // 获取待处理任务（按优先级和时间排序）
        final pendingTasks =
            _queueBox.values
                .where(
                  (task) =>
                      task.status == SyncStatus.pending &&
                      (!highPriorityOnly || task.isHighPriority),
                )
                .toList()
              ..sort((a, b) {
                // 先按优先级降序，再按时间升序
                if (a.priority != b.priority) {
                  return b.priority.compareTo(a.priority);
                }
                return a.createdAt.compareTo(b.createdAt);
              });

        if (pendingTasks.isEmpty) {
          developer.log('ℹ️ 无待同步任务');
          return {'success': 0, 'failed': 0, 'skipped': 0};
        }

        developer.log('🔄 开始处理 ${pendingTasks.length} 个同步任务...');

        // 分批并发处理（避免一次性发送太多请求）
        for (int i = 0; i < pendingTasks.length; i += maxConcurrent) {
          final batch = pendingTasks.skip(i).take(maxConcurrent).toList();
          final results = await Future.wait(
            batch.map((task) => _processTask(task)),
          );

          for (final result in results) {
            if (result == 'success') {
              successCount++;
            } else if (result == 'failed') {
              failedCount++;
            } else {
              skippedCount++;
            }
          }
        }

        developer.log(
          '✅ 同步完成: $successCount 成功, $failedCount 失败, $skippedCount 跳过',
        );
        _emitPendingCount();

        return {
          'success': successCount,
          'failed': failedCount,
          'skipped': skippedCount,
        };
      } finally {
        _isProcessing = false;
      }
    });
  }

  /// 处理单个任务
  /// 返回 'success' | 'failed' | 'skipped'
  Future<String> _processTask(SyncTask task) async {
    try {
      // 标记为同步中
      final syncingTask = task.markAsSyncing();
      await _queueBox.put(task.id, syncingTask);

      developer.log('🔄 处理任务: $task');

      // 根据资源类型和操作调用相应的 API
      await _executeTask(syncingTask);

      // 标记为成功
      final completedTask = syncingTask.markAsCompleted();
      await _queueBox.put(task.id, completedTask);

      // 30 秒后删除已完成任务（避免立即删除，方便调试）
      Future.delayed(const Duration(seconds: 30), () {
        _queueBox.delete(task.id);
      });

      developer.log('✅ 任务完成: ${task.id}');
      return 'success';
    } on DioException catch (e) {
      return await _handleTaskError(task, e);
    } catch (e, stack) {
      developer.log('❌ 任务处理异常: ${task.id}', error: e, stackTrace: stack);
      return await _handleTaskError(task, Exception('未知错误: $e'));
    }
  }

  /// 执行具体的 API 调用
  Future<void> _executeTask(SyncTask task) async {
    switch (task.resourceType) {
      case ResourceType.schedule:
        await _executeScheduleTask(task);
        break;
      case ResourceType.dailyTask:
        await _executeDailyTaskTask(task);
        break;
      case ResourceType.conversation:
        await _executeConversationTask(task);
        break;
    }
  }

  /// 执行日程任务
  Future<void> _executeScheduleTask(SyncTask task) async {
    switch (task.operation) {
      case SyncOperation.create:
        final schedule = Schedule.fromJson(task.payload);
        await _scheduleService.createSchedule(schedule.toJson());
        break;
      case SyncOperation.update:
        final schedule = Schedule.fromJson(task.payload);
        await _scheduleService.updateSchedule(
          task.resourceId,
          schedule.toJson(),
        );
        break;
      case SyncOperation.delete:
        await _scheduleService.deleteSchedule(task.resourceId);
        break;
    }
  }

  /// 执行日常任务同步
  Future<void> _executeDailyTaskTask(SyncTask task) async {
    final dailyTaskService = DailyTaskService();

    switch (task.operation) {
      case SyncOperation.create:
        developer.log('[SyncQueue] 创建日常任务: ${task.resourceId}');
        await dailyTaskService.createDailyTask(
          title: task.payload['title'] as String? ?? 'Untitled',
          description: task.payload['description'] as String?,
          startTime: task.payload['startTime'] != null
              ? DateTime.parse(task.payload['startTime'])
              : null,
          category: task.payload['category'] as String?,
          color: task.payload['color'] as String?,
        );
        break;

      case SyncOperation.update:
        developer.log('[SyncQueue] 更新日常任务: ${task.resourceId}');
        await dailyTaskService.updateDailyTask(
          task.resourceId,
          title: task.payload['title'] as String?,
          description: task.payload['description'] as String?,
          startTime: task.payload['startTime'] != null
              ? DateTime.parse(task.payload['startTime'])
              : null,
          category: task.payload['category'] as String?,
          color: task.payload['color'] as String?,
        );
        break;

      case SyncOperation.delete:
        developer.log('[SyncQueue] 删除日常任务: ${task.resourceId}');
        await dailyTaskService.deleteDailyTask(task.resourceId);
        break;
    }
  }

  /// 执行对话任务
  Future<void> _executeConversationTask(SyncTask task) async {
    switch (task.operation) {
      case SyncOperation.update:
        final title = task.payload['title'] as String;
        await _conversationService.updateConversationTitle(
          task.resourceId,
          title,
        );
        break;
      case SyncOperation.delete:
        await _conversationService.deleteConversation(task.resourceId);
        break;
      case SyncOperation.create:
        // 对话创建通常不需要离线队列
        developer.log('⚠️ 对话创建通常不需要离线同步');
        break;
    }
  }

  /// 处理任务错误
  Future<String> _handleTaskError(SyncTask task, dynamic error) async {
    final errorMessage = _extractErrorMessage(error);

    // 检查是否为冲突错误（409）
    if (error is DioException && error.response?.statusCode == 409) {
      developer.log('⚠️ 检测到冲突: ${task.id}');
      final conflictTask = task.markAsConflict(
        error.response?.data as Map<String, dynamic>? ?? {},
      );
      await _queueBox.put(task.id, conflictTask);
      return 'skipped'; // 需要手动解决冲突
    }

    // 标记为失败
    final failedTask = task.markAsFailed(errorMessage);

    // 检查是否可以重试
    if (failedTask.canRetry) {
      developer.log(
        '🔄 任务失败，将重试 (${failedTask.retryCount}/${failedTask.maxRetries}): ${task.id}',
      );
      // 重置为 pending 状态，等待下次同步
      final retryTask = failedTask.copyWith(status: SyncStatus.pending);
      await _queueBox.put(task.id, retryTask);
      return 'failed';
    } else {
      developer.log('❌ 任务失败且已达最大重试次数: ${task.id}');
      await _queueBox.put(task.id, failedTask);
      return 'failed';
    }
  }

  /// 提取错误信息
  String _extractErrorMessage(dynamic error) {
    if (error is DioException) {
      return error.response?.data?['error']?.toString() ??
          error.message ??
          '网络错误';
    }
    return error.toString();
  }

  /// 获取所有待同步任务
  List<SyncTask> getPendingTasks() {
    return _queueBox.values
        .where((task) => task.status == SyncStatus.pending)
        .toList();
  }

  /// 获取所有冲突任务
  List<SyncTask> getConflictTasks() {
    return _queueBox.values
        .where((task) => task.status == SyncStatus.conflict)
        .toList();
  }

  /// 解决冲突（使用本地版本）
  Future<void> resolveConflictWithLocal(String taskId) async {
    final task = _queueBox.get(taskId);
    if (task == null || task.status != SyncStatus.conflict) {
      throw Exception('任务不存在或不是冲突状态');
    }

    // 重置为 pending，使用本地数据重试
    final resolvedTask = task.copyWith(
      status: SyncStatus.pending,
      retryCount: 0,
      conflictData: null,
    );
    await _queueBox.put(taskId, resolvedTask);
    developer.log('✅ 冲突已解决（使用本地版本）: $taskId');
    _emitPendingCount();
  }

  /// 解决冲突（使用服务器版本）
  Future<void> resolveConflictWithServer(String taskId) async {
    final task = _queueBox.get(taskId);
    if (task == null || task.status != SyncStatus.conflict) {
      throw Exception('任务不存在或不是冲突状态');
    }

    // 直接标记为完成（放弃本地更改）
    final resolvedTask = task.copyWith(
      status: SyncStatus.completed,
      conflictData: null,
    );
    await _queueBox.put(taskId, resolvedTask);

    // 30 秒后删除
    Future.delayed(const Duration(seconds: 30), () {
      _queueBox.delete(taskId);
    });

    developer.log('✅ 冲突已解决（使用服务器版本）: $taskId');
    _emitPendingCount();
  }

  /// 清空所有已完成任务
  Future<int> cleanCompletedTasks() async {
    return await _lock.synchronized(() async {
      final completedTasks = _queueBox.values
          .where((task) => task.status == SyncStatus.completed)
          .toList();

      for (final task in completedTasks) {
        await _queueBox.delete(task.id);
      }

      developer.log('🧹 清空 ${completedTasks.length} 个已完成任务');
      return completedTasks.length;
    });
  }

  /// 清空所有失败任务（慎用）
  Future<int> cleanFailedTasks() async {
    return await _lock.synchronized(() async {
      final failedTasks = _queueBox.values
          .where((task) => task.status == SyncStatus.failed && !task.canRetry)
          .toList();

      for (final task in failedTasks) {
        await _queueBox.delete(task.id);
      }

      developer.log('🧹 清空 ${failedTasks.length} 个失败任务');
      return failedTasks.length;
    });
  }

  /// 发送待同步任务数量更新
  void _emitPendingCount() {
    _pendingCountController?.add(pendingCount);
  }

  /// 获取队列统计信息
  Map<String, int> getStatistics() {
    final tasks = _queueBox.values.toList();
    return {
      'total': tasks.length,
      'pending': tasks.where((t) => t.status == SyncStatus.pending).length,
      'syncing': tasks.where((t) => t.status == SyncStatus.syncing).length,
      'completed': tasks.where((t) => t.status == SyncStatus.completed).length,
      'failed': tasks.where((t) => t.status == SyncStatus.failed).length,
      'conflict': tasks.where((t) => t.status == SyncStatus.conflict).length,
    };
  }
}
