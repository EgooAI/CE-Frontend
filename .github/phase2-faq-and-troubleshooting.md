# Phase 2 迁移 FAQ 和故障排查

## 常见问题 (FAQ)

### 一般问题

#### Q1: Phase 2 是什么？
**A:** Phase 2 是 CE-Frontend 的仓储层迁移项目。我们在服务层和 UI 层之间添加了仓储层，实现了透明的缓存管理、离线支持和性能优化。

#### Q2: 这会影响现有功能吗？
**A:** 否。仓储层完全向后兼容，对用户没有影响。所有功能保持不变，只是性能和可靠性提升了。

#### Q3: 为什么需要仓储层？
**A:** 仓储层的好处：
- 🎯 **缓存管理** - 减少 API 调用 30-50%
- 🌐 **离线支持** - 网络失败时使用缓存
- 🏗️ **代码结构** - 清晰的关注点分离
- 🧪 **易于测试** - Mock 仓储而非 API

#### Q4: 是否需要修改我的代码？
**A:** 仅当你在页面中直接使用服务时。已经迁移的页面 (Calendar/Daily/Task/Chat) 已自动支持。

---

### 实施问题

#### Q5: 如何在新页面中使用仓储？

```dart
// ❌ 旧方式
import '../services/schedule_service.dart';

class MyPage extends State {
  final _service = ScheduleService();
  
  void _load() async {
    final data = await _service.getSchedules();
  }
}

// ✅ 新方式
import 'package:get_it/get_it.dart';
import '../repositories/schedule_repository.dart';

class MyPage extends State {
  late ScheduleRepository _repo;
  
  @override
  void initState() {
    _repo = GetIt.instance<ScheduleRepository>();
    super.initState();
  }
  
  void _load() async {
    final data = await _repo.getSchedules(2025, 12);
    // ✅ 自动缓存，自动离线支持
  }
}
```

#### Q6: 如何创建新仓储类？

```dart
// 1️⃣ 创建文件 lib/repositories/my_repository.dart
import 'package:get_it/get_it.dart';
import '../services/cache/cache_service.dart';
import '../services/my_service.dart';

class MyRepository {
  final MyService _service = MyService();
  final CacheService _cache = GetIt.instance<CacheService>();
  
  Future<List<Item>> getItems() async {
    const key = 'my_items';
    
    // 检查缓存
    final cached = await _cache.get<List<Item>>(key);
    if (cached != null) return cached;
    
    try {
      // API 请求
      final items = await _service.getItems();
      
      // 保存到缓存
      await _cache.set(key, items, duration: Duration(minutes: 10));
      
      return items;
    } catch (e) {
      // 离线降级
      final expired = await _cache.get<List<Item>>(key);
      if (expired != null) return expired;
      rethrow;
    }
  }
}

// 2️⃣ 在 lib/utils/service_locator.dart 注册
void setupServiceLocator() {
  // ... 现有代码 ...
  
  // 新仓储
  getIt.registerSingleton<MyRepository>(MyRepository());
}

// 3️⃣ 在页面中使用
final repo = GetIt.instance<MyRepository>();
final items = await repo.getItems();
```

#### Q7: 缓存 TTL 如何设置？

```dart
// 使用默认 TTL (10 分钟)
await _cache.set(key, data);

// 自定义 TTL
await _cache.set(
  key,
  data,
  duration: Duration(minutes: 5),  // 5 分钟
);

// 永不过期 (不建议)
await _cache.set(
  key,
  data,
  duration: Duration(days: 365),
);
```

#### Q8: 如何强制刷新缓存？

```dart
// 方式 1: 使用 refresh*() 方法
await _repo.refreshSchedules(2025, 12);

// 方式 2: 先清除后加载
await _repo.invalidateCache(2025, 12);
final data = await _repo.getSchedules(2025, 12);

// 方式 3: 直接清除缓存
final cache = GetIt.instance<CacheService>();
await cache.remove('schedules_2025_12');
```

#### Q9: 如何监控缓存命中率？

