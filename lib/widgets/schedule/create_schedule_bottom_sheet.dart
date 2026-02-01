import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/schedule/schedule.dart';
import '../../models/schedule/recurrence_rule.dart';
import 'recurrence_editor.dart';

/// 创建/编辑日程底部抽屉
///
/// 用法示例：
/// ```dart
/// // 创建新日程
/// showCreateScheduleBottomSheet(context, initialDate: selectedDate);
///
/// // 编辑现有日程
/// showCreateScheduleBottomSheet(context, existingSchedule: schedule);
///
/// // AI 预填充数据
/// showCreateScheduleBottomSheet(context, initialData: aiData);
/// ```
class CreateScheduleBottomSheet extends StatefulWidget {
  final DateTime? initialDate;
  final Schedule? existingSchedule; // 编辑模式
  final Map<String, dynamic>? initialData; // AI 预填充数据
  final Future<void> Function(Schedule) onSave;
  final bool use24HourFormat;

  const CreateScheduleBottomSheet({
    super.key,
    this.initialDate,
    this.existingSchedule,
    this.initialData,
    required this.onSave,
    this.use24HourFormat = true,
  });

  @override
  State<CreateScheduleBottomSheet> createState() =>
      _CreateScheduleBottomSheetState();
}

class _CreateScheduleBottomSheetState extends State<CreateScheduleBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _participantsController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _startTime;
  DateTime? _endTime;
  bool _hasStartTime = true;
  bool _hasEndTime = false;
  String _status = 'pending';
  String? _priority = 'medium';
  String? _type = 'task';
  int? _remindBefore; // 提前提醒分钟数
  RecurrenceRule? _recurrenceRule; // 重复规则

  bool _isLoading = false;
  String? _validationError; // 验证错误提示

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    String _stringify(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return jsonEncode(value);
    }

    if (widget.existingSchedule != null) {
      // 编辑模式：加载现有数据
      final schedule = widget.existingSchedule!;
      _titleController.text = schedule.title;
      _descriptionController.text = schedule.description ?? '';
      _locationController.text = schedule.location ?? '';
      _notesController.text = schedule.notes ?? '';
      _participantsController.text = schedule.participants ?? '';
      _startDate =
          schedule.startDate ??
          DateTime(
            schedule.startTime.year,
            schedule.startTime.month,
            schedule.startTime.day,
          );
      _endDate =
          schedule.endDate ??
          (schedule.endTime != null
              ? DateTime(
                  schedule.endTime!.year,
                  schedule.endTime!.month,
                  schedule.endTime!.day,
                )
              : null);
      _hasStartTime = schedule.hasStartTime;
      _hasEndTime = schedule.hasEndTime;
      _startTime = _hasStartTime ? schedule.startTime : null;
      _endTime = _hasEndTime ? schedule.endTime : null;
      _status = schedule.status;
      _priority = schedule.priority ?? 'medium';
      // 普通日程不再使用 daily 类型，若后端已有 daily 则回退为 task
      _type = (schedule.type == 'daily' || schedule.type == null)
          ? 'task'
          : schedule.type;
      _remindBefore =
          schedule.remindBefore ??
          _computeRemindBeforeFromReminders(
            schedule.reminders,
            schedule.startTime,
          );
      // 解析已有的重复规则（支持 JSON 字符串或 RRULE 字符串）
      if (schedule.recurrence != null && schedule.recurrence!.isNotEmpty) {
        try {
          // 首先尝试解析 JSON 格式
          final decoded = jsonDecode(schedule.recurrence!);
          if (decoded is Map<String, dynamic>) {
            _recurrenceRule = RecurrenceRule.fromJson(decoded);
          } else {
            // 如果不是 Map，尝试作为 RRULE 字符串解析
            _recurrenceRule = RecurrenceRule.fromRRule(schedule.recurrence!);
          }
        } catch (_) {
          // JSON 解析失败，尝试 RRULE 格式
          try {
            _recurrenceRule = RecurrenceRule.fromRRule(schedule.recurrence!);
          } catch (_) {
            // 都失败，保持为空
          }
        }
      }
    } else if (widget.initialData != null) {
      // AI 预填充模式
      final data = widget.initialData!;
      _titleController.text = _stringify(data['title']);
      _descriptionController.text = _stringify(data['description']);
      _locationController.text = _stringify(data['location']);
      _notesController.text = _stringify(data['notes']);
      _participantsController.text = _stringify(data['participants']);
      if (data['startTime'] != null) {
        // DateTime.parse() 会将带时区的时间转换为 UTC
        // 需要使用 .toLocal() 转换回本地时区，保持正确的日期
        _startTime = DateTime.parse(data['startTime']).toLocal();
        _hasStartTime = true;
        _startDate = DateTime(
          _startTime!.year,
          _startTime!.month,
          _startTime!.day,
        );
      }
      if (data['startDate'] != null) {
        final parsed = DateTime.tryParse(data['startDate']);
        if (parsed != null) {
          _startDate = DateTime(parsed.year, parsed.month, parsed.day);
        }
      }
      if (data['endTime'] != null) {
        _endTime = DateTime.parse(data['endTime']).toLocal();
        _hasEndTime = true;
        _endDate = DateTime(_endTime!.year, _endTime!.month, _endTime!.day);
      }
      if (data['endDate'] != null) {
        final parsed = DateTime.tryParse(data['endDate']);
        if (parsed != null) {
          _endDate = DateTime(parsed.year, parsed.month, parsed.day);
        }
      }
      if (_startTime == null && _startDate != null) {
        _hasStartTime = false;
      }
      if (_endTime == null && _endDate != null) {
        _hasEndTime = false;
      }
      _status = data['status'] ?? 'pending';
      _priority = data['priority'] ?? 'medium';
      final incomingType = data['type'] as String?;
      _type = (incomingType == null || incomingType == 'daily')
          ? 'task'
          : incomingType;
      _remindBefore = data['remindBefore'];
      if (_remindBefore == null && data['reminders'] is List) {
        final computed = _computeRemindBeforeFromReminders(
          data['reminders'] as List<dynamic>,
          _startTime,
        );
        _remindBefore = computed;
      }
      // 解析重复规则（支持 JSON Map、JSON 字符串、RRULE 字符串）
      if (data['recurrence'] is Map<String, dynamic>) {
        try {
          _recurrenceRule = RecurrenceRule.fromJson(
            data['recurrence'] as Map<String, dynamic>,
          );
        } catch (e) {
          // 解析失败，忽略
        }
      } else if (data['recurrence'] is String &&
          (data['recurrence'] as String).isNotEmpty) {
        try {
          // 首先尝试解析 JSON 字符串格式
          final decoded = jsonDecode(data['recurrence'] as String);
          if (decoded is Map<String, dynamic>) {
            _recurrenceRule = RecurrenceRule.fromJson(decoded);
          } else {
            // 不是 JSON，尝试 RRULE 格式
            _recurrenceRule = RecurrenceRule.fromRRule(
              data['recurrence'] as String,
            );
          }
        } catch (_) {
          // JSON 解析失败，尝试 RRULE 格式
          try {
            _recurrenceRule = RecurrenceRule.fromRRule(
              data['recurrence'] as String,
            );
          } catch (_) {
            // 都失败，忽略
          }
        }
      }
    } else {
      // 创建模式：使用默认值
      final initialDate = widget.initialDate ?? DateTime.now();
      _startDate = DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
      );
      _startTime = _getSmartStartTime(initialDate);
      _hasStartTime = true;
      _endTime = null;
      _hasEndTime = false;
    }
  }

  /// 根据提醒列表和开始时间计算提前提醒分钟数（取最早的一条提醒）
  int? _computeRemindBeforeFromReminders(
    List<dynamic>? reminders,
    DateTime? start,
  ) {
    if (reminders == null || reminders.isEmpty || start == null) return null;

    DateTime? earliest;
    for (final item in reminders) {
      final remindAtStr = item is Map<String, dynamic>
          ? item['remindAt']
          : null;
      if (remindAtStr is String && remindAtStr.isNotEmpty) {
        final remindAt = DateTime.tryParse(remindAtStr)?.toLocal();
        if (remindAt != null) {
          if (earliest == null || remindAt.isBefore(earliest)) {
            earliest = remindAt;
          }
        }
      }
    }

    if (earliest == null) return null;
    final diffMinutes = start.difference(earliest).inMinutes;
    if (diffMinutes <= 0) return null; // 不提前或数据异常
    return diffMinutes;
  }

  /// 智能设置开始时间
  DateTime _getSmartStartTime(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    if (isToday && now.hour >= 9) {
      // 今天且已过 09:00，使用下一个整点
      final nextHour = now.hour + 1;
      return DateTime(date.year, date.month, date.day, nextHour, 0);
    } else {
      // 默认 09:00
      return DateTime(date.year, date.month, date.day, 9, 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _participantsController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatTimeOnly(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (widget.use24HourFormat) {
      return '$hh:$mm';
    }
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour < 12 ? '上午' : '下午';
    return '$period ${hour12.toString().padLeft(2, '0')}:$mm';
  }

  bool get _canSave {
    return _titleController.text.isNotEmpty;
  }

  String _computeStatus() {
    final hasAnyDateOrTime =
        _startDate != null ||
        _endDate != null ||
        (_hasStartTime && _startTime != null) ||
        (_hasEndTime && _endTime != null);
    return hasAnyDateOrTime ? 'pending' : 'in_progress';
  }

  /// 合并的日期时间选择器（先选日期，再选择是否有时间）
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final currentDate = isStart ? _startDate : _endDate;
    final initialDate = currentDate ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (date == null) return;

    setState(() {
      if (isStart) {
        _startDate = DateTime(date.year, date.month, date.day);
        if (_hasStartTime && _startTime != null) {
          _startTime = DateTime(
            date.year,
            date.month,
            date.day,
            _startTime!.hour,
            _startTime!.minute,
          );
        }
      } else {
        _endDate = DateTime(date.year, date.month, date.day);
        if (_hasEndTime && _endTime != null) {
          _endTime = DateTime(
            date.year,
            date.month,
            date.day,
            _endTime!.hour,
            _endTime!.minute,
          );
        }
      }
      _status = _computeStatus();
    });
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final currentTime = isStart ? _startTime : _endTime;
    final initialTime = currentTime != null
        ? TimeOfDay(hour: currentTime.hour, minute: currentTime.minute)
        : TimeOfDay(hour: isStart ? 9 : 10, minute: 0);

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

    setState(() {
      if (isStart) {
        final baseDate = _startDate ?? DateTime.now();
        _startDate ??= DateTime(baseDate.year, baseDate.month, baseDate.day);
        _hasStartTime = true;
        _startTime = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
          time.hour,
          time.minute,
        );
      } else {
        final baseDate = _endDate ?? _startDate ?? DateTime.now();
        _endDate ??= DateTime(baseDate.year, baseDate.month, baseDate.day);
        _hasEndTime = true;
        _endTime = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          time.hour,
          time.minute,
        );
      }
      _status = _computeStatus();
    });
  }

  void _clearStartDate() {
    setState(() {
      _startDate = null;
      _startTime = null;
      _hasStartTime = false;
      _status = _computeStatus();
    });
  }

  void _clearStartTime() {
    setState(() {
      _startTime = null;
      _hasStartTime = false;
      _status = _computeStatus();
    });
  }

  void _clearEndDate() {
    setState(() {
      _endDate = null;
      _endTime = null;
      _hasEndTime = false;
      _status = _computeStatus();
    });
  }

  void _clearEndTime() {
    setState(() {
      _endTime = null;
      _hasEndTime = false;
      _status = _computeStatus();
    });
  }

  String? _validateForm() {
    if (_titleController.text.trim().isEmpty) {
      return '请输入日程标题';
    }
    if (_hasStartTime && _startTime == null) {
      return '请选择开始时间';
    }
    if (_hasEndTime && _endTime == null) {
      return '请选择结束时间';
    }
    if (_endDate != null && _startDate != null) {
      final start = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
      );
      final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      if (end.isBefore(start)) {
        return '结束日期不能早于开始日期';
      }
    }
    if (_hasStartTime &&
        _hasEndTime &&
        _startTime != null &&
        _endTime != null) {
      if (!_endTime!.isAfter(_startTime!)) {
        return '结束时间必须晚于开始时间';
      }
    }
    return null;
  }

  Future<void> _handleSave() async {
    final error = _validateForm();
    if (error != null) {
      // 使用内联提示显示错误
      setState(() {
        _validationError = error;
      });
      return;
    }

    // 清除错误提示
    setState(() {
      _validationError = null;
    });

    setState(() {
      _isLoading = true;
    });

    try {
      final hasAnyDateOrTime =
          _startDate != null ||
          _endDate != null ||
          (_hasStartTime && _startTime != null) ||
          (_hasEndTime && _endTime != null);

      final resolvedStartDate = _startDate;
      final resolvedStartTime = _hasStartTime && _startTime != null
          ? _startTime!
          : (_startDate != null
                ? DateTime(_startDate!.year, _startDate!.month, _startDate!.day)
                : DateTime.now());
      final resolvedEndDate = _endDate;
      final resolvedEndTime = _hasEndTime ? _endTime : null;
      final effectiveStatus = !hasAnyDateOrTime ? 'in_progress' : _status;

      // 构建 Schedule 对象
      final schedule = Schedule(
        id: widget.existingSchedule?.id ?? '',
        userId: widget.existingSchedule?.userId ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startTime: resolvedStartTime,
        endTime: resolvedEndTime, // 不设置默认值，可以为 null
        allDay: _startDate != null && !_hasStartTime && !_hasEndTime,
        startDate: resolvedStartDate,
        endDate: resolvedEndDate,
        hasStartTime: _hasStartTime,
        hasEndTime: _hasEndTime,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        status: effectiveStatus,
        type: _type,
        priority: _priority,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        participants: _participantsController.text.trim().isEmpty
            ? null
            : _participantsController.text.trim(),
        remindBefore: _remindBefore,
        recurrence: _recurrenceRule != null
            ? jsonEncode(_recurrenceRule!.toJson())
            : null,
      );

      // 等待外部保存逻辑完成后再关闭 Bottom Sheet，避免保存未完成即关闭导致的“没反应”体验
      await widget.onSave(schedule);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.existingSchedule != null;
    final title = isEditMode ? '编辑日程' : '创建日程';

    return RepaintBoundary(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFFF6F7F9),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 标题栏
            _buildHeader(title),

            // 表单内容
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 错误提示（如果有）
                      if (_validationError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _validationError!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildGroupCard([
                        _buildTitleField(),
                        const SizedBox(height: 16),
                        _buildDateTimeSection(),
                        const SizedBox(height: 16),
                        _buildRemindBeforeField(),
                      ]),
                      _buildGroupCard([
                        _buildStatusSection(),
                        const SizedBox(height: 12),
                        _buildPrioritySection(),
                        const SizedBox(height: 12),
                        _buildTypeSection(),
                      ]),
                      _buildGroupCard([
                        _buildLocationField(),
                        const SizedBox(height: 12),
                        _buildParticipantsField(),
                        const SizedBox(height: 12),
                        _buildDescriptionField(),
                        const SizedBox(height: 12),
                        _buildNotesField(),
                        const SizedBox(height: 12),
                        RecurrenceEditor(
                          initialRule: _recurrenceRule,
                          onChanged: (rule) {
                            setState(() {
                              _recurrenceRule = rule;
                            });
                          },
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),

            // 底部按钮
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: _inputDecoration(label: '标题 *', icon: Icons.title),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 开始日期
        GestureDetector(
          onTap: () => _selectDate(context, true),
          child: InputDecorator(
            decoration: _inputDecoration(
              label: '开始日期（可选）',
              icon: Icons.event,
              suffixIcon: _startDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: _clearStartDate,
                      tooltip: '清空开始日期',
                    )
                  : null,
            ),
            child: Text(
              _startDate != null ? _formatDate(_startDate!) : '请选择开始日期',
              style: TextStyle(
                color: _startDate != null ? Colors.black87 : Colors.grey,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 开始时间（可选）
        GestureDetector(
          onTap: () => _selectTime(context, true),
          child: InputDecorator(
            decoration: _inputDecoration(
              label: '开始时间（可选）',
              icon: Icons.schedule,
              suffixIcon: _hasStartTime && _startTime != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: _clearStartTime,
                      tooltip: '清空开始时间',
                    )
                  : null,
            ),
            child: Text(
              _hasStartTime && _startTime != null
                  ? _formatTimeOnly(_startTime!)
                  : '选择开始时间',
              style: TextStyle(
                color: _hasStartTime && _startTime != null
                    ? Colors.black87
                    : Colors.grey,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 结束日期（可选）
        GestureDetector(
          onTap: () => _selectDate(context, false),
          child: InputDecorator(
            decoration: _inputDecoration(
              label: '结束日期（可选）',
              icon: Icons.event_available,
              suffixIcon: _endDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: _clearEndDate,
                      tooltip: '清空结束日期',
                    )
                  : null,
            ),
            child: Text(
              _endDate != null ? _formatDate(_endDate!) : '选择结束日期',
              style: TextStyle(
                color: _endDate != null ? Colors.black87 : Colors.grey,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 结束时间（可选）
        GestureDetector(
          onTap: () => _selectTime(context, false),
          child: InputDecorator(
            decoration: _inputDecoration(
              label: '结束时间（可选）',
              icon: Icons.access_time,
              suffixIcon: _hasEndTime && _endTime != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: _clearEndTime,
                      tooltip: '清空结束时间',
                    )
                  : null,
            ),
            child: Text(
              _hasEndTime && _endTime != null
                  ? _formatTimeOnly(_endTime!)
                  : '选择结束时间',
              style: TextStyle(
                color: _hasEndTime && _endTime != null
                    ? Colors.black87
                    : Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: _inputDecoration(
        label: '描述',
        icon: Icons.description,
      ).copyWith(alignLabelWithHint: true),
      maxLines: 3,
    );
  }

  Widget _buildLocationField() {
    return TextFormField(
      controller: _locationController,
      decoration: _inputDecoration(label: '地点', icon: Icons.location_on),
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('状态', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: _buildChipLabel('待办', selected: _status == 'pending'),
              selected: _status == 'pending',
              onSelected: (_) => setState(() => _status = 'pending'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            ChoiceChip(
              label: _buildChipLabel('进行中', selected: _status == 'in_progress'),
              selected: _status == 'in_progress',
              onSelected: (_) => setState(() => _status = 'in_progress'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            ChoiceChip(
              label: _buildChipLabel('已完成', selected: _status == 'completed'),
              selected: _status == 'completed',
              onSelected: (_) => setState(() => _status = 'completed'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            ChoiceChip(
              label: _buildChipLabel('已取消', selected: _status == 'cancelled'),
              selected: _status == 'cancelled',
              onSelected: (_) => setState(() => _status = 'cancelled'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            ChoiceChip(
              label: _buildChipLabel('未完成', selected: _status == 'failed'),
              selected: _status == 'failed',
              onSelected: (_) => setState(() => _status = 'failed'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrioritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('优先级', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: _buildChipLabel('低', selected: _priority == 'low'),
              selected: _priority == 'low',
              onSelected: (_) => setState(() => _priority = 'low'),
              backgroundColor: Colors.green.shade100,
              selectedColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            ChoiceChip(
              label: _buildChipLabel('中', selected: _priority == 'medium'),
              selected: _priority == 'medium',
              onSelected: (_) => setState(() => _priority = 'medium'),
              backgroundColor: Colors.orange.shade100,
              selectedColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            ChoiceChip(
              label: _buildChipLabel('高', selected: _priority == 'high'),
              selected: _priority == 'high',
              onSelected: (_) => setState(() => _priority = 'high'),
              backgroundColor: Colors.red.shade100,
              selectedColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('类型', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: _buildChipLabel(
                '会议',
                selected: _type == 'meeting',
                leading: const Icon(Icons.event, size: 16),
              ),
              selected: _type == 'meeting',
              onSelected: (_) => setState(() => _type = 'meeting'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            ChoiceChip(
              label: _buildChipLabel(
                '任务',
                selected: _type == 'task',
                leading: const Icon(Icons.task, size: 16),
              ),
              selected: _type == 'task',
              onSelected: (_) => setState(() => _type = 'task'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            ChoiceChip(
              label: _buildChipLabel(
                '活动',
                selected: _type == 'event',
                leading: const Icon(Icons.celebration, size: 16),
              ),
              selected: _type == 'event',
              onSelected: (_) => setState(() => _type = 'event'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildParticipantsField() {
    return TextFormField(
      controller: _participantsController,
      decoration: _inputDecoration(
        label: '参与者',
        hint: '多个参与者用逗号分隔',
        icon: Icons.people,
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: _inputDecoration(
        label: '备注',
        icon: Icons.note,
      ).copyWith(alignLabelWithHint: true),
      maxLines: 2,
    );
  }

  Widget _buildRemindBeforeField() {
    // 预设值列表
    const presetValues = [5, 15, 30, 60, 120, 1440];

    // 判断当前值是否为自定义值
    final isCustomValue =
        _remindBefore != null &&
        _remindBefore! > 0 &&
        !presetValues.contains(_remindBefore);

    // 如果是自定义值，下拉菜单显示为 -1（自定义...）
    final dropdownValue = isCustomValue ? -1 : _remindBefore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int?>(
          key: ValueKey('remind_$dropdownValue'), // 使用 dropdownValue 作为 key
          value: dropdownValue,
          decoration: _inputDecoration(
            label: '提前提醒',
            icon: Icons.notifications,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('默认提醒 (15分钟)')),
            const DropdownMenuItem(value: 0, child: Text('不提醒')),
            const DropdownMenuItem(value: 5, child: Text('提前 5 分钟')),
            const DropdownMenuItem(value: 15, child: Text('提前 15 分钟')),
            const DropdownMenuItem(value: 30, child: Text('提前 30 分钟')),
            const DropdownMenuItem(value: 60, child: Text('提前 1 小时')),
            const DropdownMenuItem(value: 120, child: Text('提前 2 小时')),
            const DropdownMenuItem(value: 1440, child: Text('提前 1 天')),
            const DropdownMenuItem(value: -1, child: Text('自定义...')),
          ],
          onChanged: (value) async {
            if (value == -1) {
              // 自定义输入
              final customMinutes = await _showCustomRemindDialog();
              if (customMinutes != null) {
                setState(() {
                  _remindBefore = customMinutes;
                });
              } else {
                // 用户取消了输入，不改变当前值
                setState(() {}); // 强制刷新以重置下拉菜单显示
              }
            } else {
              setState(() {
                _remindBefore = value;
              });
            }
          },
          hint: const Text('选择提醒时间'),
        ),
        if (isCustomValue)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.orange[700]),
                const SizedBox(width: 6),
                Text(
                  '自定义: 提前 $_remindBefore 分钟',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange[700],
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _remindBefore = null; // 清除自定义值
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('清除', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        if (_remindBefore == null && !isCustomValue)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '💡 将在日程开始前 15 分钟提醒',
              style: TextStyle(fontSize: 12, color: Colors.blue[700]),
            ),
          ),
      ],
    );
  }

  Future<int?> _showCustomRemindDialog() async {
    final TextEditingController controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义提醒时间'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '分钟数',
            hintText: '输入提前提醒的分钟数',
            suffixText: '分钟',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text);
              if (minutes != null && minutes > 0) {
                Navigator.pop(context, minutes);
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('请输入有效的正整数')));
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _canSave && !_isLoading ? _handleSave : null,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1F2329), width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _buildGroupCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildChipLabel(
    String text, {
    required bool selected,
    Widget? leading,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.check, size: 14),
          ),
        if (leading != null) ...[leading, const SizedBox(width: 4)],
        Text(text),
      ],
    );
  }
}

/// 动画包装器：优化渲染性能
class AnimatedBottomSheetContent extends StatelessWidget {
  final DateTime? initialDate;
  final Schedule? existingSchedule;
  final Map<String, dynamic>? initialData;
  final Future<void> Function(Schedule) onSave;
  final bool use24HourFormat;

  const AnimatedBottomSheetContent({
    super.key,
    this.initialDate,
    this.existingSchedule,
    this.initialData,
    required this.onSave,
    this.use24HourFormat = true,
  });

  @override
  Widget build(BuildContext context) {
    return CreateScheduleBottomSheet(
      initialDate: initialDate,
      existingSchedule: existingSchedule,
      initialData: initialData,
      onSave: onSave,
      use24HourFormat: use24HourFormat,
    );
  }
}

/// 全局调用方法：显示创建/编辑日程底部抽屉
///
/// [context] - BuildContext
/// [initialDate] - 初始日期（创建模式）
/// [existingSchedule] - 现有日程（编辑模式）
/// [initialData] - AI 预填充数据
/// [onSave] - 保存回调
void showCreateScheduleBottomSheet(
  BuildContext context, {
  DateTime? initialDate,
  Schedule? existingSchedule,
  Map<String, dynamic>? initialData,
  required Future<void> Function(Schedule) onSave,
  bool use24HourFormat = true,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    enableDrag: true,
    isDismissible: true,
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    builder: (context) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 30),
          child: Opacity(
            opacity: 0.3 + (value * 0.7), // 从 30% 到 100% 透明度
            child: child,
          ),
        );
      },
      child: AnimatedBottomSheetContent(
        initialDate: initialDate,
        existingSchedule: existingSchedule,
        initialData: initialData,
        onSave: onSave,
        use24HourFormat: use24HourFormat,
      ),
    ),
  );
}
