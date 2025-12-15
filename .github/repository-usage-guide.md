# 仓储层使用指南

本文档说明如何在 CE-Frontend 中使用新的仓储架构进行数据操作。

---

## 快速开始

### 1. 在页面中使用仓储

```dart
import 'package:get_it/get_it.dart';
import '../repositories/schedule_repository.dart';

class MyPage extends StatefulWidget {
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  late ScheduleRepository _repo;

  @override
  void initState() {
    super.initState();
    // 方式 1: 直接创建实例 (不推荐用于单例)
    // _repo = ScheduleRepository();
    
    // 方式 2: 从 GetIt 获取单例 (推荐)
    _repo = GetIt.instance<ScheduleRepository>();
  }

  Future<void> _loadData() async {
    try {
      final schedules = await _repo.getAllSchedules();
      setState(() {
        // 更新 UI
      });
    } catch (e) {
      // 错误处理
    }
  }
}
```

### 2. 快速选择

选择适合你的场景：

| 场景 | 使用何者 | 方法 |
|------|--------|------|
| 显示日程列表 | ScheduleRepository | getSchedules() |
| 显示日常任务 | DailyTaskRepository | getDailyTasks() |
| 显示对话列表 | ConversationRepository | getConversations() |
| 创建新项目 | 对应 Repository | create*() |
| 更新项目 | 对应 Repository | update*() |
| 删除项目 | 对应 Repository | delete*() |

---

## ScheduleRepository 详细用法

### 获取日程数据

```dart
// 获取特定月份的日程 (自动缓存 15 分钟)
final schedules = await _repo.getSchedules(
  year: 2025,
  month: 12,
);

// 获取所有日程 (一次性加载所有月份)
final allSchedules = await _repo.getAllSchedules();

// 获取单个日程
final schedule = await _repo.getScheduleById('schedule-id-123');

// 手动刷新 (清除缓存，强制从 API 获取)
final fresh = await _repo.refreshSchedules(2025, 12);
```

### 创建日程

```dart
final newSchedule = Schedule(
  id: 'id',
  userId: 'user-id',
  title: '团队会议',
  description: '讨论 Q1 计划',
  startTime: DateTime(2025, 12, 10, 14, 0),
  endTime: DateTime(2025, 12, 10, 15, 0),
  isAllDay: false,
  status: 'pending',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

await _repo.createSchedule(newSchedule);

// ✅ 自动效果:
// - 发送 POST /api/schedules
// - 自动清除 12 月的日程缓存
// - UI 自动刷新
```

### 更新日程

```dart
final updated = schedule.copyWith(
  status: 'completed',
  description: '已完成讨论',
);

await _repo.updateSchedule(updated);

// ✅ 自动效果:
// - 发送 PUT /api/schedules/{id}
// - 清除所有日程缓存 (月份无关)
// - 清除该日程的详情缓存
```

### 删除日程

```dart
await _repo.deleteSchedule('schedule-id-123');

// ✅ 自动效果:
// - 发送 DELETE /api/schedules/{id}
// - 清除所有日程缓存
```

### 批量操作

```dart
// ❌ 不支持原生批量 (需要循环)
for (final id in ids) {
  await _repo.deleteSchedule(id);
}

// ✅ 优化: 后续考虑实现 deleteSchedulesBatch()
```

### 缓存管理

```dart
// 手动清除特定月份的缓存
await _repo.invalidateCache(2025, 12);

// 手动清除所有日程缓存
await _repo.invalidateAllCaches();
```

---

## DailyTaskRepository 详细用法

### 获取日常任务

```dart
// 获取活跃任务 (10 分钟缓存)
final active = await _repo.getDailyTasks(status: 'active');

// 获取已暂停任务
final paused = await _repo.getDailyTasks(status: 'paused');

// 获取所有任务
final all = await _repo.getDailyTasks(status: 'all');

// 获取单个任务
final task = await _repo.getDailyTaskById('task-id-123');

// 获取任务统计
final stats = await _repo.getDailyTaskStats('task-id-123');
// stats 包含: { completed: 5, total: 10 }
```

