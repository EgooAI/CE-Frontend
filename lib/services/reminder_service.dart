import 'package:dio/dio.dart';
import '../models/reminder.dart';
import 'api_client.dart';

/// 提醒服务
class ReminderService {
  /// 获取所有提醒
  Future<RemindersResponse> getReminders() async {
    try {
      final response = await ApiClient.instance.get('/schedules/reminders');
      return RemindersResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.message ?? '获取提醒列表失败');
    }
  }
}
