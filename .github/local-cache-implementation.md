# 本地缓存功能实施计划

**创建日期：** 2025-12-15  
**目标：** 为 CE-Frontend 添加完整的本地缓存能力，支持离线使用  
**预计工期：** 2-3 周  
**技术栈：** Flutter + Hive + Repository 模式  
**当前状态：** 🚀 准备开始

---

## 📊 项目概览

### 实施目标
- ✅ 应用支持离线查看历史数据
- ✅ 断网时创建/编辑数据，联网后自动同步
- ✅ 页面加载速度提升（缓存秒开）
- ✅ 减少网络请求和服务器压力
- ✅ 提升用户体验和应用稳定性

### 技术方案
- **缓存引擎：** Hive（轻量级 NoSQL）
- **架构模式：** Repository 模式（数据访问层）
- **依赖注入：** GetIt（服务定位器）
- **缓存策略：** 网络优先 + 缓存降级
- **离线编辑：** SyncQueue（同步队列）

---

## 🎯 里程碑规划

| 阶段 | 时间 | 进度 | 关键产出 |
|------|------|------|----------|
| **Phase 1: 基础设施** | Week 1 | 🔲 0% | Hive 集成、Schedule 缓存 |
| **Phase 2: 功能扩展** | Week 2 | 🔲 0% | 全页面缓存支持 |
| **Phase 3: 离线队列** | Week 3 | 🔲 0% | 离线编辑、自动同步 |

---

## 📝 详细任务清单

### Phase 1: 基础设施搭建（Week 1）

#### Task 1.1: 环境准备和依赖集成 ⏱️ 2h
**状态：** 🔲 待开始  
**负责人：** -  
**优先级：** P0（最高）

**步骤：**
1. 修改 `pubspec.yaml` 添加依赖：
   ```yaml
   dependencies:
     hive: ^2.2.3
     hive_flutter: ^1.1.0
     get_it: ^7.6.4
   
   dev_dependencies:
     hive_generator: ^2.0.1
     build_runner: ^2.4.6
   ```

2. 运行安装命令：
   ```bash
   flutter pub get
   ```

3. 创建目录结构：
   ```
   lib/
   ├── services/
   │   └── cache/
   │       ├── cache_service.dart
   │       ├── hive_cache_service.dart
   │       └── cache_keys.dart
   ├── repositories/
   │   ├── schedule_repository.dart
   │   ├── daily_task_repository.dart
   │   ├── user_repository.dart
   │   └── conversation_repository.dart
   └── utils/
       └── service_locator.dart
   ```

**验收标准：**
- [ ] 依赖安装成功，无冲突
- [ ] 文件结构创建完成
- [ ] `flutter analyze` 无错误

**潜在问题：**
- ❌ **Hive 版本冲突**
  - 解决：锁定版本号，不使用 ^
- ❌ **文件权限问题（Windows）**
  - 解决：以管理员运行 VS Code

---

#### Task 1.2: 实现 CacheService 基类 ⏱️ 3h
**状态：** 🔲 待开始  
**依赖：** Task 1.1

**实现文件：** `lib/services/cache/cache_service.dart`

**接口定义：**
```dart
abstract class CacheService {
  /// 初始化缓存
  Future<void> init();
  
  /// 获取单个对象
  Future<T?> get<T>(String key);
  
  /// 存储单个对象
  Future<void> set<T>(String key, T value);
  
  /// 删除缓存
  Future<void> delete(String key);
  
  /// 清空所有缓存
  Future<void> clear();
  
  /// 获取列表
  Future<List<T>> getList<T>(String key);
  
  /// 存储列表
  Future<void> setList<T>(String key, List<T> items);
  
  /// 检查缓存是否过期
  Future<bool> isExpired(String key, Duration maxAge);
  
  /// 获取缓存时间戳
  Future<DateTime?> getTimestamp(String key);
  
  /// 设置缓存时间戳
  Future<void> setTimestamp(String key, DateTime timestamp);
}
```

**验收标准：**
- [ ] 所有方法定义完整
- [ ] 类型安全（泛型支持）
- [ ] 文档注释清晰

---

