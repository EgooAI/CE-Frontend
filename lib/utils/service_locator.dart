import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/cache/cache_service.dart';
import '../services/cache/hive_cache_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/schedule_service.dart';
import '../services/conversation_service.dart';
import '../models/schedule.dart';
import '../models/daily_task.dart';
import '../models/user.dart';
import '../models/user_config.dart';
import '../models/conversation.dart';

/// 全局服务定位器（依赖注入容器）
final GetIt locator = GetIt.instance;

/// 初始化所有服务
/// 
/// 调用时机：main() 函数中，runApp() 之前
/// 
/// 流程：
/// 1. 初始化 Hive（注册适配器）
/// 2. 注册缓存服务（单例）
/// 3. 注册 API 服务（单例）
/// 4. 注册业务服务（工厂模式）
Future<void> setupServiceLocator() async {
  try {
    print('[ServiceLocator] 开始初始化服务...');
    
    // ==================== 1. 初始化 Hive ====================
    await Hive.initFlutter();
    print('[ServiceLocator] Hive 初始化完成');
    
    // 注册所有模型的适配器
    Hive.registerAdapter(ScheduleAdapter());
    Hive.registerAdapter(DailyTaskAdapter());
    Hive.registerAdapter(DailyTaskLogAdapter());
    Hive.registerAdapter(DailyTaskStatsAdapter());
    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(UserConfigAdapter());
    Hive.registerAdapter(ConversationAdapter());
    Hive.registerAdapter(MessageAdapter());
    print('[ServiceLocator] Hive 适配器注册完成');
    
    // ==================== 2. 注册缓存服务（单例）====================
    final cacheService = HiveCacheService();
    await cacheService.init();
    locator.registerSingleton<CacheService>(cacheService);
    print('[ServiceLocator] CacheService 注册完成');
    
    // ==================== 3. 注册 API 服务（单例）====================
    locator.registerSingleton<ApiClient>(ApiClient());
    print('[ServiceLocator] ApiClient 注册完成');
    
    locator.registerSingleton<AuthService>(AuthService());
    print('[ServiceLocator] AuthService 注册完成');
    
    // ==================== 4. 注册业务服务（工厂模式）====================
    // 使用工厂模式，每次调用 get<ScheduleService>() 都返回新实例
    locator.registerFactory<ScheduleService>(() => ScheduleService());
    locator.registerFactory<ConversationService>(() => ConversationService());
    print('[ServiceLocator] 业务服务注册完成');
    
    print('[ServiceLocator] ✅ 所有服务初始化完成！');
  } catch (e) {
    print('[ServiceLocator] ❌ 服务初始化失败: $e');
    rethrow;
  }
}

/// 清理所有服务（应用退出时调用）
Future<void> disposeServices() async {
  try {
    // 关闭 Hive
    final cacheService = locator<CacheService>();
    if (cacheService is HiveCacheService) {
      await cacheService.close();
    }
    await Hive.close();
    
    // 重置 GetIt
    await locator.reset();
    print('[ServiceLocator] 所有服务已清理');
  } catch (e) {
    print('[ServiceLocator] 清理服务失败: $e');
  }
}
