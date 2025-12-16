import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/daily_task.dart';
import '../services/daily_task_service.dart';

/// 日常任务卡片/行组件
/// 支持编辑标题、查看详情
class DailyTaskCard extends StatefulWidget {
  final DailyTask task;
  final VoidCallback? onDelete;
  final Function(String)? onTitleChanged;
  final Function(DailyTask)? onTaskUpdated;
  final VoidCallback? onDetailsTap;
  final VoidCallback? onFinishEditing;
  final bool autoFocus;
  final Function(String?)? onColorChanged;
  final bool use24HourFormat;
  final bool showInfo;

  const DailyTaskCard({
    super.key,
    required this.task,
    this.onDelete,
    this.onTitleChanged,
    this.onTaskUpdated,
    this.onDetailsTap,
    this.onFinishEditing,
    this.autoFocus = false,
    this.onColorChanged,
    this.use24HourFormat = true,
    this.showInfo = false,
  });

  @override
  State<DailyTaskCard> createState() => _DailyTaskCardState();
}

class _DailyTaskCardState extends State<DailyTaskCard> {
  late TextEditingController _titleController;
  bool _isEditing = false;
  bool _submittedInSession = false;
  final FocusNode _titleFocus = FocusNode();
  final DailyTaskService _dailyTaskService = DailyTaskService();
  String? _colorHex;

  Color? _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;

    // 支持 "#RRGGBB"、"#AARRGGBB"、"0xAARRGGBB"、"0xRRGGBB"
    var value = hex.toLowerCase().replaceAll('#', '');
    if (value.startsWith('0x')) {
      value = value.substring(2);
    }

    if (value.length == 6) {
      value = 'ff$value';
    }
    if (value.length != 8) return null;