#### Task 1.3: Hive 适配器生成 ⏱️ 4h
**状态：** 🔲 待开始  
**依赖：** Task 1.2

**改动文件：**

1. **lib/models/schedule.dart**
   ```dart
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
     final DateTime? endTime;
     
     @HiveField(6)
     final bool allDay;
     
     @HiveField(7)
     final String? location;
     
     @HiveField(8)
     final String status;
     
     @HiveField(9)
     final String? type;
     
     @HiveField(10)
     final String? priority;
     
     @HiveField(11)
     final String? recurrence;
     
     @HiveField(12)
     final String? participants;
     
     @HiveField(13)
     final String? notes;
     
     @HiveField(14)
     final String? attachments;
     
     @HiveField(15)
     final String? daomengId;
     
     @HiveField(16)
     final int? remindBefore;
     
     @HiveField(17)
     final List<dynamic>? reminders;
     
     @HiveField(18)
     final String? parentId;
     
     @HiveField(19)
     final int? iterationIndex;
     
     @HiveField(20)
     final DateTime? createdAt;
     
     @HiveField(21)
     final DateTime? updatedAt;
     
     @HiveField(22)
     final bool isDaily;
     
     // 构造函数保持不变
     Schedule({...});
   }
   ```

2. **lib/models/daily_task.dart** - typeId: 1
3. **lib/models/user.dart** - typeId: 2
4. **lib/models/user_config.dart** - typeId: 3
5. **lib/models/conversation.dart** - typeId: 4

**代码生成命令：**
```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

**验收标准：**
- [ ] 所有模型生成 `.g.dart` 文件
- [ ] 无生成错误
- [ ] 可序列化/反序列化测试通过

**潜在问题：**
- ❌ **typeId 冲突**
  - 解决：统一管理 typeId（创建 `cache_type_ids.dart`）
- ❌ **DateTime 序列化问题**
  - 解决：Hive 原生支持 DateTime
- ❌ **嵌套对象序列化**
  - 解决：reminders 等动态类型使用 JSON 字符串存储

---

#### Task 1.4: HiveCacheService 实现 ⏱️ 4h
**状态：** 🔲 待开始  
**依赖：** Task 1.3

**实现文件：** `lib/services/cache/hive_cache_service.dart`

**核心代码：**
```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'cache_service.dart';
import '../../models/schedule.dart';
import '../../models/daily_task.dart';
import '../../models/user.dart';
import '../../models/user_config.dart';
import '../../models/conversation.dart';

class HiveCacheService implements CacheService {
  late Box _box;
  static const String _boxName = 'app_cache';
  static const String _timestampSuffix = '_timestamp';

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    
    // 注册适配器
    Hive.registerAdapter(ScheduleAdapter());
    Hive.registerAdapter(DailyTaskAdapter());
    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(UserConfigAdapter());
    Hive.registerAdapter(ConversationAdapter());
    
    _box = await Hive.openBox(_boxName);
  }

  @override
  Future<T?> get<T>(String key) async {
    try {
      return _box.get(key) as T?;
    } catch (e) {
      print('缓存读取失败: $key, 错误: $e');
      return null;
    }
  }

  @override
  Future<void> set<T>(String key, T value) async {
    try {
      await _box.put(key, value);
      await setTimestamp(key, DateTime.now());
    } catch (e) {
      print('缓存写入失败: $key, 错误: $e');
    }
  }

  @override
  Future<void> delete(String key) async {
    await _box.delete(key);
    await _box.delete('$key$_timestampSuffix');
  }

  @override
  Future<void> clear() async {
    await _box.clear();
  }

  @override
  Future<List<T>> getList<T>(String key) async {
    try {
      final list = _box.get(key);
      if (list == null) return [];
      return List<T>.from(list);
    } catch (e) {
      print('缓存列表读取失败: $key, 错误: $e');
      return [];
    }
  }

  @override
  Future<void> setList<T>(String key, List<T> items) async {
    try {
      await _box.put(key, items);
      await setTimestamp(key, DateTime.now());
    } catch (e) {
      print('缓存列表写入失败: $key, 错误: $e');
    }
  }

  @override
  Future<bool> isExpired(String key, Duration maxAge) async {
    final timestamp = await getTimestamp(key);
    if (timestamp == null) return true;
    
    return DateTime.now().difference(timestamp) > maxAge;
  }

  @override
  Future<DateTime?> getTimestamp(String key) async {
    final timestamp = _box.get('$key$_timestampSuffix') as int?;
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  @override
  Future<void> setTimestamp(String key, DateTime timestamp) async {
    await _box.put('$key$_timestampSuffix', timestamp.millisecondsSinceEpoch);
  }
}
```

**验收标准：**
- [ ] 所有方法实现完成
- [ ] 错误处理完善
- [ ] 时间戳管理正常

**潜在问题：**
- ❌ **Box 未初始化错误**
  - 解决：添加 `_ensureInitialized()` 检查
- ❌ **并发写入冲突**
  - 解决：添加锁机制（使用 `synchronized` 包）

---

#### Task 1.5: CacheKeys 常量管理 ⏱️ 1h
**状态：** 🔲 待开始

**实现文件：** `lib/services/cache/cache_keys.dart`

```dart
class CacheKeys {
  // 日程相关
  static const schedules = 'schedules';
  static const scheduleDetail = 'schedule_detail_'; // + id
  
