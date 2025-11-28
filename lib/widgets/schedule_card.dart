import 'package:flutter/material.dart';
import '../models/schedule.dart';

class ScheduleCard extends StatefulWidget {
  final Schedule schedule;
  final bool isExpanded;
  final VoidCallback onTap;
  final Function(String newStatus)? onStatusChanged; // 状态变更回调
  final VoidCallback? onEdit; // 编辑回调
  final VoidCallback? onDelete; // 删除回调

  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.isExpanded,
    required this.onTap,
    this.onStatusChanged,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<ScheduleCard> {
  String? _pendingAction; // 'completed', 'cancelled', 'in_progress'
  bool _isConfirming = false;

  // 第一次点击：显示确认按钮
  void _handleFirstClick(String action) {
    setState(() {
      _pendingAction = action;
      _isConfirming = true;
    });

    // 显示确认提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('确认吗？再次点击确认'),
        duration: Duration(seconds: 3),
      ),
    );

    // 3秒后自动取消确认状态
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isConfirming) {
        setState(() {
          _pendingAction = null;
          _isConfirming = false;
        });
      }
    });
  }

  // 第二次点击：执行操作
  void _handleSecondClick(String action) {
    if (widget.onStatusChanged != null) {
      widget.onStatusChanged!(action);
    }
    setState(() {
      _pendingAction = null;
      _isConfirming = false;
    });
  }

  // 构建快速操作按钮
  Widget _buildQuickActionButtons() {
    final status = widget.schedule.status;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 编辑按钮（展开时显示，所有状态都可以编辑）
        if (widget.isExpanded && widget.onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: widget.onEdit,
            tooltip: '编辑',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),

        // 删除按钮（展开时显示）
        if (widget.isExpanded && widget.onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: widget.onDelete,
            tooltip: '删除',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            color: Colors.red,
          ),

        // 已完成或已取消的日程不显示状态按钮
        if (status != 'completed' && status != 'cancelled') ...[
          const SizedBox(width: 4),

          // 开始按钮（仅待办状态显示）
          if (status == 'pending')
            _buildActionButton(
              action: 'in_progress',
              icon: Icons.play_arrow,
              label: '开始',
              color: Colors.blue,
            ),

          if (status == 'pending') const SizedBox(width: 4),

          // 完成按钮
          _buildActionButton(
            action: 'completed',
            icon: Icons.check,
            label: '完成',
            color: Colors.green,
          ),

          const SizedBox(width: 4),

          // 取消按钮
          _buildActionButton(
            action: 'cancelled',
            icon: Icons.close,
            label: '取消',
            color: Colors.red,
          ),
        ],
      ],
    );
  }

  // 构建单个操作按钮
  Widget _buildActionButton({
    required String action,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isConfirming = _pendingAction == action && _isConfirming;

    return InkWell(
      onTap: () {
        if (isConfirming) {
          _handleSecondClick(action);
        } else {
          _handleFirstClick(action);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isConfirming ? 8 : 4,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: isConfirming ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isConfirming ? color : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            if (isConfirming) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: widget.onTap,
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
                      widget.schedule.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // 快速操作按钮
                  _buildQuickActionButtons(),
                  const SizedBox(width: 4),
                  Icon(
                    widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),

              // 时间
              const SizedBox(height: 4),
              Text(
                widget.schedule.getTimeDisplay(),
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),

              // 地点和状态
              const SizedBox(height: 4),
              Row(
                children: [
                  if (widget.schedule.location != null &&
                      widget.schedule.location!.isNotEmpty) ...[
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      widget.schedule.location!,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 12),
                  ],
                  _getStatusChip(),
                ],
              ),

              // 展开的详细信息
              if (widget.isExpanded) ...[
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

    switch (widget.schedule.type) {
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
      case 'daily':
        icon = Icons.calendar_today;
        color = Colors.green;
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
    String text = widget.schedule.getStatusText();

    switch (widget.schedule.status) {
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
        if (widget.schedule.description != null &&
            widget.schedule.description!.isNotEmpty) ...[
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
              widget.schedule.description!,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 类型
        if (widget.schedule.getTypeText() != null) ...[
          Row(
            children: [
              const Icon(Icons.category, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                '类型：',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                widget.schedule.getTypeText()!,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // 优先级
        if (widget.schedule.getPriorityText() != null) ...[
          Row(
            children: [
              const Icon(Icons.flag, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                '优先级：',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                widget.schedule.getPriorityText()!,
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
        if (widget.schedule.participants != null &&
            widget.schedule.participants!.isNotEmpty) ...[
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
                      widget.schedule.participants!,
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
        if (widget.schedule.recurrence != null &&
            widget.schedule.recurrence!.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.repeat, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                '重复：',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                widget.schedule.recurrence!,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // 附件
        if (widget.schedule.attachments != null &&
            widget.schedule.attachments!.isNotEmpty) ...[
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
        if (widget.schedule.notes != null &&
            widget.schedule.notes!.isNotEmpty) ...[
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
                    Text(
                      widget.schedule.notes!,
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      widget.schedule.notes!,
                      style: const TextStyle(fontSize: 14),
                    ),
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
    switch (widget.schedule.priority) {
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
