class UserConfig {
  final bool dailyScheduleDisplayInCalendar;

  UserConfig({
    // 默认值为 false，保证应用不会因为 null 崩溃
    this.dailyScheduleDisplayInCalendar = false,
  });

  factory UserConfig.fromJson(Map<String, dynamic> json) {
    return UserConfig(
      // 使用 ?? 运算符，如果字段不存在或为 null，则回退到 false
      dailyScheduleDisplayInCalendar:
          json['dailyScheduleDisplayInCalendar'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'dailyScheduleDisplayInCalendar': dailyScheduleDisplayInCalendar};
  }

  // 推荐：添加 copyWith 方法，方便只修改某个配置项
  UserConfig copyWith({bool? dailyScheduleDisplayInCalendar}) {
    return UserConfig(
      dailyScheduleDisplayInCalendar:
          dailyScheduleDisplayInCalendar ?? this.dailyScheduleDisplayInCalendar,
    );
  }
}