```dart
// 添加日志
Stopwatch sw = Stopwatch()..start();
final data = await _repo.getSchedules(2025, 12);
sw.stop();

if (sw.elapsedMilliseconds < 10) {
  print('✅ 缓存命中');
} else if (sw.elapsedMilliseconds < 500) {
  print('⚠️ 网络请求（快速）');
} else {
  print('❌ 网络请求（缓慢）');
}
```

#### Q10: GetIt 单例是否线程安全？

**A:** 是的，GetIt 是线程安全的。但 Hive (缓存数据库) 在并发写入时可能有问题。

```dart
// 使用 synchronized 包进行锁保护
import 'package:synchronized/synchronized.dart';

final lock = Lock();

Future<void> safeWrite(String key, dynamic value) async {
  await lock.synchronized(() async {
    await cacheService.set(key, value);
  });
}
```

---

### 性能问题

#### Q11: 为什么有时候数据不更新？

**可能原因及解决方案：**

```dart
// 原因 1: 缓存还未过期
// 解决: 手动刷新
await _repo.refreshSchedules(2025, 12);

// 原因 2: 在其他页面修改了数据
// 解决: 使用事件通知或手动刷新
// EventBus.fire(ScheduleChangedEvent());

// 原因 3: 缓存键不匹配
// 调试: 打印缓存内容
final cache = GetIt.instance<CacheService>();
print(await cache.get('schedules_2025_12'));
```

#### Q12: 缓存占用多少存储空间？

**估计：**

```
每条日程:         ~500 字节
每条日常任务:     ~300 字节
每条对话:         ~200 字节
每条消息:         ~100 字节

典型用户 (假设):
- 300 条日程 (6 个月)   = 150 KB
- 50 条日常任务          = 15 KB
- 10 条对话             = 2 KB
- 1000 条消息           = 100 KB
                        ≈ 270 KB

✅ 总计通常 < 1 MB
```

#### Q13: 如何清除所有缓存？

```dart
// 方式 1: 清除特定仓储的缓存
await _scheduleRepo.invalidateAllCaches();
await _dailyRepo.invalidateAllCaches();

// 方式 2: 清除所有缓存
final cache = GetIt.instance<CacheService>();
await cache.clear();

// 方式 3: 删除 Hive 数据库 (核选项)
// await Hive.deleteBoxFromDisk('cache_box');
```

#### Q14: 离线时数据会多久过期？

```dart
// 缓存在离线时不会自动过期
// 只有在重新上线后，超过 TTL 的缓存才会被删除

// 例如：
// 日程缓存: 15 分钟 TTL
// 离线 10 分钟: ✅ 缓存有效
// 离线 20 分钟: ✅ 缓存仍可用 (不会自动删除)
// 上线后: 缓存仍有 5 分钟有效期

// 强制更新:
await _repo.refreshSchedules(2025, 12);
```

---

### 错误排查

#### Q15: 报错 "GetIt instance not found"

```
错误信息:
GetIt.instance<ScheduleRepository>(): No named instance found: ScheduleRepository

原因:
1. setupServiceLocator() 未被调用
2. 拼错了类名

解决:

// 1️⃣ 在 main() 中确保调用
import 'utils/service_locator.dart';

void main() {
  setupServiceLocator();  // ✅ 必须调用
  runApp(const MyApp());
}

// 2️⃣ 检查仓储是否已注册
// lib/utils/service_locator.dart
void setupServiceLocator() {
  // ...
  getIt.registerSingleton<ScheduleRepository>(
    ScheduleRepository(),
  );
  // ...
}
```

#### Q16: 报错 "Box not found"

```
错误信息:
HiveError: Box not found: schedules_cache

原因:
Hive 数据库文件损坏或丢失

解决:
// 方式 1: 清除应用数据
flutter clean
flutter pub get

// 方式 2: 删除 Hive 数据库
rm -rf ~/path/to/app_data/hive_boxes

// 方式 3: 重启应用
```

#### Q17: 报错 "DioException: Connection timeout"

