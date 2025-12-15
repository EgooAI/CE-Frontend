import 'package:dio/dio.dart';
import '../models/daily_task.dart';
import 'api_client.dart';

/// 日常任务服务层
class DailyTaskService {
  /// 创建日常任务
  Future<DailyTask> createDailyTask({
    String? title,
    String? description,
    DateTime? startTime,
    String? category,
    String? color,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (startTime != null) data['startTime'] = _formatDateTime(startTime);
      if (category != null) data['category'] = category;
      if (color != null) data['color'] = color;

      final response = await ApiClient.instance.post(
        '/daily-tasks',
        data: data,
      );
      return DailyTask.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.message ?? '创建日常任务失败');
    }
  }

  /// 获取日常任务列表
  Future<List<DailyTask>> getDailyTasks({String? status}) async {
    try {
      final response = await ApiClient.instance.get(
        '/daily-tasks',
        queryParameters: status != null ? {'status': status} : null,
      );
      final List<dynamic> data = response.data is List ? response.data : [];
      return data.map((json) => DailyTask.fromJson(json)).toList();
    } on DioException catch (e) {
      throw Exception(e.message ?? '获取日常任务列表失败');
    }
  }

  /// 获取单个日常任务详情
  Future<DailyTask> getDailyTask(String taskId) async {
    try {
      final response = await ApiClient.instance.get('/daily-tasks/$taskId');
      return DailyTask.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.message ?? '获取日常任务失败');
    }
  }

  /// 更新日常任务
  Future<DailyTask> updateDailyTask(
    String taskId, {
    String? title,
    String? description,
    DateTime? startTime,
    String? category,
    String? color,
  }) async {
    try {
      final response = await ApiClient.instance.put(
        '/daily-tasks/$taskId',
        data: {
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          if (startTime != null) 'startTime': _formatDateTime(startTime),
          if (category != null) 'category': category,
          if (color != null) 'color': color,
        },
      );
      return DailyTask.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.message ?? '更新日常任务失败');
    }
  }

  /// 切换日常任务状态
  Future<DailyTask> toggleDailyTaskStatus(
    String taskId,
    String newStatus,
  ) async {
    try {
      final response = await ApiClient.instance.patch(
        '/daily-tasks/$taskId/status',
        data: {'status': newStatus},
      );
      return DailyTask.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.message ?? '切换日常任务状态失败');
    }
  }

  /// 删除日常任务
  Future<void> deleteDailyTask(String taskId) async {
    try {
      await ApiClient.instance.delete('/daily-tasks/$taskId');
    } on DioException catch (e) {
      throw Exception(e.message ?? '删除日常任务失败');
    }
  }

  /// 打卡（标记今天完成情况）
  Future<DailyTaskLog> logDailyTask(
    String taskId, {
    required bool completed,
    String? note,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        '/daily-tasks/$taskId/log',
        data: {'completed': completed, if (note != null) 'note': note},
      );
      return DailyTaskLog.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.message ?? '打卡失败');
    }
  }

  /// 取消今日打卡
  Future<void> cancelTodayLog(String taskId) async {
    try {
      await ApiClient.instance.delete('/daily-tasks/$taskId/log/today');
    } on DioException catch (e) {
      throw Exception(e.message ?? '取消打卡失败');
    }
  }

  /// 获取打卡记录
  Future<List<DailyTaskLog>> getDailyTaskLogs(
    String taskId, {
    int days = 30,
  }) async {
    try {
      final response = await ApiClient.instance.get(
        '/daily-tasks/$taskId/logs',
        queryParameters: {'days': days},
      );
      final List<dynamic> data = response.data is List ? response.data : [];
      return data.map((json) => DailyTaskLog.fromJson(json)).toList();
    } on DioException catch (e) {
      throw Exception(e.message ?? '获取打卡记录失败');
    }
  }

  /// 获取统计信息
  Future<DailyTaskStats> getDailyTaskStats(String taskId) async {
    try {
      final response = await ApiClient.instance.get(
        '/daily-tasks/$taskId/stats',
      );
      return DailyTaskStats.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.message ?? '获取统计信息失败');
    }
  }

  String _formatDateTime(DateTime dt) {
    final offset = dt.timeZoneOffset;
    final offsetHours = offset.inHours.toString().padLeft(2, '0');
    final offsetMinutes = (offset.inMinutes % 60).abs().toString().padLeft(
      2,
      '0',
    );
    final sign = offset.isNegative ? '-' : '+';

    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');

    return '$year-$month-${day}T$hour:$minute:$second$sign$offsetHours:$offsetMinutes';
  }
}
