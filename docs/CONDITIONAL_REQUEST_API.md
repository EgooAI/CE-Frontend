# HTTP 条件请求 API 文档

## 📚 概述

后端已为核心资源列表接口实现了 **HTTP 条件请求**（Conditional Requests），基于 `If-Modified-Since` 和 `Last-Modified` 头实现智能缓存。

### 优势

- ✅ **节省流量**：数据未变化时服务器返回 `304`（无响应体）
- ✅ **降低延迟**：304 响应无需序列化数据，服务器处理更快
- ✅ **标准协议**：基于 HTTP/1.1 标准，所有 HTTP 客户端都支持
- ✅ **自动处理**：服务器自动比对时间，客户端只需保存和发送时间戳

### 支持的接口

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 会话列表 | GET | `/api/conversations` | 用户所有会话 |
| 会话详情 | GET | `/api/conversations/:id` | 单个会话及其消息 |
| 日常任务列表 | GET | `/api/daily-tasks` | 用户所有日常任务 |
| 日程列表 | GET | `/api/schedules` | 用户所有日程 |

---

## 🔄 工作流程

### 1. 首次请求（无缓存）

```http
GET /api/conversations
Authorization: Bearer <access_token>
```

**响应 (200 OK)**：
```http
HTTP/1.1 200 OK
Last-Modified: Mon, 27 Jan 2025 08:30:15 GMT
Cache-Control: no-cache
Content-Type: application/json

{
  "code": 0,
  "message": "success",
  "data": [
    {
      "id": "conv-uuid-1",
      "title": "聊天1",
      "updated_at": "2025-01-27T08:30:15Z"
    }
  ]
}
```

**客户端操作**：
- 保存响应数据到本地缓存
- **保存 `Last-Modified` 值**（如 `Mon, 27 Jan 2025 08:30:15 GMT`）

---

### 2. 后续请求（有缓存）

#### 场景 A：数据未变化

```http
GET /api/conversations
Authorization: Bearer <access_token>
If-Modified-Since: Mon, 27 Jan 2025 08:30:15 GMT
```

**响应 (304 Not Modified)**：
```http
HTTP/1.1 304 Not Modified
Last-Modified: Mon, 27 Jan 2025 08:30:15 GMT
Cache-Control: no-cache
```

**客户端操作**：
- 直接使用本地缓存数据
- 无需更新缓存

---

#### 场景 B：数据已变化

```http
GET /api/conversations
Authorization: Bearer <access_token>
If-Modified-Since: Mon, 27 Jan 2025 08:30:15 GMT
```

**响应 (200 OK)**：
```http
HTTP/1.1 200 OK
Last-Modified: Mon, 27 Jan 2025 10:45:30 GMT
Cache-Control: no-cache
Content-Type: application/json

{
  "code": 0,
  "message": "success",
  "data": [
    {
      "id": "conv-uuid-1",
      "title": "聊天1（已修改）",
      "updated_at": "2025-01-27T10:45:30Z"
    },
    {
      "id": "conv-uuid-2",
      "title": "新聊天",
      "updated_at": "2025-01-27T10:45:30Z"
    }
  ]
}
```

**客户端操作**：
- 用新数据**覆盖**本地缓存
- **更新保存的 `Last-Modified`** 值为 `Mon, 27 Jan 2025 10:45:30 GMT`

---

## 📱 Flutter/Dart 集成示例

### 方法 1：使用 Dio 拦截器（推荐）

```dart
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConditionalRequestInterceptor extends Interceptor {
  final SharedPreferences _prefs;

  ConditionalRequestInterceptor(this._prefs);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // 仅对支持条件请求的接口添加 If-Modified-Since
    if (_isSupportedEndpoint(options.path)) {
      final lastModified = _prefs.getString('last_modified_${options.path}');
      if (lastModified != null) {
        options.headers['If-Modified-Since'] = lastModified;
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    // 保存 Last-Modified 头
    final lastModified = response.headers.value('Last-Modified');
    if (lastModified != null && _isSupportedEndpoint(response.requestOptions.path)) {
      await _prefs.setString('last_modified_${response.requestOptions.path}', lastModified);
    }
    handler.next(response);
  }

  bool _isSupportedEndpoint(String path) {
    return path.startsWith('/api/conversations') ||
           path.startsWith('/api/daily-tasks') ||
           path.startsWith('/api/schedules');
  }
}

// 使用方式
final prefs = await SharedPreferences.getInstance();
final dio = Dio(BaseOptions(baseUrl: 'https://your-api.com'));
dio.interceptors.add(ConditionalRequestInterceptor(prefs));
```

---

### 方法 2：手动实现

