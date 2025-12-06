/// 重复规则数据模型
///
/// 用于创建和编辑重复日程时的数据传递
/// 后端接收 JSON 格式，存储为 RRULE 字符串
class RecurrenceRule {
  final String frequency; // DAILY, WEEKLY, MONTHLY, YEARLY
  final int interval; // 间隔（每隔多少天/周/月）
  final List<String>? byDay; // 周几重复（仅 WEEKLY 有效）
  final DateTime? until; // 截止日期
  final int? count; // 重复次数

  RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.byDay,
    this.until,
    this.count,
  });

  /// 从 JSON 创建（用于解析后端返回的数据）
  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    return RecurrenceRule(
      frequency: json['frequency'] as String,
      interval: json['interval'] as int? ?? 1,
      byDay: json['by_day'] != null
          ? List<String>.from(json['by_day'] as List)
          : null,
      until: json['until'] != null ? DateTime.parse(json['until']) : null,
      count: json['count'] as int?,
    );
  }

  /// 转换为 JSON（用于发送给后端）
  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'interval': interval,
      if (byDay != null && byDay!.isNotEmpty) 'by_day': byDay,
      if (until != null) 'until': until!.toIso8601String(),
      if (count != null) 'count': count,
    };
  }

  /// 解析后端返回的 RRULE 字符串（可选功能，用于展示）
  factory RecurrenceRule.fromRRule(String rrule) {
    final parts = rrule.split(';');
    String frequency = 'DAILY';
    int interval = 1;
    List<String>? byDay;
    DateTime? until;
    int? count;

    for (final part in parts) {
      final keyValue = part.split('=');
      if (keyValue.length != 2) continue;

      final key = keyValue[0];
      final value = keyValue[1];

      switch (key) {
        case 'FREQ':
          frequency = value;
          break;
        case 'INTERVAL':
          interval = int.tryParse(value) ?? 1;
          break;
        case 'BYDAY':
          byDay = value.split(',');
          break;
        case 'UNTIL':
          // RRULE 格式：20261231T000000Z
          try {
            final year = int.parse(value.substring(0, 4));
            final month = int.parse(value.substring(4, 6));
            final day = int.parse(value.substring(6, 8));
            until = DateTime(year, month, day);
          } catch (e) {
            // 解析失败，忽略
          }
          break;
        case 'COUNT':
          count = int.tryParse(value);
          break;
      }
    }

    return RecurrenceRule(
      frequency: frequency,
      interval: interval,
      byDay: byDay,
      until: until,
      count: count,
    );
  }

  /// 转换为用户友好的文本
  String toDisplayText() {
    final freqMap = {
      'DAILY': '每天',
      'WEEKLY': '每周',
      'MONTHLY': '每月',
      'YEARLY': '每年',
    };

    String text = freqMap[frequency] ?? frequency;

    if (interval > 1) {
      final unitMap = {
        'DAILY': '天',
        'WEEKLY': '周',
        'MONTHLY': '月',
        'YEARLY': '年',
      };
      text = '每 $interval ${unitMap[frequency] ?? '次'}';
    }

    // 添加周几信息
    if (byDay != null && byDay!.isNotEmpty) {
      final dayMap = {
        'SU': '周日',
        'MO': '周一',
        'TU': '周二',
        'WE': '周三',
        'TH': '周四',
        'FR': '周五',
        'SA': '周六',
      };
      final days = byDay!.map((d) => dayMap[d] ?? d).join('、');
      text += '（$days）';
    }

    // 添加截止条件
    if (until != null) {
      final date =
          '${until!.year}-${until!.month.toString().padLeft(2, '0')}-${until!.day.toString().padLeft(2, '0')}';
      text += '，截止到 $date';
    } else if (count != null) {
      text += '，共 $count 次';
    }

    return text;
  }

  /// 复制并修改
  RecurrenceRule copyWith({
    String? frequency,
    int? interval,
    List<String>? byDay,
    DateTime? until,
    int? count,
  }) {
    return RecurrenceRule(
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      byDay: byDay ?? this.byDay,
      until: until ?? this.until,
      count: count ?? this.count,
    );
  }
}

/// 重复结束条件
enum RecurrenceEndType {
  never, // 永不结束
  until, // 截止日期
  count, // 重复次数
}