### 创建日常任务

```dart
final newTask = await _repo.createDailyTask(
  title: '每日冥想',
  description: '10 分钟冥想',
  startTime: DateTime(1970, 1, 1, 8, 0), // 每天 8:00
  category: '健康',
  color: '#FF5733',
);

// ✅ 自动效果:
// - 发送 POST /api/daily-tasks
// - 返回创建的任务对象
// - 清除所有日常任务缓存
```

### 更新日常任务

```dart
final updated = await _repo.updateDailyTask(
  'task-id-123',
  title: '每日冥想 (改进)',
  startTime: DateTime(1970, 1, 1, 9, 0), // 改到 9:00
);

// ✅ 自动效果:
// - 发送 PUT /api/daily-tasks/{id}
// - 返回更新后的任务对象
// - 清除所有状态的缓存 (active/paused/all)
```

### 删除日常任务

```dart
await _repo.deleteDailyTask('task-id-123');

// ✅ 自动效果:
// - 发送 DELETE /api/daily-tasks/{id}
// - 清除所有日常任务缓存
```

### 刷新数据

```dart
// 刷新所有任务 (忽略缓存)
await _repo.refreshDailyTasks();

// 会清除缓存并从 API 重新加载
```

---

## ConversationRepository 详细用法

### 获取对话数据

```dart
// 获取对话列表 (5 分钟缓存)
final conversations = await _repo.getConversations();

// 获取对话详情 (包含消息)
final detail = await _repo.getConversationDetail('conv-id-123');
// detail.messages 包含该对话的所有消息

// 获取单个对话 (无消息)
final conv = await _repo.getConversationById('conv-id-123');
```

### 创建对话

```dart
final newConv = await _repo.createConversation('新对话标题');

// ✅ 自动效果:
// - 发送 POST /api/conversations
// - 返回新对话对象
// - 自动清除对话列表缓存
```

### 发送消息

```dart
final message = await _repo.sendMessage(
  conversationId: 'conv-id-123',
  content: '你好，这是我的消息',
);

// ✅ 自动效果:
// - 发送 POST /api/conversations/{id}/messages
// - 返回消息对象
// - 清除该对话的详情缓存
// - 列表缓存不清除 (只涉及消息内容)
```

### 更新对话标题

```dart
final updated = await _repo.updateConversationTitle(
  'conv-id-123',
  '新标题',
);

// ✅ 自动效果:
// - 发送 PUT /api/conversations/{id}
// - 返回更新后的对话对象
// - 清除对话列表缓存
```

### 删除对话

```dart
await _repo.deleteConversation('conv-id-123');

// ✅ 自动效果:
// - 发送 DELETE /api/conversations/{id}
// - 清除对话列表和详情缓存
```

### 手动失效缓存

```dart
// 清除特定对话的缓存
await _repo.invalidateConversationCache('conv-id-123');

// 清除对话列表缓存
await _repo.invalidateConversationListCache();
```

---

## 缓存工作机制

### 缓存流程图

```
页面请求 getXxx()
    ↓
检查缓存是否存在且有效?
    ├─ 是 → 返回缓存 (立即)
    └─ 否 → 发送 API 请求
        ↓
    网络成功?
        ├─ 是 → 保存到缓存 + 返回
        └─ 否 → 
            ├─ 缓存存在 (已过期)? 
            │   └─ 是 → 使用过期缓存 (离线模式)
            └─ 缓存不存在?
                └─ 是 → 抛异常
```

### 缓存 TTL (生存时间)

| 仓储 | 缓存键 | TTL | 清除条件 |
|------|-------|-----|--------|
| Schedule | schedules_{year}_{month} | 15 分钟 | 月份变化、创建/更新/删除任意日程 |
| DailyTask | daily_tasks_{status} | 10 分钟 | 创建/更新/删除任意日常任务 |
| Conversation | conversations_list | 5 分钟 | 创建/删除对话 |
| Conversation | conversation_detail_{id} | 5 分钟 | 发送消息、更新标题 |