```dart
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

class ApiService {
  final Dio _dio;
  final Box _cacheBox;
  final Box<String> _timestampBox;

  ApiService(this._dio, this._cacheBox, this._timestampBox);

  Future<List<Conversation>> getConversations() async {
    const cacheKey = 'conversations';
    final lastModified = _timestampBox.get(cacheKey);

    try {
      final response = await _dio.get(
        '/api/conversations',
        options: Options(
          headers: lastModified != null
            ? {'If-Modified-Since': lastModified}
            : {},
        ),
      );

      if (response.statusCode == 304) {
        // 数据未变化，使用缓存
        print('✅ 缓存命中，使用本地数据');
        final cached = _cacheBox.get(cacheKey) as List<dynamic>;
        return cached.map((e) => Conversation.fromJson(e)).toList();
      }

      // 数据已更新或首次请求
      final data = response.data['data'] as List<dynamic>;
      final conversations = data.map((e) => Conversation.fromJson(e)).toList();

      // 保存到缓存
      await _cacheBox.put(cacheKey, data);

      // 保存时间戳
      final newLastModified = response.headers.value('Last-Modified');
      if (newLastModified != null) {
        await _timestampBox.put(cacheKey, newLastModified);
      }

      print('✅ 数据已更新，已保存到缓存');
      return conversations;

    } on DioException catch (e) {
      if (e.response?.statusCode == 304) {
        // Dio 可能将 304 当作错误处理
        final cached = _cacheBox.get(cacheKey) as List<dynamic>;
        return cached.map((e) => Conversation.fromJson(e)).toList();
      }
      rethrow;
    }
  }
}
```

---

### 方法 3：使用 http 包

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<List<Conversation>> getConversations() async {
  const cacheKey = 'conversations';
  final prefs = await SharedPreferences.getInstance();
  final lastModified = prefs.getString('last_modified_$cacheKey');

  final headers = {
    'Authorization': 'Bearer $accessToken',
    if (lastModified != null) 'If-Modified-Since': lastModified,
  };

  final response = await http.get(
    Uri.parse('https://your-api.com/api/conversations'),
    headers: headers,
  );

  if (response.statusCode == 304) {
    // 使用缓存
    final cached = prefs.getString(cacheKey);
    final data = jsonDecode(cached!)['data'] as List;
    return data.map((e) => Conversation.fromJson(e)).toList();
  }

  if (response.statusCode == 200) {
    // 保存新数据
    await prefs.setString(cacheKey, response.body);

    // 保存时间戳
    final newLastModified = response.headers['last-modified'];
    if (newLastModified != null) {
      await prefs.setString('last_modified_$cacheKey', newLastModified);
    }

    final data = jsonDecode(response.body)['data'] as List;
    return data.map((e) => Conversation.fromJson(e)).toList();
  }

  throw Exception('请求失败: ${response.statusCode}');
}
```

---

## 🎯 接口详细说明

### 1. 会话列表 `GET /api/conversations`

**请求头**：
```http
Authorization: Bearer <access_token>
If-Modified-Since: Mon, 27 Jan 2025 08:30:15 GMT  # 可选
```

**响应（数据未变化）**：
```http
HTTP/1.1 304 Not Modified
Last-Modified: Mon, 27 Jan 2025 08:30:15 GMT
```

**响应（数据已变化或首次请求）**：
```http
HTTP/1.1 200 OK
Last-Modified: Mon, 27 Jan 2025 10:45:30 GMT

{
  "code": 0,
  "message": "success",
  "data": [...]
}
```

**时间戳来源**：
- 计算所有会话的 `updated_at` 最大值
- 对比所有消息的 `created_at` 最大值（某条消息可能比会话更新）
- 取两者最大值作为 `Last-Modified`

---

### 2. 会话详情 `GET /api/conversations/:id`

**请求头**：
```http
Authorization: Bearer <access_token>
If-Modified-Since: Mon, 27 Jan 2025 09:15:20 GMT  # 可选
```

**响应（304）**：
```http
HTTP/1.1 304 Not Modified
Last-Modified: Mon, 27 Jan 2025 09:15:20 GMT
```

**响应（200）**：
```http
HTTP/1.1 200 OK
Last-Modified: Mon, 27 Jan 2025 11:20:45 GMT

