import 'package:flutter/material.dart';
import '../../models/schedule/reminder.dart';
import '../../services/schedule/reminder_service.dart';
import '../../utils/app_keys.dart';

/// 提醒列表页面
class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  final ReminderService _reminderService = ReminderService();
  bool _isLoading = true;
  String? _errorMessage;
  List<Reminder> _reminders = [];
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _reminderService.getReminders();

      // 按照提醒时间距离当前时间升序排序（最接近当前时间的排在前面）
      final now = DateTime.now();
      final sortedReminders = response.reminders
        ..sort((a, b) {
          final diffA = a.remindAt.difference(now).abs();
          final diffB = b.remindAt.difference(now).abs();
          return diffA.compareTo(diffB);
        });

      setState(() {
        _reminders = sortedReminders;
        _total = response.total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的提醒'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReminders,
            tooltip: '刷新',
          ),
        ],
      ),
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
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadReminders,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_reminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无提醒',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 统计信息
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.notifications_active,
                label: '总提醒数',
                value: _total.toString(),
                color: Colors.blue,
              ),
              _buildStatItem(
                icon: Icons.check_circle,
                label: '已提醒',
                value: _reminders.where((r) => r.reminded).length.toString(),
                color: Colors.green,
              ),
              _buildStatItem(
                icon: Icons.schedule,
                label: '待提醒',
                value: _reminders.where((r) => !r.reminded).length.toString(),
                color: Colors.orange,
              ),
            ],
          ),
        ),

        // 提醒列表
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadReminders,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final reminder = _reminders[index];
                return _buildReminderCard(reminder);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    final now = DateTime.now();
    final isPast = reminder.remindAt.isBefore(now);
    final schedule = reminder.schedule;

    // 计算时间差
    String timeText;
    Color timeColor;
    if (reminder.reminded) {
      timeColor = Colors.green;
      final diff = now.difference(reminder.remindAt);
      if (diff.inDays > 0) {
        timeText = '${diff.inDays} 天前已提醒';
      } else if (diff.inHours > 0) {
        timeText = '${diff.inHours} 小时前已提醒';
      } else if (diff.inMinutes > 0) {
        timeText = '${diff.inMinutes} 分钟前已提醒';
      } else {
        timeText = '刚刚已提醒';
      }
    } else if (!isPast) {
      timeColor = Colors.orange;
      final diff = reminder.remindAt.difference(now);
      if (diff.inDays > 0) {
        timeText = '${diff.inDays} 天后提醒';
      } else if (diff.inHours > 0) {
        timeText = '${diff.inHours} 小时后提醒';
      } else if (diff.inMinutes > 0) {
        timeText = '${diff.inMinutes} 分钟后提醒';
      } else {
        timeText = '即将提醒';
      }
    } else {
      timeColor = Colors.red;
      timeText = '未提醒';
    }

    // 获取状态颜色
    Color statusColor = _getStatusColor(schedule?.status ?? '');
    String statusText = _getStatusText(schedule?.status ?? '');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: InkWell(
        onTap: () => _showReminderDetails(reminder),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧图标
              CircleAvatar(
                radius: 24,
                backgroundColor: reminder.reminded
                    ? Colors.green[100]
                    : isPast
                    ? Colors.red[100]
                    : Colors.orange[100],
                child: Icon(
                  reminder.reminded
                      ? Icons.check_circle
                      : isPast
                      ? Icons.warning
                      : Icons.schedule,
                  color: reminder.reminded
                      ? Colors.green
                      : isPast
                      ? Colors.red
                      : Colors.orange,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              // 主体内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 日程标题
                    Text(
                      schedule?.title ?? '无标题',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // 提醒时间
                    Row(
                      children: [
                        Icon(Icons.alarm, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(reminder.remindAt),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 状态和时间差
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: timeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            timeText,
                            style: TextStyle(
                              fontSize: 11,
                              color: timeColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (schedule != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    // 日程描述
                    if (schedule?.description != null &&
                        schedule!.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        schedule.description!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // 地点
                    if (schedule?.location != null &&
                        schedule!.location!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.place, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              schedule.location!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // 右侧指示器
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'cancelled':
        return Colors.grey;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'in_progress':
        return '进行中';
      case 'cancelled':
        return '已取消';
      case 'pending':
        return '待办';
      default:
        return '未知';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showReminderDetails(Reminder reminder) {
    final schedule = reminder.schedule;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              reminder.reminded ? Icons.check_circle : Icons.schedule,
              color: reminder.reminded ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Expanded(child: Text('提醒详情')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 提醒信息
              const Text(
                '🔔 提醒信息',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              _buildDetailRow('提醒时间', _formatDateTime(reminder.remindAt)),
              _buildDetailRow(
                '提醒状态',
                reminder.reminded ? '✅ 已提醒' : '⏰ 待提醒',
                valueColor: reminder.reminded ? Colors.green : Colors.orange,
              ),
              _buildDetailRow('创建时间', _formatDateTime(reminder.createdAt)),

              // 日程信息
              if (schedule != null) ...[
                const SizedBox(height: 16),
                const Text(
                  '📅 关联日程',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                _buildDetailRow('标题', schedule.title),
                if (schedule.description != null &&
                    schedule.description!.isNotEmpty)
                  _buildDetailRow('描述', schedule.description!),
                _buildDetailRow('开始时间', _formatDateTime(schedule.startTime)),
                if (schedule.endTime != null)
                  _buildDetailRow('结束时间', _formatDateTime(schedule.endTime!)),
                if (schedule.location != null && schedule.location!.isNotEmpty)
                  _buildDetailRow('地点', schedule.location!),
                _buildDetailRow(
                  '状态',
                  _getStatusText(schedule.status),
                  valueColor: _getStatusColor(schedule.status),
                ),
                _buildDetailRow(
                  '优先级',
                  _getPriorityText(schedule.priority ?? 'medium'),
                  valueColor: _getPriorityColor(schedule.priority ?? 'medium'),
                ),
                _buildDetailRow('类型', _getTypeText(schedule.type ?? 'task')),
              ] else ...[
                const SizedBox(height: 16),
                Text(
                  '⚠️ 关联的日程不存在或已被删除',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (schedule != null)
            TextButton.icon(
              onPressed: () {
                // 关闭对话框
                Navigator.pop(context);

                // 关闭 RemindersPage，回到 MainPage
                Navigator.pop(context);

                // 延迟执行，确保返回到 MainPage 后再操作
                Future.delayed(const Duration(milliseconds: 200), () {
                  try {
                    // 直接通过全局 mainPageKey 访问 MainPage 状态
                    final mainPageState = mainPageKey.currentState;
                    if (mainPageState != null) {
                      // 调用 MainPage 的 navigateToScheduleDate 方法
                      (mainPageState as dynamic).navigateToScheduleDate(
                        schedule.startTime,
                      );
                    }
                  } catch (e) {
                    print('导航失败: $e');
                  }
                });
              },
              icon: const Icon(Icons.calendar_today),
              label: const Text('查看日程'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'high':
        return '高';
      case 'medium':
        return '中';
      case 'low':
        return '低';
      default:
        return '普通';
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getTypeText(String type) {
    switch (type) {
      case 'meeting':
        return '会议';
      case 'task':
        return '任务';
      case 'event':
        return '事件';
      case 'reminder':
        return '提醒';
      default:
        return '其他';
    }
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: valueColor)),
          ),
        ],
      ),
    );
  }
}