### 手动失效

```dart
// 方式 1: 通过 Repository 方法
await _repo.invalidateCache(...);
await _repo.invalidateAllCaches();

// 方式 2: 直接调用 CacheService
final cacheService = GetIt.instance<CacheService>();
await cacheService.remove('cache_key');
```

---

## 错误处理

### 常见异常

```dart
try {
  final schedules = await _repo.getSchedules(2025, 12);
} on DioException catch (e) {
  if (e.response?.statusCode == 401) {
    // Token 过期，需要重新登录
    print('请重新登录');
  } else if (e.response?.statusCode == 404) {
    // 资源不存在
    print('资源不存在');
  } else if (e.response?.statusCode == 500) {
    // 服务器错误
    print('服务器错误，请稍后重试');
  } else if (e.type == DioExceptionType.connectionTimeout) {
    // 网络超时 - 将使用缓存
    print('网络超时，使用本地缓存');
  }
} catch (e) {
  // 其他异常
  print('未知错误: $e');
}
```

### 离线检测

```dart
// 检查是否有网络
try {
  final schedules = await _repo.getSchedules(2025, 12);
  print('网络正常');
} on DioException catch (e) {
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout) {
    print('离线模式 - 使用缓存');
    // 应用已自动降级到缓存
  }
}
```

---

## 性能最佳实践

### ✅ 推荐做法

```dart
// 1. 页面加载时 - 直接使用缓存
@override
void initState() {
  super.initState();
  _loadData(); // 使用仓储，自动利用缓存
}

// 2. 用户下拉刷新 - 手动刷新
Future<void> _handleRefresh() async {
  await _repo.refreshSchedules(2025, 12);
  setState(() { /* UI 更新 */ });
}

// 3. 创建/更新/删除后 - 自动刷新
Future<void> _createAndRefresh(Schedule schedule) async {
  await _repo.createSchedule(schedule);
  // ✅ 缓存自动清除
  // ✅ 下次 getSchedules 会重新加载
  setState(() { /* UI 更新 */ });
}

// 4. 从其他页面返回 - 检查缓存是否有效
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  // ✅ 如果缓存有效 (<15分钟)，无需重新加载
  _loadData();
}
```

### ❌ 避免做法

```dart
// ❌ 避免: 频繁刷新 (会发送大量 API 请求)
Timer.periodic(Duration(seconds: 1), (_) {
  _repo.refreshSchedules(2025, 12);
});

// ✅ 改进: 使用缓存 + 偶尔手动刷新
Timer.periodic(Duration(minutes: 5), (_) {
  _repo.refreshSchedules(2025, 12);
});

// ❌ 避免: 为每个操作创建新实例
final repo1 = ScheduleRepository();
final repo2 = ScheduleRepository();
// 会创建 2 个独立的缓存实例

// ✅ 改进: 使用 GetIt 单例
final repo = GetIt.instance<ScheduleRepository>();
// 所有地方共享同一个缓存
```

---

## 扩展仓储

### 添加新方法

```dart
// 在 ScheduleRepository 中添加新方法
Future<List<Schedule>> getSchedulesByStatus(String status) async {
  const cacheKey = 'schedules_by_status_$status';
  
  // 检查缓存
  final cached = await _cacheService.get<List<Schedule>>(cacheKey);
  if (cached != null) return cached;
  
  try {
    // 调用 API
    final schedules = await _service.getSchedulesByStatus(status);
    
    // 缓存结果
    await _cacheService.set(cacheKey, schedules, duration: Duration(minutes: 15));
    
    return schedules;
  } catch (e) {
    // 降级到过期缓存
    final expired = await _cacheService.get<List<Schedule>>(cacheKey);
    if (expired != null) return expired;
    rethrow;
  }
}
```