    try {
      return Color(int.parse(value, radix: 16));
    } catch (_) {
      return null;
    }
  }

  String _toHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _isEditing = widget.autoFocus;
    _submittedInSession = false;
    _colorHex = widget.task.color;
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) {
        _finishEdit();
      }
    });
  }

  @override
  void didUpdateWidget(covariant DailyTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.task.title != widget.task.title) {
      _titleController.text = widget.task.title;
    }
    if (oldWidget.task.color != widget.task.color) {
      _colorHex = widget.task.color;
    }
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() {
      _isEditing = true;
      _submittedInSession = false;
    });
  }

  void _finishEdit() async {
    if (_submittedInSession) return;
    _submittedInSession = true; // guard immediately to avoid double submit
    final newTitle = _titleController.text.trim();
    if (newTitle.isEmpty) {
      _titleController.text = widget.task.title;
      setState(() {
        _isEditing = false;
      });
      _submittedInSession = false; // allow retry if user cleared text
      widget.onFinishEditing?.call();
      return;
    }

    if (newTitle != widget.task.title) {
      // 调用回调并上传后端
      widget.onTitleChanged?.call(newTitle);
    }

    setState(() {
      _isEditing = false;
    });
    widget.onFinishEditing?.call();
  }

  Future<void> _toggleCheckIn(bool? checked) async {
    final newChecked = checked ?? false;
    final prevCompleted = widget.task.todayCompleted ?? false;

    try {
      if (newChecked) {
        // 打卡：无 note 的快速打卡
        await _dailyTaskService.logDailyTask(
          widget.task.id,
          completed: true,
          note: '',
        );
        // 更新任务状态
        final updatedTask = widget.task.copyWith(todayCompleted: true);
        widget.onTaskUpdated?.call(updatedTask);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ 打卡成功'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        // 取消打卡
        await _dailyTaskService.cancelTodayLog(widget.task.id);
        // 更新任务状态
        final updatedTask = widget.task.copyWith(todayCompleted: false);
        widget.onTaskUpdated?.call(updatedTask);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ 已取消打卡'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      // 恢复之前的状态
      final revertTask = widget.task.copyWith(todayCompleted: prevCompleted);
      widget.onTaskUpdated?.call(revertTask);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }

  Future<void> _showSummaryDrawer() async {
    // 加载今日打卡记录
    DailyTaskLog? todayLog;
    try {
      final logs = await _dailyTaskService.getDailyTaskLogs(
        widget.task.id,
        days: 1,
      );
      if (logs.isNotEmpty) {
        final today = DateTime.now();
        todayLog =
            logs.firstWhere(
                  (log) =>
                      log.date.year == today.year &&
                      log.date.month == today.month &&
                      log.date.day == today.day,
                  orElse: () => null as dynamic,
                )
                as DailyTaskLog?;
      }
    } catch (e) {
      // 加载失败，继续显示drawer
      debugPrint('Failed to load today logs: $e');
    }

    final TextEditingController noteController = TextEditingController();
    if (todayLog != null &&
        todayLog.note != null &&
        todayLog.note!.isNotEmpty) {
      noteController.text = todayLog.note!;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                todayLog != null ? '修改总结' : '添加总结',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (todayLog != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '已打卡',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                autofocus: true,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '今天完成得怎么样？',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final note = noteController.text.trim();
                      Navigator.pop(context); // 先关闭 drawer

                      try {
                        // 打卡（带总结）
                        await _dailyTaskService.logDailyTask(
                          widget.task.id,
                          completed: true,
                          note: note,
                        );
                        // 更新任务状态
                        final updatedTask = widget.task.copyWith(
                          todayCompleted: true,
                        );
                        widget.onTaskUpdated?.call(updatedTask);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                todayLog != null ? '✓ 已更新总结' : '✓ 打卡成功（已添加总结）',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('打卡失败: $e')));
                      }
                    },
                    child: const Text('确认'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // 取消编辑不再需要显式按钮，保留逻辑以便未来可能调用

  Future<void> _toggleTaskStatus() async {
    final newStatus = widget.task.status == 'active' ? 'paused' : 'active';
    final statusText = newStatus == 'active' ? '活跃' : '暂停';

    try {
      final updated = await _dailyTaskService.toggleDailyTaskStatus(
        widget.task.id,
        newStatus,
      );
      if (!mounted) return;
      widget.onTaskUpdated?.call(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已切换到$statusText状态'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('状态切换失败: $e')));
    }
  }

  Future<void> _confirmDelete() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个日常任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (result == true) {
      widget.onDelete?.call();
    }
  }

  Future<void> _updateColor(String? hex) async {
    final prev = _colorHex;
    setState(() {
      _colorHex = hex;
    });
    try {
      final updated = await _dailyTaskService.updateDailyTask(
        widget.task.id,
        color: hex,
      );
      if (!mounted) return;
      setState(() {
        _colorHex = updated.color;
      });
      widget.onTaskUpdated?.call(updated);
      widget.onColorChanged?.call(updated.color);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _colorHex = prev;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新颜色失败: $e')));
    }
  }

  Future<void> _pickColor() async {
    final presetColors = <Color>[
      const Color(0xFFFF6B6B), // coral
      const Color(0xFFFFA94D), // orange
      const Color(0xFFFFD93D), // yellow
      const Color(0xFF6BCB77), // green
      const Color(0xFF4D96FF), // blue
      const Color(0xFF9B89B3), // purple
      const Color(0xFF5D9C59), // moss
      const Color(0xFFEF476F), // pink red
    ];

    Color temp = _colorFromHex(_colorHex) ?? presetColors.first;

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
      await _updateColor(_toHex(selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color? accentColor = _colorFromHex(_colorHex);

    final card = Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 左侧色条展示任务颜色，点击可修改
            GestureDetector(
              onTap: _pickColor,
              child: Container(
                width: 6,
                height: 52,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: accentColor ?? Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            // 左侧：复选框（用于打卡）
            Checkbox(
              value: widget.task.todayCompleted ?? false,
              onChanged: _toggleCheckIn,
            ),
            const SizedBox(width: 8),

            // 中间：标题编辑框 / 标题文本
            Expanded(
              child: _isEditing
                  ? TextField(
                      controller: _titleController,
                      autofocus: true,
                      focusNode: _titleFocus,
                      onSubmitted: (_) => _finishEdit(),
                      decoration: InputDecoration(
                        hintText: '输入任务名称',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _startEdit,
                      onDoubleTap: _startEdit,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.task.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: (widget.task.todayCompleted ?? false)
                                  ? Colors.grey[600]
                                  : Colors.black,
                              decoration: (widget.task.todayCompleted ?? false)
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (widget.task.startTime != null ||
                              (widget.task.category != null &&
                                  widget.task.category!.isNotEmpty))
                            Row(
                              children: [
                                if (widget.task.startTime != null) ...[
                                  const Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.task.getTimeDisplay(
                                      use24HourFormat: widget.use24HourFormat,
                                      useChinesePeriod: true,
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                                if (widget.task.startTime != null &&
                                    widget.task.category != null &&
                                    widget.task.category!.isNotEmpty)
                                  const SizedBox(width: 12),
                                if (widget.task.category != null &&
                                    widget.task.category!.isNotEmpty)
                                  Text(
                                    widget.task.category!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          if (widget.task.description != null &&
                              widget.task.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.task.description!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
            // 右端 info 按钮
            if (widget.showInfo) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Colors.blueGrey,
                ),
                tooltip: '详情',
                onPressed: widget.onDetailsTap,
              ),
            ],
          ],
        ),
      ),
    );

    final slidableCard = Slidable(
      key: Key(widget.task.id),
      // 左滑显示"总结"按钮
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          CustomSlidableAction(
            onPressed: (_) => _showSummaryDrawer(),
            padding: EdgeInsets.zero,
            autoClose: true,
            backgroundColor: Colors.blue,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_note, color: Colors.white, size: 24),
                SizedBox(height: 4),
                Text(
                  '总结',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // 右滑显示"状态切换"和"删除"按钮
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.40,
        children: [
          CustomSlidableAction(
            onPressed: (_) => _toggleTaskStatus(),
            padding: EdgeInsets.zero,
            autoClose: true,
            backgroundColor: widget.task.status == 'active'
                ? Colors.orange
                : Colors.green,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.task.status == 'active'
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.task.status == 'active' ? '暂停' : '激活',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          CustomSlidableAction(
            onPressed: (_) => _confirmDelete(),
            padding: EdgeInsets.zero,
            autoClose: true,
            backgroundColor: Colors.red,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete, color: Colors.white, size: 24),
                SizedBox(height: 4),
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
        ],
      ),
      child: card,
    );

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
}
