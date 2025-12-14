class UserConfig {
  final bool dailyScheduleDisplayInCalendar;
  final bool use24HourFormat;

  UserConfig({
    // 默认值为 false，保证应用不会因为 null 崩溃
    this.dailyScheduleDisplayInCalendar = false,
    this.use24HourFormat = false,
  });

  factory UserConfig.fromJson(Map<String, dynamic> json) {
    // 后端可能使用不同命名（snake_case / camelCase），统一兼容
    final dailyDisplayValue =
        json['dailyScheduleDisplayInCalendar'] ??
        json['daily_schedule_display_in_calendar'];
    final timeFormatValue =
        json['use24HourFormat'] ?? json['use_24_hour_format'];

    return UserConfig(
      // 使用 ?? 运算符，如果字段不存在或为 null，则回退到 false
      dailyScheduleDisplayInCalendar: dailyDisplayValue is bool
          ? dailyDisplayValue
          : false,
      use24HourFormat: timeFormatValue is bool ? timeFormatValue : false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dailyScheduleDisplayInCalendar': dailyScheduleDisplayInCalendar,
      'use24HourFormat': use24HourFormat,
    };
  }

  // 推荐：添加 copyWith 方法，方便只修改某个配置项
  UserConfig copyWith({
    bool? dailyScheduleDisplayInCalendar,
    bool? use24HourFormat,
  }) {
    return UserConfig(
      dailyScheduleDisplayInCalendar:
          dailyScheduleDisplayInCalendar ?? this.dailyScheduleDisplayInCalendar,
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
    );
  }
}
