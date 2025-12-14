# 📋 本地缓存功能实施计划

## 📅 项目概览

**目标**：为 CE-Frontend 添加完整的本地缓存能力，支持离线使用  
**预计工期**：2-3 周（按每天 4-6 小时开发时间计算）  
**技术栈**：Flutter + Hive + Repository 模式  
**影响范围**：全部数据请求层（非破坏性改造）

---

## 🎯 里程碑规划

```
Week 1: 基础设施搭建 (40%)
├─ Day 1-2: Hive 集成 + 基础缓存服务
├─ Day 3-4: Schedule 缓存实现
└─ Day 5: 测试 + Bug 修复

Week 2: 功能扩展 (40%)
├─ Day 6-7: DailyTask + User 缓存
├─ Day 8-9: Conversation 缓存
└─ Day 10: 离线队列基础

Week 3: 优化和收尾 (20%)
├─ Day 11-12: 离线编辑同步
├─ Day 13: 性能优化 + 缓存策略调整
└─ Day 14: 全面测试 + 文档
```

---

## 📝 详细任务拆解

### **Phase 1: 基础设施（Week 1）**

#### **Task 1.1: 环境准备和依赖集成** ⏱️ 2h
- [ ] pubspec.yaml 添加依赖
- [ ] 运行 flutter pub get
- [ ] 创建基础文件结构
- [ ] 验证编译无误

#### **Task 1.2: 实现 CacheService 基类** ⏱️ 3h
- [ ] 创建 cache_service.dart 抽象类
- [ ] 定义所有接口方法
- [ ] 添加完整注释
- [ ] 确保类型安全

#### **Task 1.3: Hive 适配器生成** ⏱️ 4h
- [ ] Schedule 模型添加 @HiveType
- [ ] DailyTask 模型添加 @HiveType
- [ ] User 模型添加 @HiveType
- [ ] Conversation 模型添加 @HiveType
- [ ] 运行代码生成器
- [ ] 验证序列化/反序列化

#### **Task 1.4: HiveCacheService 实现** ⏱️ 4h
- [ ] 实现 init() 方法
- [ ] 实现所有 CRUD 方法
- [ ] 添加时间戳管理
- [ ] 完善错误处理
- [ ] 单元测试

#### **Task 1.5: ScheduleRepository 实现** ⏱️ 6h
- [ ] 创建 ScheduleRepository 类
- [ ] 实现 getSchedules() - 网络优先策略
- [ ] 实现 getScheduleById()
- [ ] 实现 createSchedule()
- [ ] 实现 updateSchedule()
- [ ] 实现 deleteSchedule()
- [ ] 断网测试
- [ ] 缓存过期测试

#### **Task 1.6: CalendarPage 迁移** ⏱️ 4h
- [ ] 注入 ScheduleRepository
- [ ] 改造 _loadSchedules()
- [ ] 添加 _isOffline 状态
- [ ] 添加离线提示 UI
- [ ] 实现下拉刷新强制更新
- [ ] 测试在线/离线场景

#### **Task 1.7: 主程序集成和初始化** ⏱️ 2h
- [ ] 安装 get_it 依赖
- [ ] 创建 service_locator.dart
- [ ] main() 中初始化 Hive
- [ ] 注册所有服务
- [ ] 测试应用启动

---

### **Phase 2: 功能扩展（Week 2）**

#### **Task 2.1: DailyTaskRepository 实现** ⏱️ 4h
- [ ] 实现 getDailyTasks()
- [ ] 实现 createDailyTask()
- [ ] 实现 updateDailyTask()
- [ ] 实现 deleteDailyTask()
- [ ] 缓存策略配置

#### **Task 2.2: DailyPage 迁移** ⏱️ 3h
- [ ] 使用 DailyTaskRepository
- [ ] 添加离线模式支持
- [ ] 测试功能

#### **Task 2.3: UserRepository 实现** ⏱️ 3h
- [ ] 实现 getProfile()
- [ ] 实现 updateProfile()
- [ ] 实现 updateConfig()
- [ ] 短过期时间策略

#### **Task 2.4: ProfilePage 迁移** ⏱️ 2h
- [ ] 使用 UserRepository
- [ ] 配置更新同步缓存
- [ ] 测试配置修改