  // 日常任务
  static const dailyTasks = 'daily_tasks';
  static const dailyTaskDetail = 'daily_task_detail_'; // + id
  
  // 聊天
  static const conversations = 'conversations';
  static const conversationDetail = 'conversation_'; // + id
  static const conversationMessages = 'conversation_messages_'; // + id
  
  // 用户
  static const userProfile = 'user_profile';
  static const userConfig = 'user_config';
  
  // 同步队列
  static const syncQueue = 'sync_queue';
  
  // 缓存过期时间配置
  static const Duration schedulesCacheMaxAge = Duration(minutes: 15);
  static const Duration dailyTasksCacheMaxAge = Duration(minutes: 10);
  static const Duration userProfileCacheMaxAge = Duration(minutes: 5);
  static const Duration conversationsCacheMaxAge = Duration(minutes: 5);
}
```

---

#### Task 1.6: ServiceLocator 依赖注入 ⏱️ 2h
**状态：** 🔲 待开始  
**依赖：** Task 1.4

**实现文件：** `lib/utils/service_locator.dart`

```dart
import 'package:get_it/get_it.dart';
import '../services/cache/cache_service.dart';
import '../services/cache/hive_cache_service.dart';
import '../services/schedule_service.dart';
import '../services/daily_task_service.dart';
import '../services/auth_service.dart';
import '../services/conversation_service.dart';
import '../repositories/schedule_repository.dart';
import '../repositories/daily_task_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/conversation_repository.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // 1. 缓存服务（单例，优先初始化）
  final cache = HiveCacheService();
  await cache.init();
  getIt.registerSingleton<CacheService>(cache);
  
  // 2. API 服务（懒加载单例）
  getIt.registerLazySingleton(() => ScheduleService());
  getIt.registerLazySingleton(() => DailyTaskService());
  getIt.registerLazySingleton(() => AuthService());
  getIt.registerLazySingleton(() => ConversationService());
  
  // 3. Repository（依赖注入）
  getIt.registerLazySingleton(() => ScheduleRepository(
    getIt<ScheduleService>(),
    getIt<CacheService>(),
  ));
  
  getIt.registerLazySingleton(() => DailyTaskRepository(
    getIt<DailyTaskService>(),
    getIt<CacheService>(),
  ));
  
  getIt.registerLazySingleton(() => UserRepository(
    getIt<AuthService>(),
    getIt<CacheService>(),
  ));
  
  getIt.registerLazySingleton(() => ConversationRepository(
    getIt<ConversationService>(),
    getIt<CacheService>(),
  ));
}
```

**main.dart 改动：**
```dart
import 'utils/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化依赖注入
  await setupServiceLocator();
  
  // 原有初始化逻辑...
  runApp(const MyApp());
}
```

**验收标准：**
- [ ] 所有服务注册成功
- [ ] 应用启动无错误
- [ ] getIt 可正常获取服务

---

#### Task 1.7: ScheduleRepository 实现 ⏱️ 6h
**状态：** 🔲 待开始  
**依赖：** Task 1.6  
**优先级：** P0

**实现文件：** `lib/repositories/schedule_repository.dart`

**核心代码：**
```dart
import '../models/schedule.dart';
import '../services/schedule_service.dart';
import '../services/cache/cache_service.dart';
import '../services/cache/cache_keys.dart';

