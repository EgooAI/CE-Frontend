import 'package:flutter/material.dart';
import '../models/schedule.dart';

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
  final Function(Schedule) onSave;

  const CreateScheduleBottomSheet({
    super.key,
    this.initialDate,
    this.existingSchedule,
    this.initialData,
    required this.onSave,
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

  DateTime? _startTime;
  DateTime? _endTime;
  bool _isAllDay = false;
  String _status = 'pending';
  String? _priority = 'medium';
  String? _type = 'task';
  int? _remindBefore; // 提前提醒分钟数

  bool _isLoading = false;
  String? _validationError; // 验证错误提示

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    if (widget.existingSchedule != null) {
      // 编辑模式：加载现有数据
      final schedule = widget.existingSchedule!;
      _titleController.text = schedule.title;
      _descriptionController.text = schedule.description ?? '';
      _locationController.text = schedule.location ?? '';
      _notesController.text = schedule.notes ?? '';
      _participantsController.text = schedule.participants ?? '';
      _startTime = schedule.startTime;
      _endTime = schedule.endTime;
      _isAllDay = schedule.allDay;
      _status = schedule.status;
      _priority = schedule.priority ?? 'medium';
      _type = schedule.type ?? 'task';
      _remindBefore = schedule.remindBefore;
    } else if (widget.initialData != null) {
      // AI 预填充模式
      final data = widget.initialData!;
      _titleController.text = data['title'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _locationController.text = data['location'] ?? '';
      _notesController.text = data['notes'] ?? '';
      _participantsController.text = data['participants'] ?? '';
      if (data['startTime'] != null) {
        // DateTime.parse() 会将带时区的时间转换为 UTC
        // 需要使用 .toLocal() 转换回本地时区，保持正确的日期
        _startTime = DateTime.parse(data['startTime']).toLocal();
      }
      if (data['endTime'] != null) {
        _endTime = DateTime.parse(data['endTime']).toLocal();
      }
      _isAllDay = data['allDay'] ?? false;
      _status = data['status'] ?? 'pending';
      _priority = data['priority'] ?? 'medium';
      _type = data['type'] ?? 'task';
      _remindBefore = data['remindBefore'];
    } else {
      // 创建模式：使用默认值
      final initialDate = widget.initialDate ?? DateTime.now();
      _startTime = _getSmartStartTime(initialDate);
      _endTime = null;
    }
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

  bool get _canSave {
    return _titleController.text.isNotEmpty && _startTime != null;
  }

  /// 合并的日期时间选择器（先选日期，再选时间）
  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final currentTime = isStart ? _startTime : _endTime;
    final initialDate = currentTime ?? DateTime.now();

    // 第一步：选择日期
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (date == null) return;

    // 第二步：选择时间（全天事件跳过）
    TimeOfDay? time;
    if (!_isAllDay) {
      final initialTime = currentTime != null
          ? TimeOfDay(hour: currentTime.hour, minute: currentTime.minute)
          : TimeOfDay(hour: isStart ? 9 : 10, minute: 0);

      time = await showTimePicker(context: context, initialTime: initialTime);

      if (time == null) return;
    }

    // 合并日期和时间
    setState(() {
      if (isStart) {
        _startTime = DateTime(
          date.year,
          date.month,
          date.day,
          time?.hour ?? 0,
          time?.minute ?? 0,
        );
      } else {
        _endTime = DateTime(
          date.year,
          date.month,
          date.day,
          time?.hour ?? 23,
          time?.minute ?? 59,
        );
      }
    });
  }

  void _toggleAllDay(bool? value) {
    setState(() {
      _isAllDay = value ?? false;
      if (_isAllDay && _startTime != null) {
        // 全天事件：设置开始时间为 00:00:00
        _startTime = DateTime(
          _startTime!.year,
          _startTime!.month,
          _startTime!.day,
          0,
          0,
          0,
        );
        // 自动设置结束时间为 23:59:59
        _endTime = DateTime(
          _startTime!.year,
          _startTime!.month,
          _startTime!.day,
          23,
          59,
          59,
        );
      }
    });
  }

  void _clearEndTime() {
    setState(() {
      _endTime = null;
    });
  }

  String? _validateForm() {
    if (_titleController.text.trim().isEmpty) {
      return '请输入日程标题';
    }
    if (_startTime == null) {
      return '请选择开始时间';
    }
    if (_endTime != null && !_endTime!.isAfter(_startTime!)) {
      return '结束时间必须晚于开始时间';
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
      // 构建 Schedule 对象
      final schedule = Schedule(
        id: widget.existingSchedule?.id ?? '',
        userId: widget.existingSchedule?.userId ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startTime: _startTime!,
        endTime: _endTime, // 不设置默认值，可以为 null
        allDay: _isAllDay,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        status: _status,
        type: _type,
        priority: _priority,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        participants: _participantsController.text.trim().isEmpty
            ? null
            : _participantsController.text.trim(),
        remindBefore: _remindBefore,
      );

      widget.onSave(schedule);

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
          color: Colors.white,
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
                      _buildTitleField(),
                      const SizedBox(height: 16),
                      _buildDateTimeSection(),
                      const SizedBox(height: 16),
                      _buildLocationField(),
                      const SizedBox(height: 16),
                      _buildRemindBeforeField(),
                      const SizedBox(height: 16),
                      _buildAllDaySwitch(),
                      const SizedBox(height: 16),
                      _buildStatusSection(),
                      const SizedBox(height: 16),
                      _buildPrioritySection(),
                      const SizedBox(height: 16),
                      _buildTypeSection(),
                      const SizedBox(height: 16),
                      _buildParticipantsField(),
                      const SizedBox(height: 16),
                      _buildDescriptionField(),
                      const SizedBox(height: 16),
                      _buildNotesField(),
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
      decoration: const InputDecoration(
        labelText: '标题 *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.title),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 开始时间（方形框）
        GestureDetector(
          onTap: () => _selectDateTime(context, true),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: '开始时间 *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.event),
            ),
            child: Text(
              _startTime != null
                  ? '${_startTime!.year}-${_startTime!.month.toString().padLeft(2, '0')}-${_startTime!.day.toString().padLeft(2, '0')} ${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                  : '请选择开始时间',
              style: TextStyle(
                color: _startTime != null ? Colors.black87 : Colors.grey,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 结束时间（方形框，带内部清空按钮）
        GestureDetector(
          onTap: () => _selectDateTime(context, false),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: '结束时间（可选）',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.event_available),
              suffixIcon: _endTime != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: _clearEndTime,
                      tooltip: '清空结束时间',
                    )
                  : null,
            ),
            child: Text(
              _endTime != null
                  ? '${_endTime!.year}-${_endTime!.month.toString().padLeft(2, '0')}-${_endTime!.day.toString().padLeft(2, '0')} ${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                  : '选择结束时间',
              style: TextStyle(
                color: _endTime != null ? Colors.black87 : Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllDaySwitch() {
    return SwitchListTile(
      title: const Text('全天事件'),
      value: _isAllDay,
      onChanged: _toggleAllDay,
      secondary: const Icon(Icons.event_available),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: '描述',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.description),
      ),
      maxLines: 3,
    );
  }

  Widget _buildLocationField() {
    return TextFormField(
      controller: _locationController,
      decoration: const InputDecoration(
        labelText: '地点',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_on),
      ),
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
              label: const Text('待办'),
              selected: _status == 'pending',
              onSelected: (_) => setState(() => _status = 'pending'),
            ),
            ChoiceChip(
              label: const Text('进行中'),
              selected: _status == 'in_progress',
              onSelected: (_) => setState(() => _status = 'in_progress'),
            ),
            ChoiceChip(
              label: const Text('已完成'),
              selected: _status == 'completed',
              onSelected: (_) => setState(() => _status = 'completed'),
            ),
            ChoiceChip(
              label: const Text('已取消'),
              selected: _status == 'cancelled',
              onSelected: (_) => setState(() => _status = 'cancelled'),
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
              label: const Text('低'),
              selected: _priority == 'low',
              onSelected: (_) => setState(() => _priority = 'low'),
              backgroundColor: Colors.green.shade100,
              selectedColor: Colors.green,
            ),
            ChoiceChip(
              label: const Text('中'),
              selected: _priority == 'medium',
              onSelected: (_) => setState(() => _priority = 'medium'),
              backgroundColor: Colors.orange.shade100,
              selectedColor: Colors.orange,
            ),
            ChoiceChip(
              label: const Text('高'),
              selected: _priority == 'high',
              onSelected: (_) => setState(() => _priority = 'high'),
              backgroundColor: Colors.red.shade100,
              selectedColor: Colors.red,
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
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event, size: 16),
                  SizedBox(width: 4),
                  Text('会议'),
                ],
              ),
              selected: _type == 'meeting',
              onSelected: (_) => setState(() => _type = 'meeting'),
            ),
            ChoiceChip(
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.task, size: 16),
                  SizedBox(width: 4),
                  Text('任务'),
                ],
              ),
              selected: _type == 'task',
              onSelected: (_) => setState(() => _type = 'task'),
            ),
            ChoiceChip(
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.celebration, size: 16),
                  SizedBox(width: 4),
                  Text('活动'),
                ],
              ),
              selected: _type == 'event',
              onSelected: (_) => setState(() => _type = 'event'),
            ),
            ChoiceChip(
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 16),
                  SizedBox(width: 4),
                  Text('日常'),
                ],
              ),
              selected: _type == 'daily',
              onSelected: (_) => setState(() => _type = 'daily'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildParticipantsField() {
    return TextFormField(
      controller: _participantsController,
      decoration: const InputDecoration(
        labelText: '参与者',
        hintText: '多个参与者用逗号分隔',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.people),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: const InputDecoration(
        labelText: '备注',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.note),
      ),
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
        const Text('提前提醒', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          key: ValueKey('remind_$dropdownValue'), // 使用 dropdownValue 作为 key
          value: dropdownValue,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.notifications),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
}

/// 动画包装器：优化渲染性能
class AnimatedBottomSheetContent extends StatelessWidget {
  final DateTime? initialDate;
  final Schedule? existingSchedule;
  final Map<String, dynamic>? initialData;
  final Function(Schedule) onSave;

  const AnimatedBottomSheetContent({
    super.key,
    this.initialDate,
    this.existingSchedule,
    this.initialData,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return CreateScheduleBottomSheet(
      initialDate: initialDate,
      existingSchedule: existingSchedule,
      initialData: initialData,
      onSave: onSave,
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
  required Function(Schedule) onSave,
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
      ),
    ),
  );
}
