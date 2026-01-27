import 'dart:convert';
import 'package:hive/hive.dart';

part 'schedule.g.dart';

@HiveType(typeId: 0)
class Schedule {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String userId;
  @HiveField(2)
  final String title;
  @HiveField(3)
  final String? description;
  @HiveField(4)
  final DateTime startTime;
  @HiveField(5)
  final DateTime? endTime; // 结束时间可选
  @HiveField(6)
  final bool allDay;
  @HiveField(7)
  final String? location;
  @HiveField(8)
  final String status; // pending/in_progress/completed/cancelled/failed
  @HiveField(9)
  final String? type; // meeting/task/event
  @HiveField(10)
  final String? priority; // high/medium/low
  @HiveField(11)
  final String? recurrence;
  @HiveField(12)
  final String? participants; // JSON string
  @HiveField(13)
  final String? notes;
  @HiveField(14)
  final String? attachments; // JSON string
  @HiveField(15)
  final String? daomengId;
  @HiveField(16)
  final int? remindBefore; // 提前提醒分钟数
  @HiveField(17)
  final List<dynamic>? reminders; // 提醒列表
  @HiveField(18)
  final String? parentId; // 重复日程模板 ID
  @HiveField(19)
  final int? iterationIndex; // 第几次实例（从 1 开始）
  @HiveField(20)
  final DateTime? createdAt;
  @HiveField(21)
  final DateTime? updatedAt;
  @HiveField(22)
  final bool isDaily;

  Schedule({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.startTime,
    this.endTime, // 结束时间可选
    required this.allDay,
    this.location,
    required this.status,
    this.type,
    this.priority,
    this.recurrence,
    this.participants,
    this.notes,
    this.attachments,
    this.daomengId,
    this.remindBefore,
    this.reminders,
    this.parentId,
    this.iterationIndex,
    this.createdAt,
    this.updatedAt,
    this.isDaily = false,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    final dynamic rawRecurrence = json['recurrence'] ?? json['rule'];
    final String? recurrenceValue = rawRecurrence == null
        ? null
        : (rawRecurrence is String ? rawRecurrence : jsonEncode(rawRecurrence));
    // DateTime.parse() 会将带时区的时间转换为 UTC
    // 需要使用 .toLocal() 转换回本地时区，保持正确的日期
    return Schedule(
      id: json['id'],
      userId: json['userId'] ?? '', // 模板列表可能没有 userId
      title: json['title'],
      description: json['description'],
      // 转换为本地时区，确保日期正确
      startTime: DateTime.parse(json['startTime']).toLocal(),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime']).toLocal()
          : null,
      allDay: json['allDay'] ?? false,
      location: json['location'],
      status: json['status'] ?? 'pending',
      type: json['type'],
      priority: json['priority'],
      // 兼容后端返回的 rule（重复规则字段名）
      recurrence: recurrenceValue,
      participants: json['participants'],
      notes: json['notes'],
      attachments: json['attachments'],
      daomengId: json['daomengId'],
      remindBefore: json['remindBefore'],
      reminders: json['reminders'],
      parentId: json['parentId'],
      iterationIndex: json['iterationIndex'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt']).toLocal()
          : null,
      isDaily: json['type'] == 'daily' ? true : false,
    );
  }

  Map<String, dynamic> toJson() {
    // 格式化为 RFC3339 格式（带时区偏移量）
    String formatDateTime(DateTime dt) {
      // 使用本地时间并添加时区偏移量 +08:00
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

    // 处理 recurrence：如果是 JSON 字符串，解析成对象
    dynamic recurrenceValue;
    if (recurrence != null && recurrence!.isNotEmpty) {
      try {
        recurrenceValue = jsonDecode(recurrence!);
      } catch (_) {
        // 解析失败，可能本身就是对象或其他格式，保持原样
        recurrenceValue = recurrence;
      }
    }

    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'startTime': formatDateTime(startTime),
      if (endTime != null) 'endTime': formatDateTime(endTime!),
      'allDay': allDay,
      'location': location,
      'status': status,
      'type': type,
      'priority': priority,
      if (recurrenceValue != null) 'recurrence': recurrenceValue,
      'participants': participants,
      'notes': notes,
      'attachments': attachments,
      'daomengId': daomengId,
      if (remindBefore != null) 'remindBefore': remindBefore,
      if (reminders != null) 'reminders': reminders,
      if (parentId != null) 'parentId': parentId,
      if (iterationIndex != null) 'iterationIndex': iterationIndex,
      'createdAt': createdAt != null ? formatDateTime(createdAt!) : null,
      'updatedAt': updatedAt != null ? formatDateTime(updatedAt!) : null,
    };
  }

  // 判断是否应该显示红点（未完成的日程）
  bool shouldShowMarker() {
    return status != 'completed' && status != 'cancelled';
  }

  // 格式化时间显示
  String getTimeDisplay({
    bool use24HourFormat = true,
    bool useChinesePeriod = true,
  }) {
    String formatTime(DateTime dt) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      if (use24HourFormat) return '$hh:$mm';

      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final period = dt.hour < 12
          ? (useChinesePeriod ? '上午 ' : 'AM ')
          : (useChinesePeriod ? '下午 ' : 'PM ');
      return '$period${hour12.toString().padLeft(2, '0')}:$mm';
    }

    if (allDay) {
      return '全天';
    }
    final startStr = formatTime(startTime);
    if (endTime == null) {
      return startStr;
    }
    final endStr = formatTime(endTime!);
    return '$startStr - $endStr';
  }

  // 获取状态显示文本
  String getStatusText() {
    switch (status) {
      case 'in_progress':
        return '进行中';
      case 'pending':
        return '待开始';
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已取消';
      case 'failed':
        return '未完成';
      default:
        return '未知';
    }
  }

  // 获取优先级显示文本
  String? getPriorityText() {
    switch (priority) {
      case 'high':
        return '高';
      case 'medium':
        return '中';
      case 'low':
        return '低';
      default:
        return null;
    }
  }

  // 获取类型显示文本
  String? getTypeText() {
    switch (type) {
      case 'meeting':
        return '会议';
      case 'task':
        return '任务';
      case 'event':
        return '活动';
      default:
        return null;
    }
  }

  // 复制对象并修改指定字段
  Schedule copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    bool? allDay,
    String? location,
    String? status,
    String? type,
    String? priority,
    String? recurrence,
    String? participants,
    String? notes,
    String? attachments,
    String? daomengId,
    int? remindBefore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Schedule(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      allDay: allDay ?? this.allDay,
      location: location ?? this.location,
      status: status ?? this.status,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      recurrence: recurrence ?? this.recurrence,
      participants: participants ?? this.participants,
      notes: notes ?? this.notes,
      attachments: attachments ?? this.attachments,
      daomengId: daomengId ?? this.daomengId,
      remindBefore: remindBefore ?? this.remindBefore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