class ScheduleRepository {
  final ScheduleService _apiService;
  final CacheService _cache;
  
  ScheduleRepository(this._apiService, this._cache);
  
  /// 获取日程列表
  /// [forceRefresh] 强制刷新，跳过缓存
  Future<List<Schedule>> getSchedules({bool forceRefresh = false}) async {
    final cacheKey = CacheKeys.schedules;
    
    // 1. 检查缓存是否过期
    final expired = await _cache.isExpired(
      cacheKey,
      CacheKeys.schedulesCacheMaxAge,
    );
    
    // 2. 如果未过期且不强制刷新，返回缓存
    if (!expired && !forceRefresh) {
      final cached = await _cache.getList<Schedule>(cacheKey);
      if (cached.isNotEmpty) {
        print('📦 从缓存加载日程: ${cached.length} 条');
        return cached;
      }
    }
    
    // 3. 尝试网络请求
    try {
      print('🌐 从网络加载日程...');
      final schedules = await _apiService.getSchedules();
      
      // 4. 更新缓存
      await _cache.setList(cacheKey, schedules);
      print('✅ 日程已缓存: ${schedules.length} 条');
      
      return schedules;
    } catch (e) {
      // 5. 网络失败，降级读取缓存
      print('❌ 网络请求失败: $e');
      final cached = await _cache.getList<Schedule>(cacheKey);
      
      if (cached.isEmpty) {
        throw Exception('无网络连接且无缓存数据');
      }
      
      print('📦 降级使用缓存: ${cached.length} 条');
      return cached;
    }
  }
  
  /// 创建日程
  Future<Schedule> createSchedule(Map<String, dynamic> data) async {
    try {
      final schedule = await _apiService.createSchedule(data);
      
      // 创建成功后清除列表缓存，强制下次重新获取
      await _cache.delete(CacheKeys.schedules);
      print('✅ 日程已创建，缓存已清除');
      
      return schedule;
    } catch (e) {
      // TODO: Phase 3 加入同步队列
      print('❌ 创建日程失败: $e');
      rethrow;
    }
  }
  
  /// 更新日程
  Future<Schedule> updateSchedule(String id, Map<String, dynamic> data) async {
    try {
      final schedule = await _apiService.updateSchedule(id, data);
      
      // 更新成功后清除相关缓存
      await _cache.delete(CacheKeys.schedules);
      await _cache.delete('${CacheKeys.scheduleDetail}$id');
      print('✅ 日程已更新，缓存已清除');
      
      return schedule;
    } catch (e) {
      print('❌ 更新日程失败: $e');
      rethrow;
    }
  }
  
  /// 删除日程
  Future<void> deleteSchedule(String id) async {
    try {
      await _apiService.deleteSchedule(id);
      
      // 删除成功后清除相关缓存
      await _cache.delete(CacheKeys.schedules);
      await _cache.delete('${CacheKeys.scheduleDetail}$id');
      print('✅ 日程已删除，缓存已清除');
    } catch (e) {
      print('❌ 删除日程失败: $e');
      rethrow;
    }
  }
  
  /// 批量删除日程
  Future<void> batchDeleteSchedules(List<String> ids, String action) async {
    try {
      await _apiService.batchDeleteSchedules(ids, action);
      
      // 清除所有相关缓存
      await _cache.delete(CacheKeys.schedules);
      for (final id in ids) {
        await _cache.delete('${CacheKeys.scheduleDetail}$id');
      }
      print('✅ 批量删除成功，缓存已清除');
    } catch (e) {
      print('❌ 批量删除失败: $e');
      rethrow;
    }
  }
  
