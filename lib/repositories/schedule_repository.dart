import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule/schedule.dart';
import '../models/sync/sync_task.dart';
import '../services/cache/cache_service.dart';
import '../services/cache/cache_keys.dart';
import '../services/cache/conditional_request_service.dart';
import '../services/schedule/schedule_service.dart';
import '../services/sync/sync_queue_service.dart';
import '../utils/service_locator.dart';

/// Schedule 数据仓库
///
/// 职责：
/// - 封装缓存和网络请求逻辑
/// - 实现缓存优先策略（先读缓存 → 缓存过期则请求 API → 更新缓存）
/// - 提供离线访问能力
///
/// 使用示例：
/// ```dart
/// final repo = ScheduleRepository();
/// final schedules = await repo.getSchedules(year: 2025, month: 1);
/// ```
class ScheduleRepository {
  final CacheService _cache = locator<CacheService>();
  final ScheduleService _service = locator<ScheduleService>();
  final SyncQueueService _syncQueue = locator<SyncQueueService>();
  final _uuid = const Uuid();

  /// 获取日程列表（按年月查询，从所有日程中过滤）
  ///
  /// 缓存策略：
  /// 1. 先检查缓存是否存在且未过期
  /// 2. 如果缓存有效，直接返回
  /// 3. 如果缓存无效，请求 API 并更新缓存
  /// 4. 如果 API 请求失败，尝试返回过期缓存（降级方案）
  Future<List<Schedule>> getSchedules({
    required int year,
    required int month,
    bool forceRefresh = false,
  }) async {
    final cacheKey = CacheKeys.schedulesByMonth(year, month);

    try {
      // 1. 检查缓存是否存在 & 是否过期
      final cacheTimestamp = await _cache.getTimestamp(cacheKey);
      final isCacheExpired = await _cache.isExpired(cacheKey);

      if (forceRefresh) {
        print('[ScheduleRepository] 🔄 强制刷新，不发送 If-Modified-Since: $cacheKey');
        final response = await _service.getSchedulesWithResponse(
          skipConditionalRequest: true,
        );
        final data = response.data is List ? response.data : [];
        final allSchedules = (data as List)
            .map((json) => Schedule.fromJson(json as Map<String, dynamic>))
            .toList();

        final filteredSchedules = allSchedules.where((s) {
          return s.startTime.year == year && s.startTime.month == month;
        }).toList();

        await _cache.setList(cacheKey, filteredSchedules);
        return filteredSchedules;
      }

      // TTL 未过期，直接返回缓存（可能是空列表）
      if (!forceRefresh && cacheTimestamp != null && !isCacheExpired) {
        final cachedSchedules = await _cache.getList<Schedule>(cacheKey);
        print(
          '[ScheduleRepository] ✅ TTL 命中: $cacheKey, 数量: ${cachedSchedules.length}',
        );
        return cachedSchedules;
      }

      // TTL 过期，但缓存存在，使用条件请求判断
      if (cacheTimestamp != null) {
        final cachedSchedules = await _cache.getList<Schedule>(cacheKey);
        print('[ScheduleRepository] ⏰ TTL 过期，发送条件请求: $cacheKey');
        final response = await _service.getSchedulesWithResponse();

        if (ConditionalRequestService.isNotModified(response)) {
          print('[ScheduleRepository] ✅ 304 Not Modified，刷新 TTL');
          await _cache.refreshTTL(cacheKey);
          return cachedSchedules;
        }

        print('[ScheduleRepository] 📥 数据已更新，重新过滤');
        final data = response.data is List ? response.data : [];
        final allSchedules = (data as List)
            .map((json) => Schedule.fromJson(json as Map<String, dynamic>))
            .toList();

        final filteredSchedules = allSchedules.where((s) {
          return s.startTime.year == year && s.startTime.month == month;
        }).toList();

        await _cache.setList(cacheKey, filteredSchedules);
        return filteredSchedules;
      }

      // 2. 无缓存，请求 API（获取所有日程，然后过滤）
      print('[ScheduleRepository] 🌐 无缓存，请求 API: $cacheKey');
      final response = await _service.getSchedulesWithResponse();
      final data = response.data is List ? response.data : [];
      final allSchedules = (data as List)
          .map((json) => Schedule.fromJson(json as Map<String, dynamic>))
          .toList();

      // 按年月过滤日程
      final filteredSchedules = allSchedules.where((s) {
        return s.startTime.year == year && s.startTime.month == month;
      }).toList();

      await _cache.setList(cacheKey, filteredSchedules);
      print(
        '[ScheduleRepository] 缓存已创建: $cacheKey, 数量: ${filteredSchedules.length}',
      );

      return filteredSchedules;
    } catch (e) {
      print('[ScheduleRepository] API 请求失败: $e');

      // 4. 降级方案：返回过期缓存（如果存在）
      final cacheTimestamp = await _cache.getTimestamp(cacheKey);
      if (cacheTimestamp != null) {
        final fallbackSchedules = await _cache.getList<Schedule>(cacheKey);
        print(
          '[ScheduleRepository] ⚠️ 使用过期缓存作为降级方案, 数量: ${fallbackSchedules.length}',
        );
        return fallbackSchedules;
      }

      // 5. 无缓存且 API 失败，抛出异常
      rethrow;
    }
  }

