import 'package:flutter/material.dart';
import '../../../models/daily/daily_task.dart';
import '../../../repositories/daily_task_repository.dart';
import '../../../services/daily/daily_task_service.dart';
import 'daily_record_detail_page.dart';

/// 日常记录页面 - 展示所有日常任务列表
class DailyRecordsPage extends StatefulWidget {
  const DailyRecordsPage({super.key});

  @override
  State<DailyRecordsPage> createState() => _DailyRecordsPageState();
}

class _DailyRecordsPageState extends State<DailyRecordsPage> {
  final DailyTaskRepository _repo = DailyTaskRepository();
  final DailyTaskService _service = DailyTaskService();

  bool _isLoading = true;
  String? _errorMessage;
  List<DailyTask> _tasks = [];
  Map<String, DailyTaskStats> _statsMap = {};

  @override
  void initState() {
    super.initState();
    _load(forceRefresh: false);
  }

  Future<void> _load({required bool forceRefresh}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 同时拉 active 和 paused，合并后展示全部任务
      final results = await Future.wait([
        _repo.getDailyTasks(status: 'active', forceRefresh: forceRefresh),
        _repo.getDailyTasks(status: 'paused', forceRefresh: forceRefresh),
      ]);
      final tasks = [...results[0], ...results[1]];

      // 并发加载统计信息
      final statsEntries = await Future.wait(
        tasks.map((task) async {
          try {
            final stats = await _service.getDailyTaskStats(task.id);
            return MapEntry(task.id, stats);
          } catch (_) {
            return null;
          }
        }),
      );

      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _statsMap = Map.fromEntries(
          statsEntries.whereType<MapEntry<String, DailyTaskStats>>(),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('日常记录'), elevation: 0),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('加载失败: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _load(forceRefresh: true),
              child: const Text('重新加载'),
            ),
          ],
        ),
      );
    }

    if (_tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(forceRefresh: true),
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.checklist, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('暂无日常任务', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return _DailyTaskCard(
            task: task,
            stats: _statsMap[task.id],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DailyRecordDetailPage(task: task),
                ),
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
