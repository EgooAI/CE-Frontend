import 'schedule.dart';

/// 提醒数据模型
class Reminder {
  final String id;
  final String scheduleId;
  final DateTime remindAt; // 提醒时间
  final bool reminded; // 是否已提醒
  final DateTime createdAt;
  final Schedule? schedule; // 关联的日程对象

  Reminder({
    required this.id,
    required this.scheduleId,
    required this.remindAt,
    required this.reminded,
    required this.createdAt,
    this.schedule,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] ?? '',
      scheduleId: json['scheduleId'] ?? '',
      remindAt: DateTime.parse(json['remindAt']).toLocal(),
      reminded: json['reminded'] ?? false,
      createdAt: DateTime.parse(json['createdAt']).toLocal(),
      schedule: json['schedule'] != null
          ? Schedule.fromJson(json['schedule'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scheduleId': scheduleId,
      'remindAt': remindAt.toIso8601String(),
      'reminded': reminded,
      'createdAt': createdAt.toIso8601String(),
      if (schedule != null) 'schedule': schedule!.toJson(),
    };
  }
}

/// 提醒列表响应
class RemindersResponse {
  final int total;
  final List<Reminder> reminders;

  RemindersResponse({required this.total, required this.reminders});

  factory RemindersResponse.fromJson(Map<String, dynamic> json) {
    return RemindersResponse(
      total: json['total'] ?? 0,
      reminders:
          (json['reminders'] as List<dynamic>?)
              ?.map((item) => Reminder.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