  /// 获取所有日程（跨月份）
  ///
  /// 使用缓存 + 条件请求（304）优化
  Future<List<Schedule>> getAllSchedules({bool forceRefresh = false}) async {
    final cacheKey = CacheKeys.schedules;

    try {
      final cacheTimestamp = await _cache.getTimestamp(cacheKey);
      final isCacheExpired = await _cache.isExpired(cacheKey);

      if (forceRefresh) {
        print('[ScheduleRepository] 🔄 强制刷新(全量)，不发送 If-Modified-Since');
        final response = await _service.getSchedulesWithResponse(
          skipConditionalRequest: true,
        );
        final data = response.data is List ? response.data : [];
        final schedules = (data as List)
            .map((json) => Schedule.fromJson(json as Map<String, dynamic>))
            .toList();
        await _cache.setList(cacheKey, schedules);
        return schedules;
      }

      // 非强刷且 TTL 未过期，直接返回缓存（可能是空列表）
      if (!forceRefresh && cacheTimestamp != null && !isCacheExpired) {
        final cachedSchedules = await _cache.getList<Schedule>(cacheKey);
        print(
          '[ScheduleRepository] ✅ TTL 命中(全量): $cacheKey, 数量: ${cachedSchedules.length}',
        );
        return cachedSchedules;
      }

      // TTL 过期，但缓存存在，使用条件请求判断
      if (cacheTimestamp != null) {
        final cachedSchedules = await _cache.getList<Schedule>(cacheKey);
        print('[ScheduleRepository] ⏰ TTL 过期(全量)，发送条件请求: $cacheKey');
        final response = await _service.getSchedulesWithResponse();

        if (ConditionalRequestService.isNotModified(response)) {
          print('[ScheduleRepository] ✅ 304 Not Modified(全量)，刷新 TTL');
          await _cache.refreshTTL(cacheKey);
          return cachedSchedules;
        }

        final data = response.data is List ? response.data : [];
        final schedules = (data as List)
            .map((json) => Schedule.fromJson(json as Map<String, dynamic>))
            .toList();
        await _cache.setList(cacheKey, schedules);
        return schedules;
      }

      // 无缓存，请求 API
      print('[ScheduleRepository] 🌐 无缓存(全量)，请求 API: $cacheKey');
      final response = await _service.getSchedulesWithResponse();
      final data = response.data is List ? response.data : [];
      final schedules = (data as List)
          .map((json) => Schedule.fromJson(json as Map<String, dynamic>))
          .toList();

      await _cache.setList(cacheKey, schedules);
      print(
        '[ScheduleRepository] 缓存已创建(全量): $cacheKey, 数量: ${schedules.length}',
      );
      return schedules;
    } catch (e) {
      print('[ScheduleRepository] 获取所有日程失败: $e');

      final cacheTimestamp = await _cache.getTimestamp(cacheKey);
      if (cacheTimestamp != null) {
        final fallbackSchedules = await _cache.getList<Schedule>(cacheKey);
        print(
          '[ScheduleRepository] ⚠️ 使用过期缓存(全量)作为降级方案, 数量: ${fallbackSchedules.length}',
        );
        return fallbackSchedules;
      }

      rethrow;
    }
  }

