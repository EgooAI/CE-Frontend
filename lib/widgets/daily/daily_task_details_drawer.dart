import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:get_it/get_it.dart';

import '../../models/daily/daily_task.dart';
import '../../repositories/daily_task_repository.dart';

class DailyTaskDetailsDrawer extends StatefulWidget {
  final DailyTask task;
  final Function(DailyTask)? onSave;
  final bool use24HourFormat;

  const DailyTaskDetailsDrawer({
    super.key,
    required this.task,
    this.onSave,
    this.use24HourFormat = false,
  });

  @override
  State<DailyTaskDetailsDrawer> createState() => _DailyTaskDetailsDrawerState();
}

class _DailyTaskDetailsDrawerState extends State<DailyTaskDetailsDrawer> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  TimeOfDay? _selectedTime;
  String? _selectedColor;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(
      text: widget.task.description ?? '',
    );
    _categoryController = TextEditingController(
      text: widget.task.category ?? '',
    );
    _selectedColor = widget.task.color;

    if (widget.task.startTime != null) {
      _selectedTime = TimeOfDay(
        hour: widget.task.startTime!.hour,
        minute: widget.task.startTime!.minute,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  /// 选择时间
  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(alwaysUse24HourFormat: widget.use24HourFormat),
          child: child ?? const SizedBox.shrink(),
        );
      },
      useRootNavigator: true,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  /// 保存更新
  Future<void> _saveChanges() async {
    final newTitle = _titleController.text.trim();
    if (newTitle.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('标题不能为空')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 构造新的 startTime
      DateTime? newStartTime;
      if (_selectedTime != null) {
        newStartTime = DateTime(
          1970,
          1,
          1,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
      }

      final repository = GetIt.instance<DailyTaskRepository>();
      final updatedTask = await repository.updateDailyTask(
        widget.task.id,
        title: newTitle,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        startTime: newStartTime,
        color: _selectedColor,
      );

      widget.onSave?.call(updatedTask);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存成功')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '日常详情',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 标题输入框
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '任务名称',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 描述输入框
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: '描述',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            // 分类输入框
            TextField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: '分类',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 推荐时间
            ListTile(
              title: const Text('推荐执行时间'),
              subtitle: Text(
                _selectedTime != null
                    ? _formatTime(_selectedTime!, widget.use24HourFormat)
                    : '未设置',
              ),
              trailing: const Icon(Icons.access_time),
              onTap: _selectTime,
            ),
            const SizedBox(height: 12),

            // 颜色选择器（简易版）
            ListTile(
              title: const Text('颜色'),
              trailing: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _parseColor(_selectedColor) ?? Colors.grey[300],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                ),
              ),
              onTap: _openColorPicker,
            ),
            const SizedBox(height: 24),

            // 保存按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    child: _isSaving
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
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 解析颜色字符串为 Color
  Color? _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return null;
    try {
      var hex = colorStr.toLowerCase().replaceAll('#', '');
      if (hex.startsWith('0x')) {
        hex = hex.substring(2);
      }
      if (hex.length == 6) {
        hex = 'ff$hex';
      }
      if (hex.length != 8) return null;
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return null;
    }
  }

  String _toHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  String _formatTime(TimeOfDay time, bool use24h) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    if (use24h) return '$hh:$mm';

    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? '上午 ' : '下午 ';
    return '$period${hour12.toString().padLeft(2, '0')}:$mm';
  }

  Future<void> _openColorPicker() async {
    final presetColors = <Color>[
      const Color(0xFFFF6B6B),
      const Color(0xFFFFA94D),
      const Color(0xFFFFD93D),
      const Color(0xFF6BCB77),
      const Color(0xFF4D96FF),
      const Color(0xFF9B89B3),
      const Color(0xFF5D9C59),
      const Color(0xFFEF476F),
    ];

    Color temp = _parseColor(_selectedColor) ?? presetColors.first;

    final selected = await showModalBottomSheet<Color?>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '选择颜色',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in presetColors)
                      GestureDetector(
                        onTap: () => Navigator.pop(context, c),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c == temp
                                  ? Colors.black87
                                  : Colors.black12,
                              width: c == temp ? 2 : 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showDialog<Color?>(
                      context: context,
                      builder: (context) {
                        Color current = temp;
                        return AlertDialog(
                          title: const Text('自定义颜色'),
                          content: SingleChildScrollView(
                            child: ColorPicker(
                              pickerColor: current,
                              onColorChanged: (c) => current = c,
                              enableAlpha: false,
                              portraitOnly: true,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, null),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, current),
                              child: const Text('确定'),
                            ),
                          ],
                        );
                      },
                    );

                    if (picked != null && context.mounted) {
                      Navigator.pop(context, picked);
                    }
                  },
                  icon: const Icon(Icons.palette_outlined),
                  label: const Text('更多颜色'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    backgroundColor: Colors.grey[200],
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedColor = _toHex(selected);
      });
    }
  }
}
