import 'package:dio/dio.dart';
import '../models/schedule.dart';
import 'api_client.dart';

class ScheduleService {
  // 获取所有日程
  Future<List<Schedule>> getSchedules() async {
    try {
      final response = await ApiClient.instance.get('/schedules');
      final List<dynamic> data = response.data as List;
      return data.map((json) => Schedule.fromJson(json)).toList();
    } on DioException catch (e) {
      throw Exception(e.message ?? '获取日程失败');
    }
  }

  // 获取单个日程详情
  Future<Schedule> getSchedule(String id) async {
    try {
      final response = await ApiClient.instance.get('/schedules/$id');
      return Schedule.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.message ?? '获取日程详情失败');
    }
  }

  // 创建日程
  Future<void> createSchedule(Map<String, dynamic> scheduleData) async {
    try {
      await ApiClient.instance.post('/schedules', data: scheduleData);
      // 成功时拦截器会自动处理，失败时会抛出异常
    } on DioException catch (e) {
      throw Exception(e.message ?? '创建日程失败');
    }
  }

  // 更新日程
  Future<void> updateSchedule(
    String id,
    Map<String, dynamic> scheduleData,
  ) async {
    try {
      await ApiClient.instance.put('/schedules/$id', data: scheduleData);
      // 成功时拦截器会自动处理，失败时会抛出异常
    } on DioException catch (e) {
      throw Exception(e.message ?? '更新日程失败');
    }
  }

  // 删除日程
  Future<void> deleteSchedule(String id) async {
    try {
      await ApiClient.instance.delete('/schedules/$id');
    } on DioException catch (e) {
      throw Exception(e.message ?? '删除日程失败');
    }
  }

  // 删除重复日程模板
  // strategy: none(默认) | future | all
  Future<void> deleteRecurrenceTemplate(
    String templateId, {
    String strategy = 'none',
  }) async {
    try {
      await ApiClient.instance.delete(
        '/schedules/templates/$templateId',
        queryParameters: {'strategy': strategy},
      );
    } on DioException catch (e) {
      throw Exception(e.message ?? '删除重复日程失败');
    }
  }

  // 获取所有重复日程模板
  Future<List<Schedule>> getTemplates() async {
    try {
      final response = await ApiClient.instance.get('/schedules/templates');
      final List<dynamic> data = response.data as List;
      return data.map((json) => Schedule.fromJson(json)).toList();
    } on DioException catch (e) {
      throw Exception(e.message ?? '获取重复日程模板失败');
    }
  }
}