### 添加新仓储

```dart
// 创建 lib/repositories/notification_repository.dart
import 'package:hive/hive.dart';
import '../services/notification_service.dart';
import '../services/cache/cache_service.dart';

class NotificationRepository {
  final NotificationService _service = NotificationService();
  final CacheService _cacheService = GetIt.instance<CacheService>();
  
  Future<List<Notification>> getNotifications() async {
    const cacheKey = 'notifications_list';
    
    final cached = await _cacheService.get<List<Notification>>(cacheKey);
    if (cached != null) return cached;
    
    try {
      final notifications = await _service.getNotifications();
      await _cacheService.set(
        cacheKey,
        notifications,
        duration: Duration(minutes: 5),
      );
      return notifications;
    } catch (e) {
      // ... 离线降级
    }
  }
  
  // ... 其他方法
}
```

然后在 `service_locator.dart` 中注册：

```dart
void setupServiceLocator() {
  // ...现有注册...
  
  // 新添加
  getIt.registerSingleton<NotificationRepository>(
    NotificationRepository(),
  );
}
```

---

## 调试和监控

### 查看缓存状态

```dart
// 通过 Hive DevTools (如果已集成)
// 或打印调试信息
final cacheService = GetIt.instance<CacheService>();
final allKeys = await cacheService.getAllKeys();
print('缓存中的键: $allKeys');

for (final key in allKeys) {
  final value = await cacheService.get(key);
  print('$key: $value');
}
```

### 启用调试日志

```dart
// 在 main.dart 中
void main() {
  // 启用 Hive 调试
  // Hive.init(appDir.path);
  
  // 启用 Dio 日志
  ApiClient.instance.dio.interceptors.add(
    LoggingInterceptor(),
  );
  
  runApp(const MyApp());
}
```

### 性能监控

```dart
// 测量响应时间
Stopwatch sw = Stopwatch()..start();
final schedules = await _repo.getSchedules(2025, 12);
sw.stop();
print('加载耗时: ${sw.elapsedMilliseconds}ms');

// 缓存命中: < 10ms
// 网络请求: > 100ms
```

---

## 常见问题 (FAQ)

### Q: 如何强制更新，忽略缓存？

```dart
// 方式 1: 调用 refresh*() 方法
await _repo.refreshSchedules(2025, 12);

// 方式 2: 先清除缓存再获取
await _repo.invalidateCache(2025, 12);
final schedules = await _repo.getSchedules(2025, 12);
```

### Q: 如何实时同步数据？

暂无原生支持，建议方案：
1. 后端推送通知 → App 收到后清除缓存
2. 页面焦点事件 → 定期刷新
3. WebSocket → 实时消息更新

### Q: 缓存占用多少空间？

```dart
// Hive 数据库大小通常 < 10 MB
// 具体取决于:
// - 日程数量
// - 对话数量
// - 历史数据

// 监控方式:
final box = Hive.box('schedules_cache');
print('缓存条目数: ${box.length}');
```

### Q: 如何清除所有缓存？

```dart
// 方式 1: 通过 Repository
await _repo.invalidateAllCaches();

// 方式 2: 直接清除 Hive
final cacheService = GetIt.instance<CacheService>();
await cacheService.clear();
```

### Q: 能否实现缓存预加载？

```dart
// 目前需要手动实现
Future<void> _preload() async {
  // 预加载当前和下一个月份
  final now = DateTime.now();
  await _repo.getSchedules(now.year, now.month);
  await _repo.getSchedules(now.year, now.month + 1);
}
```

---

## 相关资源

- [仓储模式详解](https://refactoring.guru/design-patterns/repository)
- [Hive Flutter 文档](https://docs.hivedb.dev/)
- [GetIt 依赖注入](https://pub.dev/packages/get_it)
- [本项目 Phase 2 完成总结](.github/phase2-completion-summary.md)

---

**文档版本:** 1.0  
**最后更新:** 2025-12-10