  /// 更新日程状态
  Future<void> updateScheduleStatus(String id, String status) async {
    try {
      await _apiService.updateScheduleStatus(id, status);
      
      // 清除相关缓存
      await _cache.delete(CacheKeys.schedules);
      await _cache.delete('${CacheKeys.scheduleDetail}$id');
      print('✅ 日程状态已更新');
    } catch (e) {
      print('❌ 更新状态失败: $e');
      rethrow;
    }
  }
}
```

**验收标准：**
- [ ] 所有方法实现完成
- [ ] 缓存逻辑正确
- [ ] 错误处理完善
- [ ] 日志输出清晰

---

#### Task 1.8: CalendarPage 迁移 ⏱️ 4h
**状态：** 🔲 待开始  
**依赖：** Task 1.7

**改动文件：** `lib/pages/calendar_page.dart`

**改动内容：**

1. 注入 Repository：
```dart
import '../../utils/service_locator.dart';
import '../../repositories/schedule_repository.dart';

class _CalendarPageState extends State<CalendarPage> {
  final _scheduleRepository = getIt<ScheduleRepository>();
  bool _isOffline = false; // 新增：离线标识
  
  // 移除旧的 _scheduleService
}
```

2. 修改 `_loadSchedules()`:
```dart
Future<void> _loadSchedules({bool forceRefresh = false}) async {
  setState(() => _isLoading = true);
  
  try {
    // 使用 Repository 替代 Service
    final allSchedules = await _scheduleRepository.getSchedules(
      forceRefresh: forceRefresh,
    );
    
    final currentUser = await AuthService().getProfile();
    final schedules = allSchedules.where((s) => s.type != 'daily').toList();
    
    setState(() {
      _scheduleMap = _buildScheduleMap(schedules);
      _isLoading = false;
      _isOffline = false; // 在线
    });
  } catch (e) {
    setState(() {
      _isLoading = false;
      _isOffline = e.toString().contains('无网络连接'); // 离线
    });
    
    // 显示提示
    if (mounted && _isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.cloud_off, color: Colors.white),
              SizedBox(width: 8),
              Text('离线模式：显示缓存数据'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
```

3. 添加离线标识 UI：
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('日历'),
      actions: [
        // 离线标识
        if (_isOffline)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: const [
                Icon(Icons.cloud_off, size: 18),
                SizedBox(width: 4),
                Text('离线', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        // 原有按钮...
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => _loadSchedules(forceRefresh: true),
      child: // 原有内容...
    ),
  );
}
```

4. 修改其他调用 Service 的地方：
```dart
// 创建日程
await _scheduleRepository.createSchedule(schedule.toJson());

// 更新日程
await _scheduleRepository.updateSchedule(id, updatedSchedule.toJson());

// 删除日程
await _scheduleRepository.deleteSchedule(id);

// 批量删除
await _scheduleRepository.batchDeleteSchedules(ids, action);

// 更新状态
await _scheduleRepository.updateScheduleStatus(schedule.id, newStatus);
```

**验收标准：**
- [ ] 页面正常加载
- [ ] 在线显示最新数据
- [ ] 断网显示缓存数据
- [ ] 离线标识显示正确
- [ ] 下拉刷新强制更新

**测试场景：**
1. ✅ 在线首次打开 → 加载网络数据 → 写入缓存
2. ✅ 在线再次打开 → 直接显示缓存 → 后台更新
3. ✅ 断网打开 → 显示缓存 → 显示离线提示
4. ✅ 断网下拉刷新 → 显示失败提示 → 保留缓存
5. ✅ 重新联网 → 下拉刷新 → 更新成功

---

### Phase 2: 功能扩展（Week 2）

#### Task 2.1: DailyTaskRepository 实现 ⏱️ 4h
**状态：** 🔲 待开始

**实现文件：** `lib/repositories/daily_task_repository.dart`

**核心方法：**
- `getDailyTasks({String? status, bool forceRefresh = false})`
- `createDailyTask()`
- `updateDailyTask(String id, Map<String, dynamic> data)`
- `deleteDailyTask(String id)`
- `toggleDailyTaskStatus(String id, String status)`

**缓存策略：**
- 过期时间：10 分钟
- 状态变更立即失效缓存
- 支持按状态筛选缓存

---

#### Task 2.2: DailyPage 迁移 ⏱️ 3h
**状态：** 🔲 待开始

改动类似 CalendarPage：
- 注入 DailyTaskRepository
- 添加离线标识
- 错误处理优化

---

#### Task 2.3: UserRepository 实现 ⏱️ 3h
**状态：** 🔲 待开始

**实现文件：** `lib/repositories/user_repository.dart`

**核心方法：**
- `getProfile({bool forceRefresh = false})`
- `updateProfile(User user)`
- `updateConfig(UserConfig config)`

**缓存策略：**
- 过期时间：5 分钟（配置经常变）
- 更新后立即刷新缓存

---

#### Task 2.4: ProfilePage 迁移 ⏱️ 2h
**状态：** 🔲 待开始

---

#### Task 2.5: ConversationRepository 实现 ⏱️ 4h
**状态：** 🔲 待开始

**核心方法：**
- `getConversations({bool forceRefresh = false})`
- `getConversationById(String id, {bool forceRefresh = false})`
- `sendMessage(String conversationId, String message)`
- `createConversation(String title)`

**缓存策略：**
- 会话列表：缓存 5 分钟
- 会话详情：按 ID 单独缓存
- 新消息：追加到缓存

---

#### Task 2.6: ChatPage 迁移 ⏱️ 4h
**状态：** 🔲 待开始

特殊处理：
- SSE 消息流追加到缓存
- 离线显示历史会话

---

#### Task 2.7: TaskPage 迁移 ⏱️ 2h
**状态：** 🔲 待开始

使用 ScheduleRepository（已实现），只需添加离线标识。

---

### Phase 3: 离线队列和优化（Week 3）

#### Task 3.1: SyncTask 数据模型 ⏱️ 2h
**状态：** 🔲 待开始

**实现文件：** `lib/models/sync_task.dart`

```dart
import 'package:hive/hive.dart';

part 'sync_task.g.dart';

@HiveType(typeId: 10)
class SyncTask {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String type; // 'create', 'update', 'delete'
  
  @HiveField(2)
  final String resource; // 'schedule', 'daily_task', 'conversation'
  
  @HiveField(3)
  final Map<String, dynamic> data;
  
  @HiveField(4)
  final DateTime createdAt;
  
  @HiveField(5)
  final String status; // 'pending', 'syncing', 'failed'
  
  @HiveField(6)
  final int retryCount;
  
  @HiveField(7)
  final String? errorMessage;
  
  SyncTask({
    required this.id,
    required this.type,
    required this.resource,
    required this.data,
    required this.createdAt,
    this.status = 'pending',
    this.retryCount = 0,
    this.errorMessage,
  });
  
  SyncTask copyWith({
    String? status,
    int? retryCount,
    String? errorMessage,
  }) {
    return SyncTask(
      id: id,
      type: type,
      resource: resource,
      data: data,
      createdAt: createdAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
```

---

#### Task 3.2: SyncQueueService 实现 ⏱️ 6h
**状态：** 🔲 待开始

**实现文件：** `lib/services/sync_queue_service.dart`

**核心功能：**
- 添加待同步任务
- 批量处理队列
- 重试失败任务
- 冲突检测

---

#### Task 3.3: Repository 集成离线队列 ⏱️ 4h
**状态：** 🔲 待开始

修改所有 Repository 的写操作：
```dart
Future<Schedule> createSchedule(Map<String, dynamic> data) async {
  try {
    return await _apiService.createSchedule(data);
  } catch (e) {
    // 网络失败 → 加入队列
    await _syncQueue.addTask(SyncTask(
      id: Uuid().v4(),
      type: 'create',
      resource: 'schedule',
      data: data,
      createdAt: DateTime.now(),
    ));
    throw OfflineException('已保存到离线队列，将在联网后自动同步');
  }
}
```

---

#### Task 3.4: 后台同步任务 ⏱️ 4h
**状态：** 🔲 待开始

**实现文件：** `lib/services/background_sync_service.dart`

功能：
- 启动后台定时器（每 30 秒）
- 检测网络连接
- 自动执行同步队列
- 显示同步通知

---

#### Task 3.5: 缓存管理页面 ⏱️ 4h
**状态：** 🔲 待开始

**实现文件：** `lib/pages/cache_management_page.dart`

功能：
- 显示缓存大小
- 清空缓存
- 查看待同步队列
- 手动同步按钮

---

#### Task 3.6: 性能优化 ⏱️ 4h
**状态：** 🔲 待开始

优化项：
- 大列表分页缓存
- 缓存预热（登录后）
- 过期缓存自动清理
- 缓存压缩

---

#### Task 3.7: 全面测试 ⏱️ 6h
**状态：** 🔲 待开始

测试场景清单：
- [ ] 在线首次加载
- [ ] 缓存命中加载
- [ ] 断网读取缓存
- [ ] 断网创建数据
- [ ] 重新联网自动同步
- [ ] 同步冲突处理
- [ ] 缓存过期刷新
- [ ] 多端数据同步
- [ ] 缓存清空和恢复

---

## ⚠️ 潜在问题和解决方案

### 问题 1: Hive 数据迁移导致数据丢失
**风险等级：** 🔴 高  
**影响范围：** 用户数据安全

**解决方案：**
1. **版本号管理**
   ```dart
   class CacheVersion {
     static const int current = 1;
     static const String key = 'cache_version';
   }
   
   // 初始化时检查版本
   Future<void> init() async {
     await Hive.initFlutter();
     
     final version = _box.get(CacheVersion.key, defaultValue: 0);
     if (version < CacheVersion.current) {
       await _migrateCache(version, CacheVersion.current);
     }
   }
   ```

2. **迁移脚本**
   ```dart
   Future<void> _migrateCache(int from, int to) async {
     if (from == 0 && to == 1) {
       // 版本 0 → 1 迁移逻辑
       await _migrateV0ToV1();
     }
     await _box.put(CacheVersion.key, to);
   }
   ```

3. **备份机制**
   ```dart
   Future<void> backupCache() async {
     final backupBox = await Hive.openBox('cache_backup');
     await backupBox.putAll(_box.toMap());
   }
   ```

---

### 问题 2: 并发写入导致数据冲突
**风险等级：** 🟡 中  
**影响范围：** 缓存一致性

**解决方案：**
1. **使用 synchronized 包**
   ```yaml
   dependencies:
     synchronized: ^3.1.0
   ```

2. **添加锁机制**
   ```dart
   import 'package:synchronized/synchronized.dart';
   
   class HiveCacheService {
     final _lock = Lock();
     
     @override
     Future<void> set<T>(String key, T value) async {
       await _lock.synchronized(() async {
         await _box.put(key, value);
       });
     }
   }
   ```

---

### 问题 3: 缓存占用空间过大
**风险等级：** 🟡 中  
**影响范围：** 设备存储

**解决方案：**
1. **限制缓存数量**
   ```dart
   Future<void> setList<T>(String key, List<T> items) async {
     const maxCacheSize = 500; // 最多缓存 500 条
     final limitedItems = items.take(maxCacheSize).toList();
     await _box.put(key, limitedItems);
   }
   ```

2. **定期清理过期缓存**
   ```dart
   Future<void> cleanExpiredCache() async {
     final now = DateTime.now();
     final keysToDelete = <String>[];
     
     for (final key in _box.keys) {
       if (key.endsWith('_timestamp')) continue;
       
       final timestamp = await getTimestamp(key);
       if (timestamp != null && now.difference(timestamp).inDays > 7) {
         keysToDelete.add(key);
       }
     }
     
     await _box.deleteAll(keysToDelete);
   }
   ```

3. **缓存大小监控**
   ```dart
   Future<int> getCacheSize() async {
     return _box.length;
   }
   
   Future<double> getCacheSizeMB() async {
     // Hive 提供的磁盘占用 API
     final file = File(Hive.box(_boxName).path!);
     final size = await file.length();
     return size / (1024 * 1024); // MB
   }
   ```

---

### 问题 4: 离线队列同步失败
**风险等级：** 🟡 中  
**影响范围：** 数据一致性

**解决方案：**
1. **重试机制**
   ```dart
   Future<void> _processTask(SyncTask task) async {
     const maxRetries = 3;
     
     if (task.retryCount >= maxRetries) {
       // 标记为失败，需用户手动处理
       await _updateTaskStatus(task.id, 'failed');
       return;
     }
     
     try {
       await _executeTask(task);
       await _removeTask(task.id);
     } catch (e) {
       // 增加重试次数
       await _updateTask(task.copyWith(
         retryCount: task.retryCount + 1,
         errorMessage: e.toString(),
       ));
     }
   }
   ```

2. **冲突检测**
   ```dart
   Future<void> _executeTask(SyncTask task) async {
     if (task.type == 'update') {
       // 先获取服务器最新数据
       final serverData = await _getServerData(task);
       
       // 检查是否有冲突
       if (_hasConflict(task.data, serverData)) {
         // 服务器优先策略
         await _updateTask(task.copyWith(
           status: 'conflict',
           errorMessage: '数据已被其他设备修改',
         ));
         return;
       }
     }
     
     // 执行同步
     await _apiService.execute(task);
   }
   ```

---

### 问题 5: DateTime 序列化问题
**风险等级：** 🟢 低  
**影响范围：** 数据正确性

**解决方案：**
Hive 原生支持 DateTime，无需特殊处理。但需注意时区：
```dart
// 存储时统一为 UTC
@HiveField(4)
final DateTime startTime;

Schedule({required DateTime startTime})
  : startTime = startTime.toUtc();

// 读取时转为本地时间
factory Schedule.fromHive(Schedule cached) {
  return cached.copyWith(
    startTime: cached.startTime.toLocal(),
    endTime: cached.endTime?.toLocal(),
  );
}
```

---

### 问题 6: 嵌套对象（reminders）序列化
**风险等级：** 🟡 中  
**影响范围：** 数据完整性

**解决方案：**
```dart
import 'dart:convert';

@HiveField(17)
final String? remindersJson; // 改为存储 JSON 字符串

// 序列化
String? _serializeReminders(List<dynamic>? reminders) {
  if (reminders == null) return null;
  return jsonEncode(reminders);
}

// 反序列化
List<dynamic>? _deserializeReminders(String? json) {
  if (json == null) return null;
  return jsonDecode(json);
}
```

---

## 📊 进度追踪

### 当前状态
- **总进度：** 0/28 任务完成
- **Phase 1：** 🔲 0/8 (0%)
- **Phase 2：** 🔲 0/7 (0%)
- **Phase 3：** 🔲 0/7 (0%)

### 下一步行动
✅ **立即开始：** Task 1.1 - 环境准备和依赖集成

---

## 🎯 验收标准

### Phase 1 验收（Week 1 结束）
- [ ] Hive 初始化成功
- [ ] Schedule 数据可缓存
- [ ] CalendarPage 离线可用
- [ ] 断网测试通过
- [ ] 在线/离线切换正常

### Phase 2 验收（Week 2 结束）
- [ ] 所有页面支持缓存
- [ ] 离线模式 UI 完善
- [ ] 用户配置缓存生效
- [ ] 缓存过期策略正常

### Phase 3 验收（Week 3 结束）
- [ ] 离线队列运行正常
- [ ] 自动同步无误
- [ ] 冲突处理正确
- [ ] 所有测试通过
- [ ] 性能指标达标

---

## 📈 成功指标

| 指标 | 目标 | 当前 |
|------|------|------|
| **应用启动速度** | < 1秒 | - |
| **页面加载速度** | < 200ms（缓存） | - |
| **离线可用率** | 100%（有缓存） | - |
| **同步成功率** | > 95% | - |
| **缓存命中率** | > 70% | - |
| **缓存空间占用** | < 50MB | - |

---

## 📚 参考文档

- [Hive 官方文档](https://docs.hivedb.dev/)
- [GetIt 使用指南](https://pub.dev/packages/get_it)
- [Flutter 离线优先架构](https://docs.flutter.dev/cookbook/persistence)

---

**最后更新：** 2025-12-15  
**文档版本：** v1.0  
**状态：** ✅ 就绪，等待开始实施
