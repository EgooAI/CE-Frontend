import 'package:dio/dio.dart';
import '../../models/schedule/schedule.dart';
import '../core/api_client.dart';

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

  // 删除重复日程模板（系列）
  // deleteInstances: none(默认) | future | all
  // - none: 只删模板，保留已生成的实例
  // - future: 删模板和未来的实例
  // - all: 删模板和所有实例
  Future<void> deleteRecurrenceTemplate(
    String parentId, {
    String deleteInstances = 'none',
  }) async {
    try {
      await ApiClient.instance.delete(
        '/schedules/series/$parentId',
        queryParameters: {'deleteInstances': deleteInstances},
      );
    } on DioException catch (e) {
      throw Exception(e.message ?? '删除重复日程失败');
    }
  }

  // 更新重复日程系列
  // strategy: future 或 all
  // - future: 更新该实例及未来实例
  // - all: 更新该实例及所有实例
  Future<void> updateRecurrenceSeries(
    String parentId,
    Map<String, dynamic> scheduleData, {
    String? strategy,
  }) async {
    try {
      final params = strategy != null
          ? {'strategy': strategy}
          : <String, dynamic>{};
      await ApiClient.instance.put(
        '/schedules/series/$parentId',
        data: scheduleData,
        queryParameters: params,
      );
    } on DioException catch (e) {
      throw Exception(e.message ?? '更新重复日程失败');
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