#### **Task 2.5: ConversationRepository 实现** ⏱️ 4h
- [ ] 实现 getConversations()
- [ ] 实现 getConversationById()
- [ ] 实现 sendMessage()
- [ ] 消息追加缓存策略

#### **Task 2.6: ChatPage 迁移** ⏱️ 4h
- [ ] 使用 ConversationRepository
- [ ] SSE 消息追加到缓存
- [ ] 离线查看历史消息

#### **Task 2.7: TaskPage 迁移** ⏱️ 2h
- [ ] 使用 ScheduleRepository
- [ ] 添加离线标识
- [ ] 测试功能

---

### **Phase 3: 离线队列和优化（Week 3）**

#### **Task 3.1: SyncQueue 数据模型** ⏱️ 2h
- [ ] 创建 sync_task.dart
- [ ] 定义字段和类型
- [ ] 添加 Hive 适配器

#### **Task 3.2: SyncQueueService 实现** ⏱️ 6h
- [ ] 实现 addTask()
- [ ] 实现 processPendingTasks()
- [ ] 实现 retryFailedTasks()
- [ ] 网络检测逻辑
- [ ] 冲突处理策略

#### **Task 3.3: Repository 集成离线队列** ⏱️ 4h
- [ ] ScheduleRepository 集成
- [ ] DailyTaskRepository 集成
- [ ] ConversationRepository 集成
- [ ] 错误处理优化

#### **Task 3.4: 后台同步任务** ⏱️ 4h
- [ ] 创建 background_sync_service.dart
- [ ] 定时器实现
- [ ] 网络检测
- [ ] 进度通知

#### **Task 3.5: 离线模式 UI 优化** ⏱️ 3h
- [ ] 顶部离线 Banner
- [ ] 待同步徽章
- [ ] 手动同步按钮
- [ ] 同步进度提示

#### **Task 3.6: 缓存管理界面** ⏱️ 4h
- [ ] 创建 cache_management_page.dart
- [ ] 显示缓存大小
- [ ] 清空缓存功能
- [ ] 查看同步队列
- [ ] 手动同步触发

#### **Task 3.7: 性能优化** ⏱️ 4h
- [ ] 大列表分页缓存
- [ ] 缓存预热
- [ ] 缓存压缩
- [ ] 过期缓存清理
- [ ] 性能测试

#### **Task 3.8: 全面测试** ⏱️ 6h
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

### **问题 1: Hive 迁移数据丢失**
**风险级别**: 🔴 高  
**影响**: 用户历史数据丢失

**解决方案**:
1. **版本号管理**
   ```dart
   // 在 Box 中存储版本号
   const int CACHE_VERSION = 1;
   
   Future<void> init() async {
     _box = await Hive.openBox('app_cache');
     final version = _box.get('_cache_version', defaultValue: 0);
     
     if (version < CACHE_VERSION) {
       await _migrateCache(version, CACHE_VERSION);
       await _box.put('_cache_version', CACHE_VERSION);
     }
   }
   ```

2. **迁移脚本**
   ```dart
   Future<void> _migrateCache(int from, int to) async {
     if (from == 0 && to == 1) {
       // 首次迁移：清空所有缓存（安全策略）
       await _box.clear();
     }
     // 后续版本添加增量迁移逻辑
   }
   ```

3. **备份机制**
   ```dart
   Future<void> backupCache() async {
     final backupBox = await Hive.openBox('cache_backup');
     for (var key in _box.keys) {
       backupBox.put(key, _box.get(key));
     }
   }
   ```

---

### **问题 2: 并发写入冲突**
**风险级别**: 🟠 中  
**影响**: 数据覆盖、状态不一致

**解决方案**:
1. **Repository 层加锁**
   ```dart
   class ScheduleRepository {
     final _lock = Lock(); // 使用 synchronized 包
     
     Future<void> updateSchedule(Schedule schedule) async {
       await _lock.synchronized(() async {
         // 读取缓存
         final cached = await _cache.getList<Schedule>('schedules');
         
         // 更新
         final index = cached.indexWhere((s) => s.id == schedule.id);
         if (index != -1) {
           cached[index] = schedule;
         }
         
         // 写回缓存
         await _cache.setList('schedules', cached);
       });
     }
   }
   ```

