import 'package:hive/hive.dart';

part 'daily_task.g.dart';

/// 日常任务（Daily Task）数据模型
@HiveType(typeId: 1)
class DailyTask {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String userId;
  @HiveField(2)
  final String title; // 任务名称
  @HiveField(3)
  final String? description; // 任务描述
  @HiveField(4)
  final DateTime? startTime; // 推荐执行时刻，使用固定日期锚点（例如 1970-01-01）
  @HiveField(5)
  final String status; // active / paused
  @HiveField(6)
  final String? category; // 分类标签
  @HiveField(7)
  final String? color; // 颜色代码 (e.g., "#FF6B6B")
  @HiveField(8)
  final DateTime? createdAt;
  @HiveField(9)
  final DateTime? updatedAt;

  DailyTask({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.startTime,
    required this.status,
    this.category,
    this.color,
    this.createdAt,
    this.updatedAt,
  });

  factory DailyTask.fromJson(Map<String, dynamic> json) {
    return DailyTask(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime']).toLocal()
          : null,
      status: json['status'] ?? 'active',
      category: json['category'],
      color: json['color'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt']).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    String formatDateTime(DateTime dt) {
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

    return {
      'id': id,
      'userId': userId,
      'title': title,
      if (description != null) 'description': description,
      if (startTime != null) 'startTime': formatDateTime(startTime!),
      'status': status,
      if (category != null) 'category': category,
      if (color != null) 'color': color,
      if (createdAt != null) 'createdAt': formatDateTime(createdAt!),
      if (updatedAt != null) 'updatedAt': formatDateTime(updatedAt!),
    };
  }

  // 复制对象并修改指定字段
  DailyTask copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? startTime,
    String? status,
    String? category,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyTask(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      status: status ?? this.status,
      category: category ?? this.category,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // 获取显示用的时间文本
  String getTimeDisplay({
    bool use24HourFormat = true,
    bool useChinesePeriod = true,
  }) {
    if (startTime == null) return '无设置';
    final hh = startTime!.hour.toString().padLeft(2, '0');
    final mm = startTime!.minute.toString().padLeft(2, '0');
    if (use24HourFormat) return '$hh:$mm';

    final hour12 = startTime!.hour % 12 == 0 ? 12 : startTime!.hour % 12;
    final period = startTime!.hour < 12
        ? (useChinesePeriod ? '上午 ' : 'AM ')
        : (useChinesePeriod ? '下午 ' : 'PM ');
    return '$period${hour12.toString().padLeft(2, '0')}:$mm';
  }
}

/// 日常任务打卡记录
@HiveType(typeId: 5)
class DailyTaskLog {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String taskId;
  @HiveField(2)
  final String userId;
  @HiveField(3)
  final DateTime date; // YYYY-MM-DD
  @HiveField(4)
  final bool completed;
  @HiveField(5)
  final String? note;
  @HiveField(6)
  final DateTime? createdAt;

  DailyTaskLog({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.date,
    required this.completed,
    this.note,
    this.createdAt,
  });

  factory DailyTaskLog.fromJson(Map<String, dynamic> json) {
    return DailyTaskLog(
      id: json['id'] ?? '',
      taskId: json['taskId'] ?? '',
      userId: json['userId'] ?? '',
      date: DateTime.parse(json['date']).toLocal(),
      completed: json['completed'] ?? false,
      note: json['note'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'userId': userId,
      'date': date.toIso8601String(),
      'completed': completed,
      if (note != null) 'note': note,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}

/// 日常任务统计信息
@HiveType(typeId: 6)
class DailyTaskStats {
  @HiveField(0)
  final String taskId;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final int monthTotal;
  @HiveField(3)
  final int monthCompleted;
  @HiveField(4)
  final int completionRate; // 百分比 0-100
  @HiveField(5)
  final int consecutiveDays;

  DailyTaskStats({
    required this.taskId,
    required this.title,
    required this.monthTotal,
    required this.monthCompleted,
    required this.completionRate,
    required this.consecutiveDays,
  });

  factory DailyTaskStats.fromJson(Map<String, dynamic> json) {
    return DailyTaskStats(
      taskId: json['taskId'] ?? '',
      title: json['title'] ?? '',
      monthTotal: json['monthTotal'] ?? 0,
      monthCompleted: json['monthCompleted'] ?? 0,
      completionRate: json['completionRate'] ?? 0,
      consecutiveDays: json['consecutiveDays'] ?? 0,
    );
  }
}