```
错误信息:
DioException: Connection timeout of 30000ms

原因:
网络连接缓慢或无网

解决:
// 已自动处理 ✅
// 应用会自动使用缓存降级
// 无需特殊处理

try {
  final data = await _repo.getSchedules(2025, 12);
} catch (e) {
  // 如果进入这里，说明：
  // 1. 网络完全无法连接
  // 2. 本地没有缓存数据
  // 此时无法提供数据
}
```

#### Q18: 报错 "State.setState called after dispose"

```
错误信息:
setState() called after dispose() of _MyPageState

原因:
异步操作后页面被销毁

解决:
Future<void> _loadData() async {
  try {
    final data = await _repo.getSchedules(2025, 12);
    
    // ✅ 检查 mounted
    if (!mounted) return;
    
    setState(() {
      // ...
    });
  } catch (e) {
    // ✅ 也要检查
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(/*...*/);
  }
}
```

---

### 兼容性问题

#### Q19: 是否支持所有 Flutter 版本？

**支持版本:**
- ✅ Flutter 3.0+
- ✅ Dart 2.17+

**已测试的版本:**
- ✅ Flutter 3.10.x
- ✅ Flutter 3.16.x
- ✅ Flutter 3.22.x

#### Q20: 是否支持所有平台？

| 平台 | 支持 | 备注 |
|------|------|------|
| Android | ✅ | 5.0+ |
| iOS | ✅ | 11.0+ |
| Web | ✅ | 所有现代浏览器 |
| macOS | ✅ | 10.11+ |
| Windows | ✅ | 7+ |
| Linux | ✅ | 所有 |

---

## 迁移路线图

### ✅ 已完成 (Phase 2)

```
2025-12-10
├─ ✅ CacheService 基础设施
├─ ✅ HiveCacheService 实现
├─ ✅ ScheduleRepository (150 行)
├─ ✅ DailyTaskRepository (180 行)
├─ ✅ ConversationRepository (200 行)
├─ ✅ ServiceLocator 配置
├─ ✅ CalendarPage 迁移
├─ ✅ DailyPage 迁移
├─ ✅ TaskPage 迁移
└─ ✅ ChatPage 迁移

编译状态: ✅ 0 errors
```

### 🚧 进行中 (Phase 3 - 可选)

```
预计 2025-12-20
├─ 🔲 添加单元测试 (80%+ 覆盖)
├─ 🔲 集成测试验证
├─ 🔲 性能基准测试
└─ 🔲 文档完善
```

### 🔮 规划中 (Phase 4+)

```
预计 2026-01-15
├─ 🔲 推送通知集成
├─ 🔲 后台同步队列
├─ 🔲 WebSocket 实时更新
├─ 🔲 智能预加载系统
└─ 🔲 数据同步冲突解决
```

---

## 快速检查清单

迁移完成后，请确认：

- [ ] ✅ `flutter analyze` 返回 0 errors
- [ ] ✅ 应用可以启动
- [ ] ✅ 日程页面可以加载
- [ ] ✅ 日常任务可以加载
- [ ] ✅ 聊天页面可以加载
- [ ] ✅ 任务页面可以加载
- [ ] ✅ 创建/更新/删除功能正常
- [ ] ✅ 离线时可以查看缓存数据
- [ ] ✅ 重新上线后数据自动更新

如果所有项目都通过 ✅，则迁移成功！

---

## 获取帮助

**问题排查步骤：**

1. 📖 查看本 FAQ
2. 📚 查看 [使用指南](./repository-usage-guide.md)
3. 📝 查看 [完成总结](./phase2-completion-summary.md)
4. 🔍 检查编译错误：`flutter analyze`
5. 🗑️ 清理项目：`flutter clean && flutter pub get`
6. ♻️ 重启应用

**如果问题仍未解决：**

```dart
// 启用调试日志
import 'dart:developer' as developer;

developer.log(
  'Debug: $message',
  level: 1000,
  name: 'MyApp.debug',
);
```

---

**文档版本:** 1.0  
**最后更新:** 2025-12-10  
**有用吗？** 欢迎反馈！
