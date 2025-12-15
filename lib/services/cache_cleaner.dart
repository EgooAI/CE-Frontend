import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 缓存清理服务
///
/// 负责清理过期的本地缓存，释放存储空间。
class CacheCleaner {
  /// 清理过期缓存（默认 7 天）
  ///
  /// [daysThreshold] 过期天数阈值，默认 7 天
  /// 返回清理的条目数量
  static Future<int> cleanExpiredCache({int daysThreshold = 7}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: daysThreshold));
      int totalCleaned = 0;

      // 清理 Schedule 缓存（如果 Box 已打开）
      try {
        if (Hive.isBoxOpen('scheduleCache')) {
          final scheduleBox = Hive.box('scheduleCache');
          final scheduleKeys = scheduleBox.keys.where((key) {
            try {
              final entry = scheduleBox.get(key);
              if (entry is Map && entry['cachedAt'] != null) {
                final cachedAt = DateTime.parse(entry['cachedAt']);
                return cachedAt.isBefore(cutoff);
              }
            } catch (e) {
              debugPrint('解析 Schedule 缓存时间失败: $e');
            }
            return false;
          }).toList();
          await scheduleBox.deleteAll(scheduleKeys);
          totalCleaned += scheduleKeys.length;
        }
      } catch (e) {
        debugPrint('⚠️ 清理 Schedule 缓存失败: $e');
      }

      // 清理 DailyTask 缓存（如果 Box 已打开）
      try {
        if (Hive.isBoxOpen('dailyTaskCache')) {
          final dailyBox = Hive.box('dailyTaskCache');
          final dailyKeys = dailyBox.keys.where((key) {
            try {
              final entry = dailyBox.get(key);
              if (entry is Map && entry['cachedAt'] != null) {
                final cachedAt = DateTime.parse(entry['cachedAt']);
                return cachedAt.isBefore(cutoff);
              }
            } catch (e) {
              debugPrint('解析 DailyTask 缓存时间失败: $e');
            }
            return false;
          }).toList();
          await dailyBox.deleteAll(dailyKeys);
          totalCleaned += dailyKeys.length;
        }
      } catch (e) {
        debugPrint('⚠️ 清理 DailyTask 缓存失败: $e');
      }

      // 清理 Conversation 缓存（如果 Box 已打开）
      try {
        if (Hive.isBoxOpen('conversationCache')) {
          final convBox = Hive.box('conversationCache');
          final convKeys = convBox.keys.where((key) {
            try {
              final entry = convBox.get(key);
              if (entry is Map && entry['cachedAt'] != null) {
                final cachedAt = DateTime.parse(entry['cachedAt']);
                return cachedAt.isBefore(cutoff);
              }
            } catch (e) {
              debugPrint('解析 Conversation 缓存时间失败: $e');
            }
            return false;
          }).toList();
          await convBox.deleteAll(convKeys);
          totalCleaned += convKeys.length;
        }
      } catch (e) {
        debugPrint('⚠️ 清理 Conversation 缓存失败: $e');
      }

      debugPrint('✅ 缓存清理完成：删除 $totalCleaned 条过期缓存（>$daysThreshold 天）');
      return totalCleaned;
    } catch (e) {
      debugPrint('❌ 缓存清理失败: $e');
      return 0;
    }
  }

  /// 清理超大缓存（避免存储空间不足）
  ///
  /// [maxSizeKB] 最大缓存大小（KB），默认 50MB
  /// 返回是否成功
  static Future<bool> cleanOversizedCache({int maxSizeKB = 50 * 1024}) async {
    try {
      int totalSize = 0;

      // 检查总缓存大小（仅检查已打开的 Box）
      if (Hive.isBoxOpen('scheduleCache')) {
        final scheduleBox = Hive.box('scheduleCache');
        totalSize += scheduleBox.length * 2; // 粗略估算：每个条目约 2KB
        await _cleanOldestEntries(scheduleBox, 0.2);
      }

      if (Hive.isBoxOpen('dailyTaskCache')) {
        final dailyBox = Hive.box('dailyTaskCache');
        totalSize += dailyBox.length * 2;
        await _cleanOldestEntries(dailyBox, 0.2);
      }

      if (Hive.isBoxOpen('conversationCache')) {
        final convBox = Hive.box('conversationCache');
        totalSize += convBox.length * 2;
        await _cleanOldestEntries(convBox, 0.2);
      }

      if (totalSize > maxSizeKB) {
        debugPrint('⚠️ 缓存超出限制 ($totalSize KB > $maxSizeKB KB)，已执行清理');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ 超大缓存清理失败: $e');
      return false;
    }
  }

  /// 清理最旧的条目
  ///
  /// [box] Hive Box
  /// [ratio] 清理比例（0.0-1.0），例如 0.2 表示删除最旧的 20%
  static Future<void> _cleanOldestEntries(Box box, double ratio) async {
    try {
      // 获取所有条目及其时间戳
      final entries = <dynamic, DateTime>{};
      for (final key in box.keys) {
        try {
          final entry = box.get(key);
          if (entry is Map && entry['cachedAt'] != null) {
            entries[key] = DateTime.parse(entry['cachedAt']);
          }
        } catch (_) {}
      }

      // 按时间排序，删除最旧的条目
      final sortedEntries = entries.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      final deleteCount = (sortedEntries.length * ratio).ceil();
      final keysToDelete = sortedEntries
          .take(deleteCount)
          .map((e) => e.key)
          .toList();

      await box.deleteAll(keysToDelete);
      debugPrint('  删除 ${keysToDelete.length} 条旧缓存');
    } catch (e) {
      debugPrint('  清理旧条目失败: $e');
    }
  }
}