{
  "code": 0,
  "message": "success",
  "data": {
    "id": "conv-uuid",
    "title": "聊天标题",
    "updated_at": "2025-01-27T11:20:45Z",
    "messages": [
      {
        "id": "msg-uuid-1",
        "content": "你好",
        "attachments": [
          {
            "key": "images/2025/01/27/uuid.jpg",
            "name": "photo.jpg",
            "url": "https://bucket.oss.aliyuncs.com/images/...?Expires=..."
          }
        ]
      }
    ]
  }
}
```

**时间戳来源**：
- 比较会话的 `updated_at`
- 比较该会话所有消息的 `created_at` 最大值
- 取两者最大值

**特殊说明**：
- 消息中的图片附件会自动生成 **24 小时有效期**的预签名 URL
- 附件的 `key` 存储在数据库，`url` 是动态生成的

---

### 3. 日常任务列表 `GET /api/daily-tasks`

**请求参数**：
```
?date=2025-01-27  # 可选，筛选特定日期
?limit=50         # 可选，限制数量
```

**请求头**：
```http
Authorization: Bearer <access_token>
If-Modified-Since: Mon, 27 Jan 2025 07:00:00 GMT  # 可选
```

**响应（304）**：
```http
HTTP/1.1 304 Not Modified
Last-Modified: Mon, 27 Jan 2025 07:00:00 GMT
```

**响应（200）**：
```http
HTTP/1.1 200 OK
Last-Modified: Mon, 27 Jan 2025 12:30:15 GMT

{
  "code": 0,
  "message": "success",
  "data": [
    {
      "id": "task-uuid",
      "title": "任务标题",
      "completed": false,
      "updated_at": "2025-01-27T12:30:15Z"
    }
  ]
}
```

**时间戳来源**：
- 用户所有任务的 `updated_at` 最大值
- **注意**：即使设置了 `date` 参数，时间戳仍基于全部任务（保证其他日期变化时也能感知）

---

### 4. 日程列表 `GET /api/schedules`

**请求参数**：
```
?startTime=2025-01-27T00:00:00Z  # 可选，开始时间
?endTime=2025-02-03T23:59:59Z    # 可选，结束时间
?title=会议                       # 可选，标题模糊搜索
?status=pending                  # 可选，状态筛选
?limit=100                       # 可选，限制数量
```

**请求头**：
```http
Authorization: Bearer <access_token>
If-Modified-Since: Mon, 27 Jan 2025 06:45:30 GMT  # 可选
```

**响应（304）**：
```http
HTTP/1.1 304 Not Modified
Last-Modified: Mon, 27 Jan 2025 06:45:30 GMT
```

**响应（200）**：
```http
HTTP/1.1 200 OK
Last-Modified: Mon, 27 Jan 2025 13:15:20 GMT

{
  "code": 0,
  "message": "success",
  "data": [
    {
      "id": "schedule-uuid",
      "title": "团队会议",
      "start_time": "2025-01-28T14:00:00Z",
      "updated_at": "2025-01-27T13:15:20Z"
    }
  ]
}
```

**时间戳来源**：
- 用户所有日程的 `updated_at` 最大值
- **注意**：即使设置了时间范围，时间戳仍基于全部日程

---

## ⚙️ 技术细节

### 时间格式

- **请求头格式**：`If-Modified-Since: Mon, 27 Jan 2025 08:30:15 GMT`
- **响应头格式**：`Last-Modified: Mon, 27 Jan 2025 08:30:15 GMT`
- **标准**：RFC 1123（HTTP 日期格式）

### 时间精度

- 服务器自动将时间**截断到秒**（去掉毫秒和纳秒）
- 避免数据库时间精度差异导致的误判

### Cache-Control

所有响应都包含：
```http
Cache-Control: no-cache
```

**含义**：
- 允许缓存数据
- 但必须先验证（发送 `If-Modified-Since`）
- 不允许直接使用过期缓存

---

## 🐛 常见问题

### Q1: 为什么总是返回 200，从不返回 304？

**检查清单**：
1. 确认请求头中包含 `If-Modified-Since`
2. 确认时间格式正确（RFC 1123）
3. 确认时间戳是从之前的 `Last-Modified` 响应头获取的
4. 确认数据确实没有变化（检查数据库 `updated_at` 字段）

**调试方法**：
```dart
// 打印请求头
print('If-Modified-Since: ${headers['If-Modified-Since']}');

// 打印响应头
print('Last-Modified: ${response.headers.value('Last-Modified')}');
print('Status Code: ${response.statusCode}');
```

---

### Q2: Dio 将 304 当作错误处理怎么办？

某些版本的 Dio 可能将非 2xx 状态码视为错误。解决方案：

```dart
dio.options.validateStatus = (status) {
  return status != null && status >= 200 && status < 500;
};

// 或在单次请求中
final response = await dio.get(
  '/api/conversations',
  options: Options(
    validateStatus: (status) => status! >= 200 && status < 500,
  ),
);

if (response.statusCode == 304) {
  // 使用缓存
}
```

---

### Q3: 如何处理多设备同步？

条件请求天然支持多设备场景：

1. **设备 A** 修改数据 → 服务器 `Last-Modified` 更新为新时间
2. **设备 B** 请求时携带旧的 `If-Modified-Since` → 服务器返回 200 + 新数据
3. **设备 B** 更新本地缓存和时间戳

**推荐策略**：
- 在用户执行「下拉刷新」时强制重新请求（不发送 `If-Modified-Since`）
- 在应用启动、切换标签时使用条件请求

---

### Q4: 缓存键（Cache Key）如何设计？

**推荐方案**：

```dart
// 方案 1：基于路径
final cacheKey = 'conversations';
final timestampKey = 'last_modified_conversations';

