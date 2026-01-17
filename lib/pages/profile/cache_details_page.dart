import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/sync/sync_task.dart';
import '../../services/cache/cache_keys.dart';

/// 缓存详情页面
///
/// 显示指定分类下的所有缓存条目列表，支持删除和查看详情。
class CacheDetailsPage extends StatefulWidget {
  final String category; // schedule, dailyTask, conversation, syncQueue
  final String title; // 显示标题
  final IconData icon;
  final Color color;

  const CacheDetailsPage({
    super.key,
    required this.category,
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  State<CacheDetailsPage> createState() => _CacheDetailsPageState();
}

class _CacheDetailsPageState extends State<CacheDetailsPage> {
  List<_CacheEntry> _entries = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCacheEntries();
  }

  /// 加载缓存条目
  Future<void> _loadCacheEntries() async {
    setState(() => _isLoading = true);

    try {
      final entries = <_CacheEntry>[];

      if (widget.category == 'syncQueue') {
        // 处理同步队列（特殊的 Box<SyncTask>）
        if (Hive.isBoxOpen('sync_queue')) {
          final syncBox = Hive.box<SyncTask>('sync_queue');
          for (int i = 0; i < syncBox.length; i++) {
            final key = syncBox.keyAt(i);
            final value = syncBox.getAt(i);
            entries.add(
              _CacheEntry(
                key: key.toString(),
                value: value,
                size: _estimateSize(value),
              ),
            );
          }
        }
      } else {
        // 处理其他缓存（都在 app_cache 中）
        if (Hive.isBoxOpen('app_cache')) {
          final appCache = Hive.box('app_cache');

          for (final key in appCache.keys) {
            if (key is! String) continue;
            if (key.endsWith('_timestamp')) continue; // 跳过时间戳

            // 按分类筛选
            bool matches = false;
            switch (widget.category) {
              case 'schedule':
                matches =
                    key.startsWith(CacheKeys.schedules) ||
                    key.startsWith(CacheKeys.scheduleDetail);
                break;
              case 'dailyTask':
                matches =
                    key.startsWith(CacheKeys.dailyTasks) ||
                    key.startsWith(CacheKeys.dailyTaskDetail);
                break;
              case 'conversation':
                matches =
                    key.startsWith(CacheKeys.conversations) ||
                    key.startsWith(CacheKeys.conversationDetail) ||
                    key.startsWith(CacheKeys.conversationMessages);
                break;
            }

            if (matches) {
              final value = appCache.get(key);
              entries.add(
                _CacheEntry(key: key, value: value, size: _estimateSize(value)),
              );
            }
          }
        }
      }

      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载缓存条目失败: $e');
      setState(() => _isLoading = false);
    }
  }

  /// 估算大小（KB）
  int _estimateSize(dynamic value) {
    try {
      if (value is List) {
        return (value.length * 2).clamp(1, 999);
      }
      return 2;
    } catch (_) {
      return 2;
    }
  }

  /// 删除单条缓存
  Future<void> _deleteEntry(_CacheEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除这条缓存吗？\n\nKey: ${entry.key}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (widget.category == 'syncQueue') {
        if (Hive.isBoxOpen('sync_queue')) {
          await Hive.box<SyncTask>('sync_queue').delete(entry.key);
        }
      } else {
        if (Hive.isBoxOpen('app_cache')) {
          await Hive.box('app_cache').delete(entry.key);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已删除')));
        _loadCacheEntries();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  /// 获取筛选后的条目列表
  List<_CacheEntry> _getFilteredEntries() {
    if (_searchQuery.isEmpty) {
      return _entries;
    }
    return _entries
        .where(
          (entry) =>
              entry.key.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  /// 显示条目详情
  void _showEntryDetails(_CacheEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('缓存详情'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Key', entry.key),
              const SizedBox(height: 12),
              _buildDetailRow('大小', '${entry.size} KB'),
              const SizedBox(height: 12),
              const Text(
                'Value:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatValue(entry.value),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 格式化值为字符串
  String _formatValue(dynamic value) {
    try {
      if (value is SyncTask) {
        return 'SyncTask(id: ${value.id}, operation: ${value.operation})';
      } else if (value is List) {
        return value.toString();
      } else if (value is Map) {
        return value.toString();
      }
      return value.toString();
    } catch (_) {
      return '[无法解析]';
    }
  }

  /// 构建详情行
  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _getFilteredEntries();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCacheEntries,
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: '搜索键名...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          // 缓存列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredEntries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty ? '暂无缓存' : '未找到匹配的缓存',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      return _buildEntryTile(entry);
                    },
                  ),
          ),

          // 统计信息
          if (filteredEntries.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('条目数', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '${filteredEntries.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('总大小', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '${filteredEntries.fold<int>(0, (sum, e) => sum + e.size)} KB',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 构建条目 Tile
  Widget _buildEntryTile(_CacheEntry entry) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(
          entry.key,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: Text('${entry.size} KB'),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Text('查看详情'),
              onTap: () {
                Future.microtask(() => _showEntryDetails(entry));
              },
            ),
            PopupMenuItem(
              child: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Future.microtask(() => _deleteEntry(entry));
              },
            ),
          ],
        ),
        onTap: () => _showEntryDetails(entry),
      ),
    );
  }
}

/// 缓存条目数据类
class _CacheEntry {
  final String key;
  final dynamic value;
  final int size;

  _CacheEntry({required this.key, required this.value, required this.size});
}
