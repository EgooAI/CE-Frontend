import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../repositories/schedule_repository.dart';
import '../../repositories/daily_task_repository.dart';
import '../../repositories/conversation_repository.dart';
import '../../services/cache/cache_keys.dart';
import '../../models/sync/sync_task.dart';
import 'cache_details_page.dart';

/// 缓存管理页面
///
/// 显示缓存统计信息，提供清理功能。
class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({super.key});

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage> {
  final _scheduleRepo = ScheduleRepository();
  final _dailyTaskRepo = DailyTaskRepository();
  final _conversationRepo = ConversationRepository();

  bool _isLoading = true;
  Map<String, dynamic> _cacheStats = {};

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  /// 加载缓存统计信息
  Future<void> _loadCacheStats() async {
    setState(() => _isLoading = true);

    try {
      final stats = <String, dynamic>{};

      // 读取实际使用的缓存 Box：app_cache（业务缓存） + sync_queue（离线队列）
      Box? appCacheBox;
      Box<SyncTask>? syncQueueBox;

      if (Hive.isBoxOpen('app_cache')) {
        appCacheBox = Hive.box('app_cache');
      }
      if (Hive.isBoxOpen('sync_queue')) {
        syncQueueBox = Hive.box<SyncTask>('sync_queue');
      }

      // 统计分类：基于键前缀聚合（忽略 *_timestamp 键）
      int scheduleEntries = 0;
      int scheduleSizeKB = 0;
      int dailyEntries = 0;
      int dailySizeKB = 0;
      int convEntries = 0;
      int convSizeKB = 0;

      if (appCacheBox != null) {
        for (final key in appCacheBox.keys) {
          if (key is! String) continue;
          if (key.endsWith('_timestamp')) continue; // 跳过时间戳

          final value = appCacheBox.get(key);
          final size = _estimateEntrySize(value);

          // 日程相关
          if (key.startsWith(CacheKeys.schedules) ||
              key.startsWith(CacheKeys.scheduleDetail)) {
            scheduleEntries += 1;
            scheduleSizeKB += size;
            continue;
          }

          // 日常任务相关
          if (key.startsWith(CacheKeys.dailyTasks) ||
              key.startsWith(CacheKeys.dailyTaskDetail)) {
            dailyEntries += 1;
            dailySizeKB += size;
            continue;
          }

          // 会话相关
          if (key.startsWith(CacheKeys.conversations) ||
              key.startsWith(CacheKeys.conversationDetail) ||
              key.startsWith(CacheKeys.conversationMessages)) {
            convEntries += 1;
            convSizeKB += size;
            continue;
          }
        }
      }

      // Schedule 缓存统计
      stats['schedule'] = {'entries': scheduleEntries, 'size': scheduleSizeKB};

      // DailyTask 缓存统计
      stats['dailyTask'] = {'entries': dailyEntries, 'size': dailySizeKB};

      // Conversation 缓存统计
      stats['conversation'] = {'entries': convEntries, 'size': convSizeKB};

      // SyncQueue 统计（独立 Box）
      final syncEntries = syncQueueBox?.length ?? 0;
      final syncSizeKB = (syncQueueBox != null)
          ? _estimateBoxSize(syncQueueBox)
          : 0;
      stats['syncQueue'] = {'entries': syncEntries, 'size': syncSizeKB};

      // 总计
      final totalEntries =
          scheduleEntries + dailyEntries + convEntries + syncEntries;
      final totalSize = scheduleSizeKB + dailySizeKB + convSizeKB + syncSizeKB;
      stats['total'] = {'entries': totalEntries, 'size': totalSize};

      setState(() {
        _cacheStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载缓存统计失败: $e');
      setState(() => _isLoading = false);
    }
  }

  /// 估算单个缓存条目大小（KB）
  int _estimateEntrySize(dynamic value) {
    try {
      if (value is List) {
        return value.length * 2; // 粗略估算：每项约 2KB
      }
      return 2; // 非列表按 2KB 估算
    } catch (_) {
      return 2;
    }
  }

  /// 估算 Box 大小（KB）
  int _estimateBoxSize(Box box) {
    try {
      // 粗略估算：每个条目约 1-2KB
      return box.length * 2;
    } catch (e) {
      return 0;
    }
  }

  /// 清空所有缓存
  Future<void> _clearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空缓存'),
        content: const Text('这将删除所有本地缓存数据，包括未同步的离线操作。\n\n是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // 清空所有仓储缓存
      await _scheduleRepo.clearCache();
      await _dailyTaskRepo.clearCache();
      await _conversationRepo.clearCache();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('缓存已清空')));
        _loadCacheStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('清空失败: $e')));
      }
    }
  }

  /// 清空过期缓存
  Future<void> _clearExpiredCache() async {
    try {
      // 清空过期缓存（7天前）
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      int totalCleaned = 0;

      // Schedule 缓存
      if (Hive.isBoxOpen('scheduleCache')) {
        final scheduleBox = Hive.box('scheduleCache');
        final scheduleKeys = scheduleBox.keys.where((key) {
          final entry = scheduleBox.get(key);
          if (entry is Map && entry['cachedAt'] != null) {
            final cachedAt = DateTime.parse(entry['cachedAt']);
            return cachedAt.isBefore(cutoff);
          }
          return false;
        }).toList();
        await scheduleBox.deleteAll(scheduleKeys);
        totalCleaned += scheduleKeys.length;
      }

      // DailyTask 缓存
      if (Hive.isBoxOpen('dailyTaskCache')) {
        final dailyBox = Hive.box('dailyTaskCache');
        final dailyKeys = dailyBox.keys.where((key) {
          final entry = dailyBox.get(key);
          if (entry is Map && entry['cachedAt'] != null) {
            final cachedAt = DateTime.parse(entry['cachedAt']);
            return cachedAt.isBefore(cutoff);
          }
          return false;
        }).toList();
        await dailyBox.deleteAll(dailyKeys);
        totalCleaned += dailyKeys.length;
      }

      // Conversation 缓存
      if (Hive.isBoxOpen('conversationCache')) {
        final convBox = Hive.box('conversationCache');
        final convKeys = convBox.keys.where((key) {
          final entry = convBox.get(key);
          if (entry is Map && entry['cachedAt'] != null) {
            final cachedAt = DateTime.parse(entry['cachedAt']);
            return cachedAt.isBefore(cutoff);
          }
          return false;
        }).toList();
        await convBox.deleteAll(convKeys);
        totalCleaned += convKeys.length;
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已清理 $totalCleaned 条过期缓存')));
        _loadCacheStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('清理失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('缓存管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCacheStats,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 总览卡片
                _buildOverviewCard(),
                const SizedBox(height: 16),

                // 详细统计
                _buildCategoryCard(
                  '日程缓存',
                  'schedule',
                  Icons.calendar_today,
                  Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildCategoryCard(
                  '日常任务缓存',
                  'dailyTask',
                  Icons.task,
                  Colors.green,
                ),
                const SizedBox(height: 12),
                _buildCategoryCard(
                  '对话缓存',
                  'conversation',
                  Icons.chat,
                  Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildCategoryCard(
                  '同步队列',
                  'syncQueue',
                  Icons.sync,
                  Colors.purple,
                ),
                const SizedBox(height: 24),

                // 操作按钮
                ElevatedButton.icon(
                  onPressed: _clearExpiredCache,
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('清理过期缓存 (>7天)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _clearAllCache,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('清空所有缓存'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
    );
  }

  /// 总览卡片
  Widget _buildOverviewCard() {
    final total = _cacheStats['total'] ?? {'entries': 0, 'size': 0};

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.storage, size: 48, color: Colors.blue),
            const SizedBox(height: 12),
            const Text(
              '缓存总览',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('条目数', '${total['entries']}', Icons.file_copy),
                _buildStatItem('大小', '${total['size']} KB', Icons.data_usage),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 分类统计卡片
  Widget _buildCategoryCard(
    String title,
    String key,
    IconData icon,
    Color color,
  ) {
    final stats = _cacheStats[key] ?? {'entries': 0, 'size': 0};

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text('${stats['entries']} 条目 • ${stats['size']} KB'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CacheDetailsPage(
                category: key,
                title: title,
                icon: icon,
                color: color,
              ),
            ),
          );
        },
      ),
    );
  }

  /// 统计项
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.grey[600]),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ],
    );
  }
}
