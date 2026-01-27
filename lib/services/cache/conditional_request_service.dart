import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

/// HTTP 条件请求服务
///
/// 实现基于 If-Modified-Since 和 Last-Modified 的缓存策略
/// 遵循 HTTP/1.1 标准，自动处理 304 Not Modified 响应
///
/// 使用场景：
/// - 会话列表 GET /api/conversations
/// - 会话详情 GET /api/conversations/:id
/// - 日常任务 GET /api/daily-tasks
/// - 日程列表 GET /api/schedules
///
/// 工作流程：
/// 1. 请求前：读取本地保存的 Last-Modified 时间戳，添加到 If-Modified-Since 请求头
/// 2. 响应后：保存服务器返回的 Last-Modified 到本地
/// 3. 304 响应：数据未变化，使用本地缓存
/// 4. 200 响应：数据已更新，覆盖本地缓存
class ConditionalRequestService {
  static const String _boxName = 'conditional_request_timestamps';
  static Box<String>? _timestampBox;

  /// 初始化服务
  static Future<void> init() async {
    if (_timestampBox == null || !_timestampBox!.isOpen) {
      _timestampBox = await Hive.openBox<String>(_boxName);
      print('[ConditionalRequestService] ✅ 时间戳存储已初始化');
    }
  }

  /// 获取 Dio 拦截器实例
  static Interceptor getInterceptor() {
    return InterceptorsWrapper(
      onRequest: _onRequest,
      onResponse: _onResponse,
      onError: _onError,
    );
  }

  /// 请求拦截：添加 If-Modified-Since 头
  static void _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 确保初始化
    await init();

    // 允许单次请求跳过条件请求
    if (options.extra['skipConditionalRequest'] == true) {
      handler.next(options);
      return;
    }

    // 仅对支持条件请求的接口添加头
    if (_isSupportedEndpoint(options.path) && options.method == 'GET') {
      final cacheKey = _buildCacheKey(options);
      final lastModified = _timestampBox!.get(cacheKey);

      if (lastModified != null) {
        options.headers['If-Modified-Since'] = lastModified;
        print(
          '[ConditionalRequest] 📤 添加 If-Modified-Since: $lastModified (${options.path})',
        );
      }
    }

    handler.next(options);
  }

  /// 响应拦截：保存 Last-Modified 头
  static void _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    await init();

    // 允许单次请求跳过条件请求
    if (response.requestOptions.extra['skipConditionalRequest'] == true) {
      handler.next(response);
      return;
    }

    final path = response.requestOptions.path;
    if (_isSupportedEndpoint(path)) {
      final lastModified =
          response.headers.value('Last-Modified') ??
          response.headers.value('last-modified');

      if (lastModified != null) {
        final cacheKey = _buildCacheKey(response.requestOptions);
        await _timestampBox!.put(cacheKey, lastModified);
        print(
          '[ConditionalRequest] 💾 保存 Last-Modified: $lastModified (${path})',
        );
      }

      // 处理 304 Not Modified
      if (response.statusCode == 304) {
        print('[ConditionalRequest] ✅ 304 Not Modified - 数据未变化');
        // 标记为 304，让 Repository 知道使用缓存
        response.data = {'_isNotModified': true};
      }
    }

    handler.next(response);
  }

  /// 错误拦截：处理 Dio 将 304 当作错误的情况
  static void _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (error.response?.statusCode == 304) {
      print('[ConditionalRequest] ✅ 304 Not Modified (从错误恢复)');
      // 将 304 转换为正常响应
      final response = error.response!;
      response.data = {'_isNotModified': true};
      handler.resolve(response);
      return;
    }

    handler.next(error);
  }

  /// 判断是否支持条件请求
  static bool _isSupportedEndpoint(String path) {
    final normalized = _normalizePath(path);
    return normalized.startsWith('conversations') ||
        normalized.startsWith('daily-tasks') ||
        normalized.startsWith('schedules');
  }

  /// 构建缓存键
  ///
  /// 规则：
  /// - 基础路径 + 查询参数（按键排序）
  /// - 例如：/api/conversations?limit=50 -> conversations_limit=50
  static String _buildCacheKey(RequestOptions options) {
    String key = _normalizePath(options.path).replaceAll('/', '_');

    // 添加查询参数（排序后拼接）
    if (options.queryParameters.isNotEmpty) {
      final sortedParams = options.queryParameters.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final paramsStr = sortedParams
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      key += '_$paramsStr';
    }

    return key;
  }

  /// 清除特定路径的时间戳
  static Future<void> clearTimestamp(String path) async {
    await init();
    final key = _normalizePath(path).replaceAll('/', '_');
    await _timestampBox!.delete(key);
    print('[ConditionalRequest] 🗑️ 已清除时间戳: $key');
  }

  /// 清除所有时间戳
  static Future<void> clearAllTimestamps() async {
    await init();
    await _timestampBox!.clear();
    print('[ConditionalRequest] 🗑️ 已清除所有时间戳');
  }

  /// 获取时间戳（调试用）
  static Future<String?> getTimestamp(String path) async {
    await init();
    final key = _normalizePath(path).replaceAll('/', '_');
    return _timestampBox!.get(key);
  }

  /// 规范化路径：兼容 baseUrl 已包含 /api 的情况
  static String _normalizePath(String path) {
    var normalized = path;
    if (normalized.startsWith('/api/')) {
      normalized = normalized.substring(5);
    } else if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  /// 检查响应是否为 304 Not Modified
  static bool isNotModified(Response response) {
    return response.statusCode == 304 ||
        (response.data is Map &&
            (response.data as Map).containsKey('_isNotModified'));
  }
}
