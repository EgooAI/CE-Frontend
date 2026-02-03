import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../models/schedule/schedule.dart';
import '../../models/schedule/recurrence_rule.dart';
import '../common/native_context_menu.dart';

enum _DateMenuAction { today, tomorrow, nextMonday, pick, clear }

class ScheduleCard extends StatefulWidget {
  final Schedule schedule;
  final bool isExpanded;
  final VoidCallback onTap;
  final Function(String newStatus)? onStatusChanged; // 状态变更回调
  final VoidCallback? onEdit; // 编辑回调
  final VoidCallback? onDelete; // 删除回调
  final Future<void> Function(Schedule updatedSchedule)? onUpdate; // 快速更新回调
  final bool use24HourFormat;

  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.isExpanded,
    required this.onTap,
    this.onStatusChanged,
    this.onEdit,
    this.onDelete,
    this.onUpdate,
    this.use24HourFormat = true,
  });

  @override
  State<ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<ScheduleCard> {
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _applyQuickUpdate(Schedule updatedSchedule) async {
    if (widget.onUpdate != null) {
      await widget.onUpdate!(updatedSchedule);
    } else {
      widget.onEdit?.call();
    }
  }

  Future<void> _handleDateAction(_DateMenuAction action) async {
    late DateTime selectedDate;

    switch (action) {
      case _DateMenuAction.today:
        selectedDate = _normalizeDate(DateTime.now());
        break;
      case _DateMenuAction.tomorrow:
        selectedDate = _normalizeDate(
          DateTime.now().add(const Duration(days: 1)),
        );
        break;
      case _DateMenuAction.nextMonday:
        final now = DateTime.now();
        final daysUntilMonday = (8 - now.weekday) % 7;
        final offset = daysUntilMonday == 0 ? 7 : daysUntilMonday;
        selectedDate = _normalizeDate(now.add(Duration(days: offset)));
        break;
      case _DateMenuAction.pick:
        final picked = await showDatePicker(
          context: context,
          initialDate: _normalizeDate(widget.schedule.startTime),
          firstDate: DateTime(2020, 1, 1),
          lastDate: DateTime(2035, 12, 31),
        );
        if (picked == null) return;
        selectedDate = _normalizeDate(picked);
        break;
      case _DateMenuAction.clear:
        final updated = widget.schedule.copyWith(
          clearStartDate: true,
          clearEndDate: true,
          hasStartTime: false,
          hasEndTime: false,
        );
        await _applyQuickUpdate(updated);
        return;
    }

    final oldStart = widget.schedule.startTime;
    final duration = widget.schedule.endTime != null
        ? widget.schedule.endTime!.difference(widget.schedule.startTime)
        : null;
    final newStart = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      oldStart.hour,
      oldStart.minute,
      oldStart.second,
      oldStart.millisecond,
      oldStart.microsecond,
    );
    final newEnd = duration != null ? newStart.add(duration) : null;

    final updated = widget.schedule.copyWith(
      startTime: newStart,
      endTime: newEnd,
      startDate: selectedDate,
      endDate: newEnd != null
          ? _normalizeDate(newEnd)
          : widget.schedule.endDate,
      hasStartTime: true,
      hasEndTime: widget.schedule.endTime != null
          ? widget.schedule.hasEndTime
          : false,
    );

    await _applyQuickUpdate(updated);
  }

  Future<void> _showDateMenu() async {
    final action = await showDialog<_DateMenuAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择日期'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pop(context, _DateMenuAction.today),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.today, size: 20),
                        SizedBox(height: 4),
                        Text('今天'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pop(context, _DateMenuAction.tomorrow),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month, size: 20),
                        SizedBox(height: 4),
                        Text('明天'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pop(context, _DateMenuAction.nextMonday),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available, size: 20),
                        SizedBox(height: 4),
                        Text('下周一'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pop(context, _DateMenuAction.pick),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.date_range, size: 20),
                        SizedBox(height: 4),
                        Text('选择日期'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pop(context, _DateMenuAction.clear),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy, size: 20),
                        SizedBox(height: 4),
                        Text('清除日期'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (action == null) return;
    await _handleDateAction(action);
  }

  Future<void> _showTimePicker() async {
    final initialTime = TimeOfDay.fromDateTime(widget.schedule.startTime);
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(alwaysUse24HourFormat: widget.use24HourFormat),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (time == null) return;

    final date = widget.schedule.startTime;
    final newStart = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final duration = widget.schedule.endTime != null
        ? widget.schedule.endTime!.difference(widget.schedule.startTime)
        : null;
    final newEnd = duration != null ? newStart.add(duration) : null;

    final updated = widget.schedule.copyWith(
      startTime: newStart,
      endTime: newEnd,
      startDate: _normalizeDate(newStart),
      endDate: newEnd != null
          ? _normalizeDate(newEnd)
          : widget.schedule.endDate,
      hasStartTime: true,
      hasEndTime: widget.schedule.endTime != null
          ? widget.schedule.hasEndTime
          : false,
    );

    await _applyQuickUpdate(updated);
  }

  Future<void> _showPriorityMenu() async {
    final current = widget.schedule.priority ?? '';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择优先级'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPriorityOption(
              context,
              value: 'high',
              label: '高',
              color: Colors.red,
              selected: current == 'high',
            ),
            _buildPriorityOption(
              context,
              value: 'medium',
              label: '中',
              color: Colors.orange,
              selected: current == 'medium',
            ),
            _buildPriorityOption(
              context,
              value: 'low',
              label: '低',
              color: Colors.green,
              selected: current == 'low',
            ),
            _buildPriorityOption(
              context,
              value: '',
              label: '清除优先级',
              color: Colors.grey,
              selected: current.isEmpty,
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;
    final updated = widget.schedule.copyWith(
      priority: selected.isEmpty ? null : selected,
    );
    await _applyQuickUpdate(updated);
  }

  Widget _buildPriorityOption(
    BuildContext context, {
    required String value,
    required String label,
    required Color color,
    required bool selected,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.flag, color: color, size: 18),
      title: Text(label),
      trailing: selected ? const Icon(Icons.check, size: 18) : null,
      onTap: () => Navigator.pop(context, value),
    );
  }

  void _toggleCompleted(bool? value) {
    if (widget.onStatusChanged == null || value == null) return;
    widget.onStatusChanged!(value ? 'completed' : 'pending');
  }

  @override
  Widget build(BuildContext context) {
    final card = NativeContextMenu(
      actions: [
        NativeContextMenuItem(
          title: '进行中',
          icon: Icons.play_arrow,
          onSelected: () async {
            widget.onStatusChanged?.call('in_progress');
          },
        ),
        NativeContextMenuItem(
          title: '已取消',
          icon: Icons.cancel_outlined,
          onSelected: () async {
            widget.onStatusChanged?.call('cancelled');
          },
        ),
        NativeContextMenuItem(
          title: '日期',
          icon: Icons.calendar_today,
          onSelected: () async {
            await _showDateMenu();
          },
        ),
        NativeContextMenuItem(
          title: '时间',
          icon: Icons.access_time,
          onSelected: () async {
            await _showTimePicker();
          },
        ),
        NativeContextMenuItem(
          title: '优先级',
          icon: Icons.flag_outlined,
          onSelected: () async {
            await _showPriorityMenu();
          },
        ),
        NativeContextMenuItem(
          title: '置顶',
          icon: Icons.push_pin_outlined,
          onSelected: () async {},
        ),
        NativeContextMenuItem(
          title: '编辑',
          icon: Icons.edit_outlined,
          onSelected: () async {
            widget.onEdit?.call();
          },
        ),
        NativeContextMenuItem(
          title: '删除',
          icon: Icons.delete_outline,
          isDestructive: true,
          onSelected: () async {
            widget.onDelete?.call();
          },
        ),
      ],
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        clipBehavior: Clip.antiAlias,
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
                    Checkbox(
                      value: widget.schedule.status == 'completed',
                      onChanged: widget.onStatusChanged == null
                          ? null
                          : _toggleCompleted,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
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
                  widget.schedule.getTimeDisplay(
                    use24HourFormat: widget.use24HourFormat,
                    useChinesePeriod: true,
                  ),
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),

                // 提醒信息
                if (_hasReminders())
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _buildReminderInfo(),
                  ),

                // 地点、状态和重复标识
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (widget.schedule.location != null &&
                        widget.schedule.location!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.schedule.location!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    _getStatusChip(),
                    // 重复标识
                    if (widget.schedule.parentId != null ||
                        (widget.schedule.recurrence != null &&
                            widget.schedule.recurrence!.isNotEmpty))
                      _buildRecurrenceBadge(),
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
      ),
    );

    final slidableCard = widget.onDelete != null
        ? Slidable(
            key: ValueKey(widget.schedule.id),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.20,
              children: [
                CustomSlidableAction(
                  onPressed: (_) => widget.onDelete?.call(),
                  padding: EdgeInsets.zero,
                  autoClose: true,
                  child: SizedBox.expand(
                    child: Container(
                      color: Colors.red,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.delete, color: Colors.white, size: 20),
                          SizedBox(width: 6),
                          Text(
                            '删除',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            child: card,
          )
        : card;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: slidableCard,
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
      case 'failed':
        backgroundColor = Colors.orange[50] ?? Colors.orange.shade50;
        textColor = Colors.orange[700] ?? Colors.orange.shade700;
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
        if (_getRecurrenceText() != null &&
            _getRecurrenceText()!.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.repeat, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                '重复：',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(_getRecurrenceText()!, style: const TextStyle(fontSize: 14)),
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

  // 检查是否有提醒
  bool _hasReminders() {
    return widget.schedule.reminders != null &&
        widget.schedule.reminders!.isNotEmpty;
  }

  // 构建提醒信息
  Widget _buildReminderInfo() {
    if (!_hasReminders()) return const SizedBox.shrink();

    final reminders = widget.schedule.reminders!;
    final now = DateTime.now();

    // 统计已提醒和待提醒的数量
    int remindedCount = 0;
    int pendingCount = 0;
    DateTime? nextRemindTime;

    for (var reminder in reminders) {
      final reminded = reminder['reminded'] ?? false;
      if (reminded) {
        remindedCount++;
      } else {
        pendingCount++;
        final remindAt = DateTime.parse(reminder['remindAt']).toLocal();
        if (nextRemindTime == null || remindAt.isBefore(nextRemindTime)) {
          nextRemindTime = remindAt;
        }
      }
    }

    return Row(
      children: [
        const Icon(Icons.notifications_active, size: 14, color: Colors.orange),
        const SizedBox(width: 4),
        if (pendingCount > 0 && nextRemindTime != null) ...[
          Text(
            _formatRemindTime(nextRemindTime, now),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else if (remindedCount > 0) ...[
          Text('已提醒', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
        if (reminders.length > 1) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${reminders.length}',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 格式化提醒时间
  String _formatRemindTime(DateTime remindTime, DateTime now) {
    final diff = remindTime.difference(now);

    if (diff.isNegative) {
      return '应提醒';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟后提醒';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时后提醒';
    } else if (diff.inDays == 1) {
      return '明天提醒';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天后提醒';
    } else {
      return _formatDate(remindTime);
    }
  }

  // 格式化日期（用于提醒时间显示）
  String _formatDate(DateTime date) {
    final dateStr = '${date.month}/${date.day}';
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    if (widget.use24HourFormat) {
      return '$dateStr $hh:$mm';
    }
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour < 12 ? '上午' : '下午';
    return '$dateStr $period ${hour12.toString().padLeft(2, '0')}:$mm';
  }

  // 构建重复标识徽章
  Widget _buildRecurrenceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat, size: 12, color: Colors.purple),
          const SizedBox(width: 4),
          Text(
            '重复',
            style: TextStyle(
              fontSize: 10,
              color: Colors.purple[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.schedule.iterationIndex != null) ...[
            const SizedBox(width: 2),
            Text(
              '·${widget.schedule.iterationIndex}',
              style: TextStyle(fontSize: 9, color: Colors.purple[600]),
            ),
          ],
        ],
      ),
    );
  }

  /// 解析 recurrence（支持 JSON 字符串或 RRULE），返回可读文本
  String? _getRecurrenceText() {
    final raw = widget.schedule.recurrence;
    if (raw == null || raw.isEmpty) return null;

    // 优先解析 JSON 格式
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return RecurrenceRule.fromJson(decoded).toDisplayText();
      }
    } catch (_) {
      // 忽略 JSON 解析失败
    }

    // 退回解析 RRULE 字符串
    try {
      return RecurrenceRule.fromRRule(raw).toDisplayText();
    } catch (_) {
      // 忽略
    }

    // 无法解析则原样返回
    return raw;
  }
}