  /// 获取缓存中的全量日程（即使已过期）
  ///
  /// 返回 null 表示没有缓存记录
  Future<List<Schedule>?> getCachedAllSchedules() async {
    final cacheKey = CacheKeys.schedules;
    final cacheTimestamp = await _cache.getTimestamp(cacheKey);
    if (cacheTimestamp == null) return null;
    return await _cache.getList<Schedule>(cacheKey);
  }

  /// 创建日程
  ///
  /// 副作用：
  /// - 清除对应月份的缓存（触发下次重新加载）
  /// - 网络失败时自动加入离线队列
  Future<void> createSchedule(Schedule schedule) async {
    final year = schedule.startTime.year;
    final month = schedule.startTime.month;

    try {
      await _service.createSchedule(schedule.toJson());

      // 清除对应月份的缓存
      await _invalidateMonthCache(year, month);

      print('[ScheduleRepository] 日程创建成功，已清除缓存: $year-$month');
    } on DioException catch (e) {
      // 网络错误：加入离线队列
      if (_isNetworkError(e)) {
        print('[ScheduleRepository] ⚠️ 网络错误，加入离线队列');

        // 生成临时 ID
        final tempId = 'temp_${_uuid.v4()}';

        // 创建同步任务
        final syncTask = SyncTask.create(
          id: _uuid.v4(),
          resourceType: ResourceType.schedule,
          operation: SyncOperation.create,
          resourceId: tempId,
          payload: schedule.toJson(),
          priority: 7, // 创建操作高优先级
        );

        await _syncQueue.addTask(syncTask);

        // 乐观更新：立即更新本地缓存
        // （用户看到创建成功，后台同步）
        await _invalidateMonthCache(year, month);
        print('[ScheduleRepository] 已加入离线队列，任务ID: ${syncTask.id}');
        return; // 不抛出异常，对用户透明
      }
      rethrow;
    } catch (e) {
      print('[ScheduleRepository] 创建日程失败: $e');
      rethrow;
    }
  }

  /// 更新日程
  ///
  /// 副作用：
  /// - 清除旧月份和新月份的缓存（如果开始时间改变）
  /// - 网络失败时自动加入离线队列
  Future<void> updateSchedule(Schedule schedule) async {
    try {
      // 获取旧日程（用于比较月份）
      final oldSchedule = await _service.getSchedule(schedule.id);

      await _service.updateSchedule(schedule.id, schedule.toJson());

      // 清除旧月份缓存
      final oldYear = oldSchedule.startTime.year;
      final oldMonth = oldSchedule.startTime.month;
      await _invalidateMonthCache(oldYear, oldMonth);

      // 如果月份改变，清除新月份缓存
      final newYear = schedule.startTime.year;
      final newMonth = schedule.startTime.month;
      if (oldYear != newYear || oldMonth != newMonth) {
        await _invalidateMonthCache(newYear, newMonth);
      }

      print('[ScheduleRepository] 日程更新成功，已清除缓存');
    } on DioException catch (e) {
      // 网络错误：加入离线队列
      if (_isNetworkError(e)) {
        print('[ScheduleRepository] ⚠️ 网络错误，加入离线队列');

        // 创建同步任务
        final syncTask = SyncTask.create(
          id: _uuid.v4(),
          resourceType: ResourceType.schedule,
          operation: SyncOperation.update,
          resourceId: schedule.id,
          payload: schedule.toJson(),
          priority: 6, // 更新操作中等优先级
        );

        await _syncQueue.addTask(syncTask);

        // 乐观更新缓存
        final year = schedule.startTime.year;
        final month = schedule.startTime.month;
        await _invalidateMonthCache(year, month);
        print('[ScheduleRepository] 已加入离线队列，任务ID: ${syncTask.id}');
        return;
      }
      rethrow;
    } catch (e) {
      print('[ScheduleRepository] 更新日程失败: $e');
      rethrow;
    }
  }

