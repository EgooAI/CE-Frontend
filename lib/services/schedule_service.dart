import 'package:dio/dio.dart';
import '../models/schedule.dart';
import 'api_client.dart';

class ScheduleService {
  // 获取所有日程
  Future<List<Schedule>> getSchedules() async {
    try {
      final response = await ApiClient.instance.get('/schedules');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List;
        return data.map((json) => Schedule.fromJson(json)).toList();
      } else {
        throw Exception('获取日程失败: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception('获取日程失败: ${e.response?.data ?? e.message}');
    }
  }

  // 获取单个日程详情
  Future<Schedule> getSchedule(String id) async {
    try {
      final response = await ApiClient.instance.get('/schedules/$id');
      
      if (response.statusCode == 200) {
        return Schedule.fromJson(response.data);
      } else {
        throw Exception('获取日程详情失败: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception('获取日程详情失败: ${e.response?.data ?? e.message}');
    }
  }

  // 创建日程
  Future<Schedule> createSchedule(Map<String, dynamic> scheduleData) async {
    try {
      final response = await ApiClient.instance.post(
        '/schedules',
        data: scheduleData,
      );
      
      if (response.statusCode == 201) {
        return Schedule.fromJson(response.data);
      } else {
        throw Exception('创建日程失败: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception('创建日程失败: ${e.response?.data ?? e.message}');
    }
  }

  // 更新日程
  Future<Schedule> updateSchedule(String id, Map<String, dynamic> scheduleData) async {
    try {
      final response = await ApiClient.instance.put(
        '/schedules/$id',
        data: scheduleData,
      );
      
      if (response.statusCode == 200) {
        return Schedule.fromJson(response.data);
      } else {
        throw Exception('更新日程失败: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception('更新日程失败: ${e.response?.data ?? e.message}');
    }
  }

  // 删除日程
  Future<void> deleteSchedule(String id) async {
    try {
      final response = await ApiClient.instance.delete('/schedules/$id');
      
      if (response.statusCode != 200) {
        throw Exception('删除日程失败: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception('删除日程失败: ${e.response?.data ?? e.message}');
    }
  }
}