2. **乐观锁机制**
   ```dart
   class CachedData<T> {
     final T data;
     final int version;
     final DateTime timestamp;
   }
   
   Future<void> set<T>(String key, T value) async {
     final cached = await get<CachedData<T>>(key);
     final newVersion = (cached?.version ?? 0) + 1;
     
     await _box.put(key, CachedData(
       data: value,
       version: newVersion,
       timestamp: DateTime.now(),
     ));
   }
   ```

---

### **问题 3: 缓存占用空间过大**
**风险级别**: 🟡 低  
**影响**: 存储空间不足

**解决方案**:
1. **LRU 缓存淘汰**
   ```dart
   class LRUCache<T> {
     final int maxSize;
     final LinkedHashMap<String, CachedItem<T>> _cache;
     
     Future<void> set(String key, T value) async {
       if (_cache.length >= maxSize) {
         // 删除最久未使用的
         final oldestKey = _cache.keys.first;
         _cache.remove(oldestKey);
         await _box.delete(oldestKey);
       }
       
       _cache[key] = CachedItem(value, DateTime.now());
       await _box.put(key, value);
     }
   }
   ```

2. **定期清理**
   ```dart
   // 启动时清理过期缓存
   Future<void> cleanExpiredCache() async {
     final now = DateTime.now();
     
     for (var key in _box.keys) {
       if (key.endsWith('_timestamp')) {
         final timestamp = _box.get(key) as int;
         final age = now.difference(
           DateTime.fromMillisecondsSinceEpoch(timestamp)
         );
         
         if (age > Duration(days: 7)) {
           // 清理 7 天前的缓存
           await _box.delete(key);
           await _box.delete(key.replaceAll('_timestamp', ''));
         }
       }
     }
   }
   ```

3. **大小限制**
   ```dart
   Future<int> getCacheSize() async {
     int totalSize = 0;
     for (var key in _box.keys) {
       final value = _box.get(key);
       totalSize += jsonEncode(value).length;
     }
     return totalSize;
   }
   
   Future<void> checkCacheSizeLimit() async {
     const maxSize = 50 * 1024 * 1024; // 50MB
     final size = await getCacheSize();
     
     if (size > maxSize) {
       await cleanOldestCache();
     }
   }
   ```

---

### **问题 4: 离线队列同步失败**
**风险级别**: 🟠 中  
**影响**: 数据未同步到服务器

**解决方案**:
1. **指数退避重试**
   ```dart
   class SyncTask {
     int retryCount = 0;
     DateTime? lastRetryAt;
     
     Duration get nextRetryDelay {
       // 1s, 2s, 4s, 8s, 16s, 32s, 60s (max)
       final delay = min(pow(2, retryCount).toInt(), 60);
       return Duration(seconds: delay);
     }
   }
   
   Future<void> retryTask(SyncTask task) async {
     if (task.lastRetryAt != null) {
       final elapsed = DateTime.now().difference(task.lastRetryAt!);
       if (elapsed < task.nextRetryDelay) {
         return; // 还未到重试时间
       }
     }
     
     try {
       await _executeTask(task);
       task.retryCount = 0;
     } catch (e) {
       task.retryCount++;
       task.lastRetryAt = DateTime.now();
       
       if (task.retryCount > 5) {
         // 超过 5 次，标记为失败
         task.status = 'failed';
         await _notifyUser(task);
       }
     }
   }
   ```

2. **用户手动同步**
   ```dart
   Future<void> manualSync() async {
     showDialog(
       context: context,
       barrierDismissible: false,
       builder: (_) => SyncProgressDialog(),
     );
     
     final results = await _syncQueue.processPendingTasks();
     
     Navigator.pop(context);
     
     showDialog(
       context: context,
       builder: (_) => AlertDialog(
         title: Text('同步结果'),
         content: Text('成功: ${results.success}, 失败: ${results.failed}'),
       ),
     );
   }
   ```

3. **冲突检测**
   ```dart
   Future<void> _executeTask(SyncTask task) async {
     try {
       final response = await _apiService.execute(task);
       
       if (response.statusCode == 409) {
         // 冲突：服务器数据已更新
         final serverData = response.data;
         
         // 弹窗让用户选择
         final choice = await showConflictDialog(
           localData: task.data,
           serverData: serverData,
         );
         
         if (choice == ConflictResolution.useServer) {
           // 放弃本地修改
           await _cache.set(task.resource, serverData);
         } else {
           // 强制覆盖服务器（风险操作）
           await _apiService.forceUpdate(task.data);
         }
       }
     } catch (e) {
       rethrow;
     }
   }
   ```

