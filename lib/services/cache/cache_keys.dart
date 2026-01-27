/// 缓存键统一管理
///
/// 集中管理所有缓存的键名和过期时间配置，避免硬编码
class CacheKeys {
  // ==================== 日程相关 ====================

  /// 日程列表缓存键
  static const String schedules = 'schedules';

  /// 日程详情缓存键前缀（需拼接 ID）
  /// 使用方式: '${CacheKeys.scheduleDetail}$id'
  static const String scheduleDetail = 'schedule_detail_';

  /// 日程列表缓存过期时间: 1分钟
  static const Duration schedulesCacheMaxAge = Duration(minutes: 1);

  // ==================== 日常任务相关 ====================

  /// 日常任务列表缓存键
  static const String dailyTasks = 'daily_tasks';

  /// 日常任务详情缓存键前缀（需拼接 ID）
  static const String dailyTaskDetail = 'daily_task_detail_';

  /// 日常任务列表缓存过期时间: 1分钟
  static const Duration dailyTasksCacheMaxAge = Duration(minutes: 1);

  // ==================== 聊天相关 ====================

  /// 会话列表缓存键
  static const String conversations = 'conversations';

  /// 单个会话缓存键前缀（需拼接 ID）
  static const String conversationDetail = 'conversation_';

  /// 会话消息列表缓存键前缀（需拼接会话 ID）
  static const String conversationMessages = 'conversation_messages_';

  /// 会话列表缓存过期时间: 1分钟（聊天消息实时性要求高）
  static const Duration conversationsCacheMaxAge = Duration(minutes: 1);

  /// 会话详情缓存过期时间: 1分钟（保持与列表一致）
  static const Duration conversationDetailCacheMaxAge = Duration(minutes: 1);

  // ==================== 用户相关 ====================

  /// 用户信息缓存键
  static const String userProfile = 'user_profile';

  /// 用户配置缓存键
  static const String userConfig = 'user_config';

  /// 用户信息缓存过期时间: 1分钟（配置经常变化）
  static const Duration userProfileCacheMaxAge = Duration(minutes: 1);

  /// 用户配置缓存过期时间: 1分钟
  static const Duration userConfigCacheMaxAge = Duration(minutes: 1);

  // ==================== 同步队列相关 ====================

  /// 离线同步队列缓存键
  static const String syncQueue = 'sync_queue';

  /// 同步失败任务缓存键
  static const String syncFailedTasks = 'sync_failed_tasks';

  // ==================== 系统相关 ====================

  /// 缓存版本号键（用于数据迁移）
  static const String cacheVersion = 'cache_version';

  /// 当前缓存版本
  static const int currentCacheVersion = 1;

  /// 全局缓存清理周期：7天
  /// 超过此时间的缓存将被自动清理
  static const Duration globalCleanupMaxAge = Duration(days: 7);

  // ==================== 辅助方法 ====================

  /// 生成日程详情缓存键
  static String getScheduleDetailKey(String id) => '$scheduleDetail$id';

  /// 生成日常任务详情缓存键
  static String getDailyTaskDetailKey(String id) => '$dailyTaskDetail$id';

  /// 生成会话详情缓存键
  static String getConversationDetailKey(String id) => '$conversationDetail$id';

  /// 生成会话消息缓存键
  static String getConversationMessagesKey(String conversationId) =>
      '$conversationMessages$conversationId';

  /// 生成按月份的日程缓存键
  static String schedulesByMonth(int year, int month) {
    final monthStr = month.toString().padLeft(2, '0');
    return '${schedules}_${year}_$monthStr';
  }
}
