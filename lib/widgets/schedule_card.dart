import 'package:flutter/material.dart';
import '../models/schedule.dart';

class ScheduleCard extends StatelessWidget {
  final Schedule schedule;
  final bool isExpanded;
  final VoidCallback onTap;

  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  _getTypeIcon(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      schedule.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),

              // 时间
              const SizedBox(height: 4),
              Text(
                schedule.getTimeDisplay(),
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),

              // 地点和状态
              const SizedBox(height: 4),
              Row(
                children: [
                  if (schedule.location != null &&
                      schedule.location!.isNotEmpty) ...[
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      schedule.location!,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 12),
                  ],
                  _getStatusChip(),
                ],
              ),

              // 展开的详细信息
              if (isExpanded) ...[
                const Divider(height: 20),
                _buildDetailedInfo(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 获取类型图标
  Widget _getTypeIcon() {
    IconData icon;
    Color color;

    switch (schedule.type) {
      case 'meeting':
        icon = Icons.groups;
        color = Colors.blue;
        break;
      case 'task':
        icon = Icons.assignment;
        color = Colors.orange;
        break;
      case 'event':
        icon = Icons.celebration;
        color = Colors.purple;
        break;
      default:
        icon = Icons.event_note;
        color = Colors.grey;
    }

    return Icon(icon, size: 20, color: color);
  }

  // 获取状态标签
  Widget _getStatusChip() {
    Color backgroundColor;
    Color textColor;
    String text = schedule.getStatusText();

    switch (schedule.status) {
      case 'in_progress':
        backgroundColor = Colors.blue[50] ?? Colors.blue.shade50;
        textColor = Colors.blue[700] ?? Colors.blue.shade700;
        break;
      case 'pending':
        backgroundColor = Colors.grey[200] ?? Colors.grey.shade200;
        textColor = Colors.grey[700] ?? Colors.grey.shade700;
        break;
      case 'completed':
        backgroundColor = Colors.green[50] ?? Colors.green.shade50;
        textColor = Colors.green[700] ?? Colors.green.shade700;
        break;
      case 'cancelled':
        backgroundColor = Colors.red[50] ?? Colors.red.shade50;
        textColor = Colors.red[700] ?? Colors.red.shade700;
        break;
      default:
        backgroundColor = Colors.grey[200] ?? Colors.grey.shade200;
        textColor = Colors.grey[700] ?? Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // 构建详细信息
  Widget _buildDetailedInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 描述
        if (schedule.description != null &&
            schedule.description!.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.description, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                '描述',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              schedule.description!,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 类型
        if (schedule.getTypeText() != null) ...[
          Row(
            children: [
              const Icon(Icons.category, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                '类型：',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                schedule.getTypeText()!,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // 优先级
        if (schedule.getPriorityText() != null) ...[
          Row(
            children: [
              const Icon(Icons.flag, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                '优先级：',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                schedule.getPriorityText()!,
                style: TextStyle(
                  fontSize: 14,
                  color: _getPriorityColor(),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // 参与者
        if (schedule.participants != null &&
            schedule.participants!.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.people, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '参与者：',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      schedule.participants!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // 重复规则
        if (schedule.recurrence != null && schedule.recurrence!.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.repeat, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                '重复：',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(schedule.recurrence!, style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // 附件
        if (schedule.attachments != null &&
            schedule.attachments!.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.attach_file, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                '附件：',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const Text(
                '有附件',
                style: TextStyle(fontSize: 14, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // 备注
        if (schedule.notes != null && schedule.notes!.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.note, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '备注：',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(schedule.notes!, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // 获取优先级颜色
  Color _getPriorityColor() {
    switch (schedule.priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
