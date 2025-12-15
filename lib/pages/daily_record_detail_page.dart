import 'package:flutter/material.dart';
import '../models/daily_task.dart';
import '../services/daily_task_service.dart';

/// 日常任务详细记录页面
class DailyRecordDetailPage extends StatefulWidget {
  final DailyTask task;

  const DailyRecordDetailPage({super.key, required this.task});

  @override
  State<DailyRecordDetailPage> createState() => _DailyRecordDetailPageState();
}

class _DailyRecordDetailPageState extends State<DailyRecordDetailPage> {
  final DailyTaskService _service = DailyTaskService();
  late Future<DailyTaskStats?> _statsFuture;
  late Future<List<DailyTaskLog>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
    _logsFuture = _service.getDailyTaskLogs(widget.task.id, days: 30);
  }

  Future<DailyTaskStats?> _loadStats() async {
    try {
      return await _service.getDailyTaskStats(widget.task.id);
    } catch (e) {
      debugPrint('Failed to load stats: $e');
      return null;
    }
  }

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

  String _formatLogDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final logDate = DateTime(date.year, date.month, date.day);

    if (logDate == today) {
      return '今天';
    } else if (logDate == yesterday) {
      return '昨天';
    } else {
      return '${date.month}月${date.day}日';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.task.title), elevation: 0),
      body: FutureBuilder<DailyTaskStats?>(
        future: _statsFuture,
        builder: (context, statsSnapshot) {
          final stats = statsSnapshot.data;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 任务信息和统计卡片
                _buildHeaderCard(stats),

                // 打卡日历网格
                _buildLogGridSection(),

                // 坚持统计
                _buildConsecutiveStats(),

                // 打卡记录列表
                _buildLogListSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(DailyTaskStats? stats) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 任务基本信息
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _parseColor(widget.task.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.task.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.task.description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          widget.task.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 统计指标
          Row(
            children: [
              _StatCard(
                label: '完成率',
                value: '${stats?.completionRate ?? 0}%',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: '连续天数',
                value: '${stats?.consecutiveDays ?? 0}',
                icon: Icons.local_fire_department,
                color: Colors.orange,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: '本月完成',
                value: '${stats?.monthCompleted ?? 0}',
                icon: Icons.calendar_today,
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogGridSection() {
    return FutureBuilder<List<DailyTaskLog>>(
      future: _logsFuture,
      builder: (context, logsSnapshot) {
        if (logsSnapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }

        if (logsSnapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('加载失败: ${logsSnapshot.error}'),
          );
        }

        final logs = logsSnapshot.data ?? [];
        if (logs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '最近30天打卡情况',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              _BuildLogGrid(logs: logs),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConsecutiveStats() {
    return FutureBuilder<List<DailyTaskLog>>(
      future: _logsFuture,
      builder: (context, logsSnapshot) {
        if (logsSnapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }

        final logs = logsSnapshot.data ?? [];
        if (logs.isEmpty) {
          return const SizedBox.shrink();
        }

        // 计算连续天数和未打卡天数
        final now = DateTime.now();
        int consecutiveDays = 0;
        int lastMissedDays = 0;

        for (int i = 0; i < 30; i++) {
          final checkDate = now.subtract(Duration(days: i));
          final hasLog = logs.any(
            (log) =>
                log.date.year == checkDate.year &&
                log.date.month == checkDate.month &&
                log.date.day == checkDate.day &&
                log.completed,
          );

          if (hasLog) {
            consecutiveDays++;
          } else {
            if (consecutiveDays > 0) {
              break;
            }
            lastMissedDays++;
          }
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[200]!, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.whatshot, color: Colors.orange[700], size: 28),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '坚持了 $consecutiveDays 天',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[800],
                    ),
                  ),
                  if (lastMissedDays > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '最近 $lastMissedDays 天未打卡',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[600],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogListSection() {
    return FutureBuilder<List<DailyTaskLog>>(
      future: _logsFuture,
      builder: (context, logsSnapshot) {
        if (logsSnapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }

        if (logsSnapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('加载失败: ${logsSnapshot.error}'),
          );
        }

        final logs = logsSnapshot.data ?? [];
        if (logs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text('暂无打卡记录', style: TextStyle(color: Colors.grey[600])),
            ),
          );
        }

        // 按日期倒序排列
        final sortedLogs = List<DailyTaskLog>.from(logs)
          ..sort((a, b) => b.date.compareTo(a.date));

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '打卡记录详情',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              ...sortedLogs.map((log) {
                return _buildLogItem(log);
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogItem(DailyTaskLog log) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                log.completed ? Icons.check_circle : Icons.cancel,
                color: log.completed ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formatLogDate(log.date),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (log.note != null && log.note!.isNotEmpty)
                Icon(Icons.note, color: Colors.blue[400], size: 18),
            ],
          ),
          if (log.note != null && log.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 32),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!, width: 1),
                ),
                child: Text(
                  log.note!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[800],
                    height: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 单个统计卡片
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

/// 打卡日历网格
class _BuildLogGrid extends StatelessWidget {
  final List<DailyTaskLog> logs;

  const _BuildLogGrid({required this.logs});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = <(DateTime, bool)>[];

    for (int i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final completed = logs.any(
        (log) =>
            log.date.year == date.year &&
            log.date.month == date.month &&
            log.date.day == date.day &&
            log.completed,
      );
      days.add((date, completed));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: days.map((item) {
        final date = item.$1;
        final completed = item.$2;
        final isToday =
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;

        return Tooltip(
          message: '${date.month}月${date.day}日${completed ? '✓ 已完成' : '未完成'}',
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: completed ? Colors.green[400] : Colors.grey[300],
              border: isToday ? Border.all(color: Colors.blue, width: 2) : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: completed || isToday ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
