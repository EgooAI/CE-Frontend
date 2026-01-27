/// 缓存服务抽象接口
///
/// 定义了应用中所有缓存操作的标准接口，支持：
/// - 单个对象的读写
/// - 列表对象的读写
/// - 缓存过期检测
/// - 缓存时间戳管理
abstract class CacheService {
  /// 初始化缓存服务
  ///
  /// 必须在使用任何其他方法前调用
  /// 通常在 main() 中调用
  Future<void> init();

  /// 获取单个缓存对象
  ///
  /// [key] 缓存键
  /// 返回：缓存的对象，如果不存在或类型不匹配则返回 null
  Future<T?> get<T>(String key);

  /// 存储单个对象到缓存
  ///
  /// [key] 缓存键
  /// [value] 要缓存的对象
  ///
  /// 自动记录缓存时间戳
  Future<void> set<T>(String key, T value);

  /// 删除指定缓存
  ///
  /// [key] 缓存键
  ///
  /// 同时删除关联的时间戳
  Future<void> delete(String key);

  /// 清空所有缓存
  ///
  /// ⚠️ 谨慎使用，会删除所有缓存数据
  Future<void> clear();

  /// 获取缓存列表
  ///
  /// [key] 缓存键
  /// 返回：缓存的列表，如果不存在则返回空列表
  Future<List<T>> getList<T>(String key);

  /// 存储列表到缓存
  ///
  /// [key] 缓存键
  /// [items] 要缓存的列表
  ///
  /// 自动记录缓存时间戳
  Future<void> setList<T>(String key, List<T> items);

  /// 检查缓存是否已过期
  ///
  /// [key] 缓存键
  ///
  /// 返回：true 表示已过期或不存在，false 表示仍有效
  /// 实现自动从 CacheKeys 查找过期时间
  Future<bool> isExpired(String key);

  /// 获取缓存的时间戳
  ///
  /// [key] 缓存键
  /// 返回：缓存时间，如果不存在则返回 null
  Future<DateTime?> getTimestamp(String key);

  /// 设置缓存时间戳（自动使用当前时间）
  ///
  /// [key] 缓存键
  ///
  /// 通常由 set/setList 自动调用，不需要手动调用
  Future<void> setTimestamp(String key);

  /// 刷新缓存的 TTL（不修改数据，仅更新时间戳）
  ///
  /// [key] 缓存键
  ///
  /// 用于条件请求返回 304 时，数据未变化但需要延长缓存有效期
  Future<void> refreshTTL(String key);

  /// 获取缓存大小（条目数量）
  ///
  /// 返回：缓存中的键值对数量
  Future<int> getCacheSize();

  /// 获取缓存占用的磁盘空间（MB）
  ///
  /// 返回：缓存文件大小（单位：MB）
  Future<double> getCacheSizeMB();

  /// 清理过期缓存
  ///
  /// 根据 CacheKeys 定义的过期时间，删除所有过期缓存
  /// 返回：清理的条目数量
  Future<int> cleanExpiredCache();
}
