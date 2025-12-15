import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/schedule.dart';
import '../models/recurrence_rule.dart';
import '../services/schedule_service.dart';
import '../widgets/create_schedule_bottom_sheet.dart';

/// 重复日程模板列表页面
class RecurringSchedulesPage extends StatefulWidget {
  const RecurringSchedulesPage({super.key});

  @override
  State<RecurringSchedulesPage> createState() => _RecurringSchedulesPageState();
}

class _RecurringSchedulesPageState extends State<RecurringSchedulesPage> {
  final ScheduleService _scheduleService = ScheduleService();
  late Future<List<Schedule>> _templatesFuture;
  Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  void _loadTemplates() {
    setState(() {
      _templatesFuture = _scheduleService.getTemplates();
    });
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  /// 解析 recurrence（支持 JSON 字符串或 RRULE），返回可读文本
  String _getRecurrenceText(String? raw) {
    if (raw == null || raw.isEmpty) return '未设置';

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

  Future<void> _handleDelete(Schedule template) async {
    String selectedOption = 'none';

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('删除重复日程模板'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('「${template.title}」'),
                  const SizedBox(height: 16),
                  const Text('请选择删除方式：'),
                  const SizedBox(height: 12),
                  RadioListTile<String>(
                    title: const Text('仅删除模板'),
                    subtitle: const Text('保留所有已生成的实例'),
                    value: 'none',
                    groupValue: selectedOption,
                    onChanged: (v) =>
                        setState(() => selectedOption = v ?? 'none'),
                  ),
                  RadioListTile<String>(
                    title: const Text('删除模板 + 所有待办'),
                    subtitle: const Text('删除未开始的实例'),
                    value: 'future',
                    groupValue: selectedOption,
                    onChanged: (v) =>
                        setState(() => selectedOption = v ?? 'none'),
                  ),
                  RadioListTile<String>(
                    title: const Text('删除模板 + 所有事件（含历史）'),
                    value: 'all',
                    groupValue: selectedOption,
                    onChanged: (v) =>
                        setState(() => selectedOption = v ?? 'none'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop({'action': selectedOption}),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('确认删除'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    final action = result['action'] ?? 'none';

    try {
      await _scheduleService.deleteRecurrenceTemplate(
        template.id,
        deleteInstances: action,
      );

      if (mounted) {
        final strategyText =
            {'future': '模板+待办实例', 'all': '模板+全部实例'}[action] ?? '仅模板';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除：$strategyText'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      _loadTemplates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 新建重复日程
  void _handleCreate() {
    // 默认启用重复规则（周重复，周一）
    // 并设置合理的默认时间
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day, 10, 0);
    final endTime = startTime.add(const Duration(hours: 1));

    // 使用后端期望的字段名：by_day（下划线）
    final initialRecurrenceData = {
      'frequency': 'WEEKLY',
      'interval': 1,
      'by_day': ['MO'],
      'until': null,
      'count': null,
    };

    showCreateScheduleBottomSheet(
      context,
      initialData: {
        'title': '',
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'recurrence': initialRecurrenceData,
      },
      onSave: (schedule) => _handleSaveSchedule(schedule, isCreate: true),
    );
  }

  /// 编辑重复日程模板
  void _handleEdit(Schedule template) {
    showCreateScheduleBottomSheet(
      context,
      existingSchedule: template,
      onSave: (schedule) =>
          _handleSaveSchedule(schedule, isCreate: false, template: template),
    );
  }

  /// 保存日程（新建或编辑）
  Future<void> _handleSaveSchedule(
    Schedule schedule, {
    required bool isCreate,
    Schedule? template,
  }) async {
    try {
      if (isCreate) {
        // 新建
        await _scheduleService.createSchedule(schedule.toJson());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('重复日程创建成功'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // 编辑：模板不需要范围选择，直接更新模板系列配置；实例走单条更新
        if (template != null && template.parentId == null) {
          await _scheduleService.updateRecurrenceSeries(
            template.id,
            schedule.toJson(),
          );
        } else {
          // 普通实例或非模板，直接更新单条
          await _scheduleService.updateSchedule(schedule.id, schedule.toJson());
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('重复日程更新成功'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // 刷新列表
      _loadTemplates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 模板编辑不需要范围选择，已移除策略对话框

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的重复事件'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _handleCreate,
            tooltip: '新建重复日程',
          ),
        ],
      ),
      body: FutureBuilder<List<Schedule>>(
        future: _templatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    '加载失败',
                    style: TextStyle(fontSize: 16, color: Colors.red[400]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadTemplates,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          final templates = snapshot.data ?? [];

          if (templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.repeat, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    '暂无重复事件',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              final isExpanded = _expandedIds.contains(template.id);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: InkWell(
                  onTap: () => _toggleExpanded(template.id),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题行
                        Row(
                          children: [
                            Icon(
                              _getTypeIcon(template.type),
                              color: _getTypeColor(template.type),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                template.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '模板',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.purple[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.grey,
                            ),
                          ],
                        ),

                        // 时间信息
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              template.getTimeDisplay(),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                            if (template.location != null &&
                                template.location!.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  template.location!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),

                        // 展开详情
                        if (isExpanded) ...[
                          const Divider(height: 16),
                          _buildDetailRow(
                            '重复规则',
                            _getRecurrenceText(template.recurrence),
                          ),
                          if (template.description != null &&
                              template.description!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildDetailRow('描述', template.description!),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _handleEdit(template),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('编辑'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () => _handleDelete(template),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                label: const Text('删除'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 12, color: valueColor)),
        ),
      ],
    );
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'meeting':
        return Icons.groups;
      case 'task':
        return Icons.assignment;
      case 'event':
        return Icons.celebration;
      case 'daily':
        return Icons.calendar_today;
      default:
        return Icons.event_note;
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'meeting':
        return Colors.blue;
      case 'task':
        return Colors.orange;
      case 'event':
        return Colors.purple;
      case 'daily':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