---

### **问题 5: 老数据结构不兼容**
**风险级别**: 🔴 高  
**影响**: 应用崩溃

**解决方案**:
1. **TypeAdapter 版本控制**
   ```dart
   @HiveType(typeId: 0, adapterName: 'ScheduleAdapterV2')
   class Schedule {
     @HiveField(0)
     final String id;
     
     @HiveField(10) // 新字段从 10 开始，避免冲突
     final String? newField;
   }
   ```

2. **降级兼容**
   ```dart
   factory Schedule.fromJson(Map<String, dynamic> json) {
     return Schedule(
       id: json['id'],
       // 旧字段可能不存在，提供默认值
       newField: json['newField'] ?? 'default',
     );
   }
   ```

3. **错误恢复**
   ```dart
   Future<T?> get<T>(String key) async {
     try {
       return _box.get(key) as T?;
     } catch (e) {
       print('缓存读取失败，可能是版本不兼容: $e');
       // 删除损坏的缓存
       await _box.delete(key);
       return null;
     }
   }
   ```

---

### **问题 6: 性能下降**
**风险级别**: 🟡 低  
**影响**: 应用卡顿

**解决方案**:
1. **懒加载**
   ```dart
   // 不要一次性加载所有数据
   Future<List<Schedule>> getSchedules({
     int page = 1,
     int pageSize = 20,
   }) async {
     final cacheKey = 'schedules_page_$page';
     
     // 按页缓存
     final cached = await _cache.getList<Schedule>(cacheKey);
     if (cached.isNotEmpty) {
       return cached;
     }
     
     // 从 API 获取
     final schedules = await _apiService.getSchedules(page, pageSize);
     await _cache.setList(cacheKey, schedules);
     
     return schedules;
   }
   ```

2. **异步初始化**
   ```dart
   void main() async {
     // 不阻塞 UI
     runApp(MyApp());
     
     // 后台初始化缓存
     unawaited(_initializeCache());
   }
   
   Future<void> _initializeCache() async {
     await Hive.initFlutter();
     await setupServiceLocator();
     
     // 预热常用数据
     unawaited(_warmupCache());
   }
   ```

3. **索引优化**
   ```dart
   // 对频繁查询的字段建索引
   late Box<Schedule> _scheduleBox;
   
   Future<void> init() async {
     _scheduleBox = await Hive.openBox<Schedule>('schedules');
     
     // 可以用 Map 做二级索引
     _scheduleIndex = {};
     for (var schedule in _scheduleBox.values) {
       _scheduleIndex[schedule.id] = schedule;
     }
   }
   ```

---

## 📈 成功指标

| 指标 | 目标 | 验证方法 |
|------|------|----------|
| **应用启动速度** | < 1秒 | 性能测试工具 |
| **页面加载速度** | < 200ms | 计时器 + 日志 |
| **离线可用率** | 100% | 断网测试 |
| **同步成功率** | > 95% | 统计日志 |
| **缓存命中率** | > 70% | 埋点统计 |
| **用户满意度** | 无Bug反馈 | 用户反馈 |

---

## ✅ 验收标准

**Phase 1 验收（Week 1 结束）**
- [ ] Hive 初始化成功
- [ ] Schedule 数据可缓存
- [ ] CalendarPage 离线可用
- [ ] 断网测试通过

**Phase 2 验收（Week 2 结束）**
- [ ] 所有页面支持缓存
- [ ] 离线模式 UI 完善
- [ ] 用户配置缓存生效

**Phase 3 验收（Week 3 结束）**
- [ ] 离线队列运行正常
- [ ] 自动同步无误
- [ ] 所有测试通过
- [ ] 性能达标

---

## 📚 参考资料

- [Hive 官方文档](https://docs.hivedb.dev/)
- [Flutter 缓存最佳实践](https://flutter.dev/docs/cookbook/persistence)
- [Repository 模式详解](https://developer.android.com/jetpack/guide)

---

**创建日期**: 2025-12-15  
**最后更新**: 2025-12-15  
**状态**: 准备开始实施
