import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:synchronized/synchronized.dart';
import 'cache_service.dart';
import 'cache_keys.dart';

/// Hive 缓存服务实现
/// 
/// 功能：
/// - 使用 Hive 作为本地 NoSQL 数据库
/// - 支持时间戳管理（过期检测）
/// - 并发锁保护（防止同时写入冲突）
/// - 完整的错误处理和日志
class HiveCacheService implements CacheService {
  static const String _boxName = 'app_cache';
  static const String _timestampSuffix = '_timestamp';
  
  Box? _box;
  final _lock = Lock();
  
  @override
  Future<void> init() async {
    try {
      // 初始化 Hive（在 main.dart 中调用 Hive.initFlutter() 后才能使用）
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox(_boxName);
        print('[HiveCacheService] Box 已打开: $_boxName');
      } else {
        _box = Hive.box(_boxName);
        print('[HiveCacheService] 使用已打开的 Box: $_boxName');
      }
      
      // 启动时清理过期缓存
      await cleanExpiredCache();
    } catch (e) {
      print('[HiveCacheService] 初始化失败: $e');
      rethrow;
    }
  }
  
  @override
  Future<T?> get<T>(String key) async {
    return await _lock.synchronized(() async {
      try {
        if (_box == null) {
          print('[HiveCacheService] Box 未初始化，调用 get($key) 失败');
          return null;
        }
        
        // 检查是否过期
        if (await isExpired(key)) {
          print('[HiveCacheService] 缓存已过期，删除: $key');
          await delete(key);
          return null;
        }
        
        final value = _box!.get(key);
        if (value == null) {
          print('[HiveCacheService] 缓存不存在: $key');
          return null;
        }
        
        print('[HiveCacheService] 读取缓存成功: $key');
        return value as T;
      } catch (e) {
        print('[HiveCacheService] 读取缓存失败: $key, 错误: $e');
        return null;
      }
    });
  }
  
  @override
  Future<void> set<T>(String key, T value) async {
    await _lock.synchronized(() async {
      try {
        if (_box == null) {
          print('[HiveCacheService] Box 未初始化，调用 set($key) 失败');
          return;
        }
        
        await _box!.put(key, value);
        await setTimestamp(key);
        print('[HiveCacheService] 写入缓存成功: $key');
      } catch (e) {
        print('[HiveCacheService] 写入缓存失败: $key, 错误: $e');
        rethrow;
      }
    });
  }
  
  @override
  Future<void> delete(String key) async {
    await _lock.synchronized(() async {
      try {
        if (_box == null) return;
        
        await _box!.delete(key);
        await _box!.delete('$key$_timestampSuffix'); // 同时删除时间戳
        print('[HiveCacheService] 删除缓存成功: $key');
      } catch (e) {
        print('[HiveCacheService] 删除缓存失败: $key, 错误: $e');
      }
    });
  }
  
  @override
  Future<void> clear() async {
    await _lock.synchronized(() async {
      try {
        if (_box == null) return;
        
        await _box!.clear();
        print('[HiveCacheService] 清空所有缓存');
      } catch (e) {
        print('[HiveCacheService] 清空缓存失败: $e');
        rethrow;
      }
    });
  }
  
  @override
  Future<List<T>> getList<T>(String key) async {
    return await _lock.synchronized(() async {
      try {
        if (_box == null) return [];
        
        // 检查是否过期
        if (await isExpired(key)) {
          print('[HiveCacheService] 列表缓存已过期，删除: $key');
          await delete(key);
          return [];
        }
        
        final value = _box!.get(key);
        if (value == null) {
          print('[HiveCacheService] 列表缓存不存在: $key');
          return [];
        }
        
        // 处理列表类型
        if (value is List) {
          print('[HiveCacheService] 读取列表缓存成功: $key, 长度: ${value.length}');
          return List<T>.from(value);
        }
        
        print('[HiveCacheService] 缓存值不是列表类型: $key');
        return [];
      } catch (e) {
        print('[HiveCacheService] 读取列表缓存失败: $key, 错误: $e');
        return [];
      }
    });
  }
  
  @override
  Future<void> setList<T>(String key, List<T> value) async {
    await _lock.synchronized(() async {
      try {
        if (_box == null) return;
        
        await _box!.put(key, value);
        await setTimestamp(key);
        print('[HiveCacheService] 写入列表缓存成功: $key, 长度: ${value.length}');
      } catch (e) {
        print('[HiveCacheService] 写入列表缓存失败: $key, 错误: $e');
        rethrow;
      }
    });
  }
  
  @override
  Future<bool> isExpired(String key) async {
    try {
      if (_box == null) return true;
      
      final timestamp = await getTimestamp(key);
      if (timestamp == null) {
        return true; // 没有时间戳视为已过期
      }
      
      final now = DateTime.now();
      final diff = now.difference(timestamp);
      
      // 根据 key 获取过期时间
      Duration maxAge;
      if (key.contains(CacheKeys.schedules)) {
        maxAge = CacheKeys.schedulesCacheMaxAge;
      } else if (key.contains(CacheKeys.dailyTasks)) {
        maxAge = CacheKeys.dailyTasksCacheMaxAge;
      } else if (key.contains(CacheKeys.conversations)) {
        maxAge = CacheKeys.conversationsCacheMaxAge;
      } else if (key.contains(CacheKeys.userProfile)) {
        maxAge = CacheKeys.userProfileCacheMaxAge;
      } else {
        maxAge = const Duration(minutes: 10); // 默认 10 分钟
      }
      
      final isExpired = diff > maxAge;
      if (isExpired) {
        print('[HiveCacheService] 缓存已过期: $key, 时间差: ${diff.inMinutes} 分钟');
      }
      
      return isExpired;
    } catch (e) {
      print('[HiveCacheService] 检查过期失败: $key, 错误: $e');
      return true; // 出错时视为已过期
    }
  }
  
  @override
  Future<DateTime?> getTimestamp(String key) async {
    try {
      if (_box == null) return null;
      
      final timestampMs = _box!.get('$key$_timestampSuffix');
      if (timestampMs == null) return null;
      
      return DateTime.fromMillisecondsSinceEpoch(timestampMs as int);
    } catch (e) {
      print('[HiveCacheService] 获取时间戳失败: $key, 错误: $e');
      return null;
    }
  }
  
  @override
  Future<void> setTimestamp(String key) async {
    try {
      if (_box == null) return;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      await _box!.put('$key$_timestampSuffix', now);
    } catch (e) {
      print('[HiveCacheService] 设置时间戳失败: $key, 错误: $e');
    }
  }
  
  @override
  Future<int> getCacheSize() async {
    try {
      if (_box == null) return 0;
      return _box!.length;
    } catch (e) {
      print('[HiveCacheService] 获取缓存大小失败: $e');
      return 0;
    }
  }
  
  @override
  Future<double> getCacheSizeMB() async {
    try {
      if (_box == null) return 0.0;
      
      // 估算大小（Hive 不直接提供字节数）
      final keys = _box!.keys;
      int totalBytes = 0;
      
      for (var key in keys) {
        final value = _box!.get(key);
        // 粗略估算：假设每个对象平均 1KB
        if (value is List) {
          totalBytes += value.length * 1024;
        } else if (value is String) {
          totalBytes += value.length;
        } else {
          totalBytes += 1024; // 默认 1KB
        }
      }
      
      return totalBytes / (1024 * 1024); // 转换为 MB
    } catch (e) {
      print('[HiveCacheService] 计算缓存大小失败: $e');
      return 0.0;
    }
  }
  
  @override
  Future<int> cleanExpiredCache() async {
    return await _lock.synchronized(() async {
      try {
        if (_box == null) return 0;
        
        final keys = _box!.keys.toList();
        int cleanedCount = 0;
        
        for (var key in keys) {
          // 跳过时间戳 key
          if (key.toString().endsWith(_timestampSuffix)) continue;
          
          if (await isExpired(key.toString())) {
            await delete(key.toString());
            cleanedCount++;
          }
        }
        
        print('[HiveCacheService] 清理过期缓存完成，删除 $cleanedCount 项');
        return cleanedCount;
      } catch (e) {
        print('[HiveCacheService] 清理过期缓存失败: $e');
        return 0;
      }
    });
  }
  
  /// 关闭 Hive Box（应用退出时调用）
  Future<void> close() async {
    try {
      if (_box != null && _box!.isOpen) {
        await _box!.close();
        print('[HiveCacheService] Box 已关闭');
      }
    } catch (e) {
      print('[HiveCacheService] 关闭 Box 失败: $e');
    }
  }
}
