class Schedule {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime? endTime; // 结束时间可选
  final bool allDay;
  final String? location;
  final String status; // pending/in_progress/completed/cancelled
  final String? type; // meeting/task/event
  final String? priority; // high/medium/low
  final String? recurrence;
  final String? participants; // JSON string
  final String? notes;
  final String? attachments; // JSON string
  final String? daomengId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.createdAt,
    this.updatedAt,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    // DateTime.parse() 会将带时区的时间转换为 UTC
    // 需要使用 .toLocal() 转换回本地时区，保持正确的日期
    return Schedule(
      id: json['id'],
      userId: json['userId'],
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
      recurrence: json['recurrence'],
      participants: json['participants'],
      notes: json['notes'],
      attachments: json['attachments'],
      daomengId: json['daomengId'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt']).toLocal()
          : null,
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
      'recurrence': recurrence,
      'participants': participants,
      'notes': notes,
      'attachments': attachments,
      'daomengId': daomengId,
      'createdAt': createdAt != null ? formatDateTime(createdAt!) : null,
      'updatedAt': updatedAt != null ? formatDateTime(updatedAt!) : null,
    };
  }

  // 判断是否应该显示红点（未完成的日程）
  bool shouldShowMarker() {
    return status != 'completed' && status != 'cancelled';
  }

  // 格式化时间显示
  String getTimeDisplay() {
    if (allDay) {
      return '全天';
    }
    final startStr =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    if (endTime == null) {
      return startStr;
    }
    final endStr =
        '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';
    return '$startStr-$endStr';
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
}
