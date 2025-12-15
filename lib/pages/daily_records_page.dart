import 'package:flutter/material.dart';
import '../models/daily_task.dart';
import '../services/daily_task_service.dart';
import 'daily_record_detail_page.dart';

/// 日常记录页面 - 展示所有日常任务列表
class DailyRecordsPage extends StatefulWidget {
  const DailyRecordsPage({super.key});

  @override
  State<DailyRecordsPage> createState() => _DailyRecordsPageState();
}

class _DailyRecordsPageState extends State<DailyRecordsPage> {
  final DailyTaskService _service = DailyTaskService();
  late Future<List<DailyTask>> _tasksFuture;
  late Future<Map<String, DailyTaskStats>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _tasksFuture = _service.getDailyTasks();
    _statsFuture = _loadAllStats();
  }

  Future<Map<String, DailyTaskStats>> _loadAllStats() async {
    try {
      final tasks = await _tasksFuture;
      final statsMap = <String, DailyTaskStats>{};
      for (final task in tasks) {
        try {
          final stats = await _service.getDailyTaskStats(task.id);
          statsMap[task.id] = stats;
        } catch (e) {
          debugPrint('Failed to load stats for task ${task.id}: $e');
        }
      }
      return statsMap;
    } catch (e) {
      debugPrint('Failed to load all stats: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('日常记录'), elevation: 0),
      body: FutureBuilder<List<DailyTask>>(
        future: _tasksFuture,
        builder: (context, tasksSnapshot) {
          if (tasksSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (tasksSnapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('加载失败: ${tasksSnapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _tasksFuture = _service.getDailyTasks();
                        _statsFuture = _loadAllStats();
                      });
                    },
                    child: const Text('重新加载'),
                  ),
                ],
              ),
            );
          }

          final tasks = tasksSnapshot.data ?? [];
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('暂无日常任务', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return FutureBuilder<Map<String, DailyTaskStats>>(
            future: _statsFuture,
            builder: (context, statsSnapshot) {
              final statsMap = statsSnapshot.data ?? {};

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final stats = statsMap[task.id];

                  return _DailyTaskCard(
                    task: task,
                    stats: stats,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DailyRecordDetailPage(task: task),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// 日常任务卡片 - 可点击进入详情
class _DailyTaskCard extends StatelessWidget {
  final DailyTask task;
  final DailyTaskStats? stats;
  final VoidCallback? onTap;

  const _DailyTaskCard({required this.task, this.stats, this.onTap});

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) {
      return Colors.blue;
    }
    var value = colorHex.toLowerCase().replaceAll('#', '');
    if (value.startsWith('0x')) {
      value = value.substring(2);
    }
    if (value.length == 6) {
      value = 'ff$value';
    }
    if (value.length != 8) {
      return Colors.blue;
    }
    try {
      return Color(int.parse(value, radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 任务标题和描述
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _parseColor(task.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (task.description != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              task.description!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 16),
              // 统计信息
              Row(
                children: [
                  _StatItem(
                    icon: Icons.check_circle,
                    label: '完成率',
                    value: '${stats?.completionRate ?? 0}%',
                    color: Colors.green,
                  ),
                  const SizedBox(width: 16),
                  _StatItem(
                    icon: Icons.local_fire_department,
                    label: '连续天数',
                    value: '${stats?.consecutiveDays ?? 0}天',
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 16),
                  _StatItem(
                    icon: Icons.calendar_today,
                    label: '本月完成',
                    value:
                        '${stats?.monthCompleted ?? 0}/${stats?.monthTotal ?? 0}',
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 统计数据显示项
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
