import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../services/reminder_service.dart';

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
      setState(() {
        _reminders = response.reminders;
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
    final isFuture = reminder.remindAt.isAfter(now);

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
    } else if (isFuture) {
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
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
          ),
        ),
        title: Text(
          _formatDateTime(reminder.remindAt),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(timeText, style: TextStyle(color: timeColor, fontSize: 12)),
            const SizedBox(height: 2),
            Text(
              '日程 ID: ${reminder.scheduleId.substring(0, 8)}...',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: reminder.reminded
            ? const Icon(Icons.done, color: Colors.green)
            : null,
        onTap: () {
          _showReminderDetails(reminder);
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showReminderDetails(Reminder reminder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提醒详情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('提醒 ID', reminder.id),
            _buildDetailRow('日程 ID', reminder.scheduleId),
            _buildDetailRow('提醒时间', _formatDateTime(reminder.remindAt)),
            _buildDetailRow(
              '状态',
              reminder.reminded ? '已提醒' : '待提醒',
              valueColor: reminder.reminded ? Colors.green : Colors.orange,
            ),
            _buildDetailRow('创建时间', _formatDateTime(reminder.createdAt)),
          ],
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
