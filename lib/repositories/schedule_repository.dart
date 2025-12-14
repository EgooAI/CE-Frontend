import '../models/schedule.dart';
import '../services/cache/cache_service.dart';
import '../services/cache/cache_keys.dart';
import '../services/schedule_service.dart';
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
  }) async {
    final cacheKey = CacheKeys.schedulesByMonth(year, month);
    
    try {
      // 1. 尝试读取缓存
      final cachedSchedules = await _cache.getList<Schedule>(cacheKey);
      final isCacheValid = cachedSchedules.isNotEmpty && 
                          !(await _cache.isExpired(cacheKey));
      
      if (isCacheValid) {
        print('[ScheduleRepository] 命中缓存: $cacheKey, 数量: ${cachedSchedules.length}');
        return cachedSchedules;
      }
      
      // 2. 缓存无效，请求 API（获取所有日程，然后过滤）
      print('[ScheduleRepository] 缓存未命中，请求 API: $cacheKey');
      final allSchedules = await _service.getSchedules();
      
      // 按年月过滤日程
      final filteredSchedules = allSchedules.where((s) {
        return s.startTime.year == year && s.startTime.month == month;
      }).toList();
      
      // 3. 更新缓存
      await _cache.setList(cacheKey, filteredSchedules);
      print('[ScheduleRepository] 缓存已更新: $cacheKey, 数量: ${filteredSchedules.length}');
      
      return filteredSchedules;
    } catch (e) {
      print('[ScheduleRepository] API 请求失败: $e');
      
      // 4. 降级方案：返回过期缓存（如果存在）
      final fallbackSchedules = await _cache.getList<Schedule>(cacheKey);
      if (fallbackSchedules.isNotEmpty) {
        print('[ScheduleRepository] ⚠️ 使用过期缓存作为降级方案, 数量: ${fallbackSchedules.length}');
        return fallbackSchedules;
      }
      
      // 5. 无缓存且 API 失败，抛出异常
      rethrow;
    }
  }
  
  /// 获取所有日程（跨月份）
  /// 
  /// 注意：不使用缓存（数据量太大）
  Future<List<Schedule>> getAllSchedules() async {
    try {
      return await _service.getSchedules();
    } catch (e) {
      print('[ScheduleRepository] 获取所有日程失败: $e');
      rethrow;
    }
  }
  
  /// 创建日程
  /// 
  /// 副作用：
  /// - 清除对应月份的缓存（触发下次重新加载）
  Future<void> createSchedule(Schedule schedule) async {
    try {
      await _service.createSchedule(schedule.toJson());
      
      // 清除对应月份的缓存
      final year = schedule.startTime.year;
      final month = schedule.startTime.month;
      await _invalidateMonthCache(year, month);
      
      print('[ScheduleRepository] 日程创建成功，已清除缓存: $year-$month');
    } catch (e) {
      print('[ScheduleRepository] 创建日程失败: $e');
      rethrow;
    }
  }
  
  /// 更新日程
  /// 
  /// 副作用：
  /// - 清除旧月份和新月份的缓存（如果开始时间改变）
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
    } catch (e) {
      print('[ScheduleRepository] 更新日程失败: $e');
      rethrow;
    }
  }
  
  /// 删除日程
  /// 
  /// 副作用：
  /// - 清除对应月份的缓存
  Future<void> deleteSchedule(String id) async {
    try {
      // 获取日程信息（用于确定月份）
      final schedule = await _service.getSchedule(id);
      
      await _service.deleteSchedule(id);
      
      // 清除对应月份缓存
      final year = schedule.startTime.year;
      final month = schedule.startTime.month;
      await _invalidateMonthCache(year, month);
      
      print('[ScheduleRepository] 日程删除成功，已清除缓存: $year-$month');
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
    // 先清除缓存
    await _invalidateMonthCache(year, month);
    
    // 重新加载
    return await getSchedules(year: year, month: month);
  }
  
  /// 清除所有日程缓存
  Future<void> clearAllCache() async {
    // 注意：这里只能清除已知的缓存 key
    // 更完整的方案是在 CacheService 中添加 deleteByPrefix 方法
    await _cache.clear();
    print('[ScheduleRepository] 所有缓存已清除');
  }
}
