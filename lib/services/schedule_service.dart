import 'package:dio/dio.dart';
import '../models/schedule.dart';
import 'api_client.dart';

class ScheduleService {
  ScheduleService();

  Future<List<Schedule>> getSchedules({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final response = await ApiClient.instance.get(
        '/schedules',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> body = response.data;
        return body.map((e) => Schedule.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load schedules: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception(
        'Failed to load schedules: ${e.response?.data ?? e.message}',
      );
    }
  }

  Future<Schedule> getSchedule(String id) async {
    try {
      final response = await ApiClient.instance.get('/schedules/$id');

      if (response.statusCode == 200) {
        return Schedule.fromJson(response.data);
      } else {
        throw Exception('Failed to load schedule: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception(
        'Failed to load schedule: ${e.response?.data ?? e.message}',
      );
    }
  }

  Future<Schedule> createSchedule({
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        '/schedules',
        data: {
          'title': title,
          'description': description,
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'location': location,
        },
      );

      if (response.statusCode == 201) {
        return Schedule.fromJson(response.data);
      } else {
        throw Exception('Failed to create schedule: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception(
        'Failed to create schedule: ${e.response?.data ?? e.message}',
      );
    }
  }

  Future<Schedule> updateSchedule({
    required String id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    bool? isCompleted,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (startTime != null) data['startTime'] = startTime.toIso8601String();
      if (endTime != null) data['endTime'] = endTime.toIso8601String();
      if (location != null) data['location'] = location;
      if (isCompleted != null) data['isCompleted'] = isCompleted;

      final response = await ApiClient.instance.put(
        '/schedules/$id',
        data: data,
      );

      if (response.statusCode == 200) {
        return Schedule.fromJson(response.data);
      } else {
        throw Exception('Failed to update schedule: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception(
        'Failed to update schedule: ${e.response?.data ?? e.message}',
      );
    }
  }

  Future<void> deleteSchedule(String id) async {
    try {
      final response = await ApiClient.instance.delete('/schedules/$id');

      if (response.statusCode != 200) {
        throw Exception('Failed to delete schedule: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception(
        'Failed to delete schedule: ${e.response?.data ?? e.message}',
      );
    }
  }
}
