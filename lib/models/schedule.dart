class Schedule {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
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
    required this.endTime,
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
    return Schedule(
      id: json['id'],
      userId: json['userId'],
      title: json['title'],
      description: json['description'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
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
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
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
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
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
    final endStr =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
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