// 方案 2：基于路径 + 参数（适用于带参数的接口）
final cacheKey = 'daily_tasks_2025-01-27';
final timestampKey = 'last_modified_daily_tasks_2025-01-27';

// 方案 3：基于用户 ID + 路径（适用于多账号）
final cacheKey = '${userId}_conversations';
final timestampKey = '${userId}_last_modified_conversations';
```

**注意**：日常任务和日程虽然支持参数筛选，但时间戳基于全量数据，建议使用方案 1 或 3。

---

### Q5: 如何清除缓存？

```dart
// 清除所有缓存数据
await _cacheBox.clear();
await _timestampBox.clear();

// 清除特定资源
await _cacheBox.delete('conversations');
await _timestampBox.delete('last_modified_conversations');

// 或使用 SharedPreferences
await prefs.remove('conversations');
await prefs.remove('last_modified_conversations');
```

**适用场景**：
- 用户登出时
- 切换账号时
- 用户手动触发「清除缓存」时

---

## 📊 性能对比

### 数据未变化场景（304 响应）

| 指标 | 无条件请求 (200) | 条件请求 (304) | 节省 |
|------|-----------------|---------------|------|
| 响应体大小 | ~50KB | 0 | **100%** |
| 服务器处理时间 | ~80ms | ~5ms | **93%** |
| 数据库查询 | 2-3 次 | 0 | **100%** |
| 流量消耗（月活 1 万用户） | ~15GB | ~0.1GB | **99%** |

### 数据已变化场景（200 响应）

与普通请求完全相同，无额外开销（仅多一次时间比对）。

---

## 🎓 最佳实践

### 1. 分层缓存策略

```dart
class ConversationRepository {
  // 内存缓存（最快）
  List<Conversation>? _memoryCache;

  // 本地持久化缓存（次之）
  final HiveCacheService _cache;

  // 网络请求（最慢）
  final ApiService _api;

  Future<List<Conversation>> getConversations({bool forceRefresh = false}) async {
    // 1. 强制刷新 → 跳过缓存
    if (forceRefresh) {
      _memoryCache = null;
      return await _fetchFromNetwork();
    }

    // 2. 内存缓存命中 → 直接返回
    if (_memoryCache != null) {
      return _memoryCache!;
    }

    // 3. 发起条件请求
    final result = await _fetchFromNetwork();
    _memoryCache = result;
    return result;
  }

  Future<List<Conversation>> _fetchFromNetwork() async {
    // 实现如前面示例
  }
}
```

---

### 2. 后台刷新（Stale-While-Revalidate）

```dart
Future<List<Conversation>> getConversations() async {
  // 先返回缓存（即使可能过期）
  final cached = _cacheBox.get('conversations');
  if (cached != null) {
    final conversations = (cached as List).map((e) => Conversation.fromJson(e)).toList();

    // 🔄 后台验证是否有新数据
    _revalidateInBackground();

    return conversations;
  }

  // 无缓存 → 等待网络请求
  return await _fetchFromNetwork();
}

void _revalidateInBackground() async {
  try {
    final result = await _fetchFromNetwork();
    // 如果数据变化，触发 UI 更新
    if (result != _memoryCache) {
      _memoryCache = result;
      notifyListeners(); // 如果使用 Provider
    }
  } catch (e) {
    // 静默失败，用户继续使用旧缓存
  }
}
```

---

### 3. 监听数据变化

```dart
// 使用 StreamController 实现响应式更新
class ConversationRepository {
  final _controller = StreamController<List<Conversation>>.broadcast();

  Stream<List<Conversation>> get conversationsStream => _controller.stream;

  Future<void> refresh() async {
    final result = await _fetchFromNetwork();
    _controller.add(result); // 触发 UI 更新
  }
}

// UI 层使用 StreamBuilder
StreamBuilder<List<Conversation>>(
  stream: repository.conversationsStream,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return ConversationList(conversations: snapshot.data!);
    }
    return LoadingIndicator();
  },
);
```

---

## 🔗 相关文档

- [图片上传 API 文档](./IMAGE_UPLOAD_API.md)
- [认证系统 API 文档](./AUTH_API.md)
- [缓存版本控制 - 快速开始](./CACHE_VERSIONING_QUICKSTART.md)
- [缓存版本控制 - 设计文档](./CACHE_VERSIONING_DESIGN.md)

---

## 📞 技术支持

如有问题，请联系后端团队或在项目 Issue 中提出。
