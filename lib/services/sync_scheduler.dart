import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:workmanager/workmanager.dart';
import '../utils/service_locator.dart';
import 'sync_queue_service.dart';

/// 后台同步调度器
///
/// 职责：
/// - 监听网络状态变化
/// - 网络恢复时立即触发同步
/// - 定期后台同步（每5分钟）
/// - 管理 WorkManager 后台任务
class SyncScheduler {
  static const String _syncTaskName = 'syncQueueTask';
  static const String _uniqueTaskName = 'periodicSyncQueue';

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = false;

  /// 初始化同步调度器
  Future<void> init() async {
    developer.log('🔄 [SyncScheduler] 初始化同步调度器...');

    // 1. 检查初始网络状态
    await _checkInitialConnectivity();

    // 2. 监听网络状态变化
    _listenToConnectivityChanges();

    // 3. 注册 WorkManager 后台任务
    await _registerBackgroundSync();

    developer.log('✅ [SyncScheduler] 同步调度器初始化完成');
  }

  /// 检查初始网络状态
  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = _isConnected(results);
      developer.log('[SyncScheduler] 初始网络状态: ${_isOnline ? "在线" : "离线"}');

      // 如果初始就在线，触发一次同步
      if (_isOnline) {
        _triggerSync();
      }
    } catch (e) {
      developer.log('[SyncScheduler] ⚠️ 检查网络状态失败: $e');
    }
  }

  /// 监听网络状态变化
  void _listenToConnectivityChanges() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final wasOnline = _isOnline;
        _isOnline = _isConnected(results);

        developer.log(
          '[SyncScheduler] 网络状态变化: ${wasOnline ? "在线" : "离线"} → ${_isOnline ? "在线" : "离线"}',
        );

        // 从离线→在线：立即触发同步
        if (!wasOnline && _isOnline) {
          developer.log('[SyncScheduler] 🌐 网络已恢复，触发立即同步');
          _triggerSync();
        }
      },
      onError: (error) {
        developer.log('[SyncScheduler] ⚠️ 网络监听错误: $error');
      },
    );
  }

  /// 判断是否有网络连接
  bool _isConnected(List<ConnectivityResult> results) {
    return results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet,
    );
  }

  /// 触发立即同步
  void _triggerSync() {
    developer.log('[SyncScheduler] 🔄 开始处理离线队列...');

    // 异步处理，不阻塞主线程
    Future.microtask(() async {
      try {
        final syncQueue = locator<SyncQueueService>();
        final result = await syncQueue.processPendingTasks(maxConcurrent: 3);

        developer.log(
          '[SyncScheduler] ✅ 同步完成: ${result['success']} 成功, '
          '${result['failed']} 失败, ${result['skipped']} 跳过',
        );
      } catch (e) {
        developer.log('[SyncScheduler] ❌ 同步失败: $e');
      }
    });
  }

  /// 注册 WorkManager 后台任务
  Future<void> _registerBackgroundSync() async {
    // Web 平台不支持 WorkManager
    if (kIsWeb) {
      developer.log('[SyncScheduler] ℹ️ Web 平台跳过 WorkManager 后台任务注册');
      return;
    }

    try {
      // 注册定期任务（每15分钟执行一次，最小间隔）
      await Workmanager().registerPeriodicTask(
        _uniqueTaskName,
        _syncTaskName,
        frequency: const Duration(minutes: 15), // WorkManager 最小间隔
        constraints: Constraints(
          networkType: NetworkType.connected, // 仅在有网络时执行
          requiresBatteryNotLow: true, // 电量充足时执行
        ),
      );

      developer.log('[SyncScheduler] ✅ 后台任务已注册 (每15分钟)');
    } catch (e) {
      developer.log('[SyncScheduler] ⚠️ 注册后台任务失败: $e');
    }
  }

  /// 手动触发同步（供用户下拉刷新使用）
  Future<Map<String, int>> manualSync() async {
    developer.log('[SyncScheduler] 📲 用户手动触发同步');

    try {
      final syncQueue = locator<SyncQueueService>();
      return await syncQueue.processPendingTasks(maxConcurrent: 3);
    } catch (e) {
      developer.log('[SyncScheduler] ❌ 手动同步失败: $e');
      return {'success': 0, 'failed': 0, 'skipped': 0};
    }
  }

  /// 获取当前网络状态
  bool get isOnline => _isOnline;

  /// 获取待同步任务数量
  int get pendingCount {
    try {
      final syncQueue = locator<SyncQueueService>();
      return syncQueue.pendingCount;
    } catch (e) {
      return 0;
    }
  }

  /// 监听待同步任务数量变化
  Stream<int> get pendingCountStream {
    try {
      final syncQueue = locator<SyncQueueService>();
      return syncQueue.pendingCountStream;
    } catch (e) {
      return Stream.value(0);
    }
  }

  /// 清理资源
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();

    // Web 平台不支持 WorkManager
    if (!kIsWeb) {
      try {
        await Workmanager().cancelByUniqueName(_uniqueTaskName);
      } catch (e) {
        developer.log('[SyncScheduler] ⚠️ 取消后台任务失败: $e');
      }
    }

    developer.log('[SyncScheduler] 同步调度器已清理');
  }
}

/// WorkManager 后台任务回调
///
/// 注意：这个函数必须是顶层函数或静态方法
@pragma('vm:entry-point')
void syncQueueCallback() {
  Workmanager().executeTask((task, inputData) async {
    developer.log('[WorkManager] 🔄 后台任务开始: $task');

    try {
      // 重新初始化服务（后台隔离环境）
      await setupServiceLocator();

      // 处理队列
      final syncQueue = locator<SyncQueueService>();
      final result = await syncQueue.processPendingTasks(
        maxConcurrent: 2, // 后台降低并发
      );

      developer.log(
        '[WorkManager] ✅ 后台同步完成: ${result['success']} 成功, '
        '${result['failed']} 失败',
      );

      return Future.value(true);
    } catch (e) {
      developer.log('[WorkManager] ❌ 后台任务失败: $e');
      return Future.value(false);
    }
  });
}