  /// 删除日程
  ///
  /// 副作用：
  /// - 清除对应月份的缓存
  /// - 网络失败时自动加入离线队列
  Future<void> deleteSchedule(String id) async {
    Schedule? schedule;

    try {
      // 获取日程信息（用于确定月份）
      schedule = await _service.getSchedule(id);

      await _service.deleteSchedule(id);

      // 清除对应月份缓存
      final year = schedule.startTime.year;
      final month = schedule.startTime.month;
      await _invalidateMonthCache(year, month);

      print('[ScheduleRepository] 日程删除成功，已清除缓存: $year-$month');
    } on DioException catch (e) {
      // 网络错误：加入离线队列
      if (_isNetworkError(e)) {
        print('[ScheduleRepository] ⚠️ 网络错误，加入离线队列');

        // 创建同步任务
        final syncTask = SyncTask.create(
          id: _uuid.v4(),
          resourceType: ResourceType.schedule,
          operation: SyncOperation.delete,
          resourceId: id,
          payload: {}, // 删除操作不需要 payload
          priority: 5, // 删除操作优先级稍低
        );

        await _syncQueue.addTask(syncTask);

        // 乐观更新：立即清除缓存（用户看到删除效果）
        if (schedule != null) {
          final year = schedule.startTime.year;
          final month = schedule.startTime.month;
          await _invalidateMonthCache(year, month);
        }
        print('[ScheduleRepository] 已加入离线队列，任务ID: ${syncTask.id}');
        return;
      }
      rethrow;
    } catch (e) {
      print('[ScheduleRepository] 删除日程失败: $e');
      rethrow;
    }
  }

  /// 获取单个日程（不使用缓存，确保实时性）
  Future<Schedule> getScheduleById(String id) async {
    return await _service.getSchedule(id);
  }

  /// 清除指定月份的缓存
  Future<void> _invalidateMonthCache(int year, int month) async {
    final cacheKey = CacheKeys.schedulesByMonth(year, month);
    await _cache.delete(cacheKey);
    print('[ScheduleRepository] 缓存已清除: $cacheKey');
  }

  /// 手动刷新缓存（下拉刷新时调用）
  Future<List<Schedule>> refreshSchedules({
    required int year,
    required int month,
  }) async {
    // 强制刷新（不清缓存，失败时仍可回退到缓存）
    return await getSchedules(year: year, month: month, forceRefresh: true);
  }

  /// 获取缓存中的日程列表（即使已过期）
  ///
  /// 返回 null 表示没有缓存记录
  Future<List<Schedule>?> getCachedSchedules({
    required int year,
    required int month,
  }) async {
    final cacheKey = CacheKeys.schedulesByMonth(year, month);
    final cacheTimestamp = await _cache.getTimestamp(cacheKey);
    if (cacheTimestamp == null) return null;
    return await _cache.getList<Schedule>(cacheKey);
  }

  /// 清除所有日程缓存
  Future<void> clearAllCache() async {
    // 注意：这里只能清除已知的缓存 key
    // 更完整的方案是在 CacheService 中添加 deleteByPrefix 方法
    await _cache.clear();
    print('[ScheduleRepository] 所有缓存已清除');
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
