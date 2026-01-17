import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:get_it/get_it.dart';
import '../../models/daily/daily_task.dart';
import '../../repositories/daily_task_repository.dart';
import '../../services/core/auth_service.dart';
import '../../services/sync/sync_queue_service.dart';
import '../../widgets/daily/daily_task_card.dart';
import '../../widgets/common/offline_banner.dart';
import '../../widgets/common/sync_indicator.dart';

/// 日常任务页面 - 主页面
class DailyPage extends StatefulWidget {
  const DailyPage({super.key});

  @override
  State<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<DailyPage> {
  final DailyTaskRepository _dailyTaskRepository = DailyTaskRepository();
  final _syncQueue = GetIt.instance<SyncQueueService>();
  bool _use24HourFormat = true;
  List<DailyTask> _tasks = [];
  String? _errorMessage;
  String? _autoFocusTaskId;
  bool _isSyncing = false;
  // 日常任务状态过滤器：'active' 或 'paused'
  String _dailyTaskStatusFilter = 'active';
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadConfig();
    _listenToPendingCount();
  }

  /// 监听待同步任务数量
  void _listenToPendingCount() {
    _syncQueue.pendingCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _pendingCount = count;
        });
      }
    });
  }

  /// 下拉刷新（强制从 API 获取最新数据）
  Future<void> _handlePullToRefresh() async {
    try {
      // 使用 refreshDailyTasks 强制刷新，忽略缓存
      final tasks = await _dailyTaskRepository.refreshDailyTasks(
        status: _dailyTaskStatusFilter,
      );

      if (mounted) {
        setState(() {
          _tasks = tasks;
          _errorMessage = null;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('刷新成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('刷新失败: $e')));
      }
    }
  }

  // 公开的刷新方法，供外部调用（MainPage 调用）
  void refreshData() {
    _loadTasks();
    _loadConfig();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTasks();
    _loadConfig();
  }

  /// 加载日常任务列表
  Future<void> _loadTasks() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final tasks = await _dailyTaskRepository.getDailyTasks(
        status: _dailyTaskStatusFilter,
      );
      setState(() {
        _tasks = tasks;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadConfig() async {
    try {
      final profile = await AuthService().getProfile();
      if (!mounted) return;
      setState(() {
        _use24HourFormat = profile.config.use24HourFormat;
      });
    } catch (_) {
      // 忽略配置加载失败，不阻塞页面
    }
  }

  /// 创建新日常任务
  Future<void> _createNewTask() async {
    try {
      final newTask = await _dailyTaskRepository.createDailyTask();
      setState(() {
        _autoFocusTaskId = newTask.id;
      });
      await _loadTasks();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('创建失败: $e')));
    }
  }

  /// 更新任务标题
  Future<void> _updateTaskTitle(String taskId, String newTitle) async {
    try {
      final updatedTask = await _dailyTaskRepository.updateDailyTask(
        taskId,
        title: newTitle,
      );
      setState(() {
        final index = _tasks.indexWhere((t) => t.id == taskId);
        if (index != -1) {
          _tasks[index] = updatedTask;
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('更新成功')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
    }
  }

  /// 删除任务
  Future<void> _deleteTask(String taskId) async {
    final confirmed = await showDialog<bool>(
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

    if (confirmed != true) return;

    try {
      await _dailyTaskRepository.deleteDailyTask(taskId);
      setState(() {
        _tasks.removeWhere((t) => t.id == taskId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除成功')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  /// 显示任务详情 Drawer
  void _showTaskDetailsDrawer(DailyTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DailyTaskDetailsDrawer(
        task: task,
        use24HourFormat: _use24HourFormat,
        onSave: (updatedTask) {
          setState(() {
            final index = _tasks.indexWhere((t) => t.id == task.id);
            if (index != -1) {
              _tasks[index] = updatedTask;
            }
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('我的日常'),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _dailyTaskStatusFilter,
                  isDense: true,
                  style: TextStyle(color: Colors.grey[800], fontSize: 13),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: Colors.grey[700],
                    size: 20,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'active',
                      child: Text(
                        '活跃',
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'paused',
                      child: Text(
                        '暂停',
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null && value != _dailyTaskStatusFilter) {
                      setState(() {
                        _dailyTaskStatusFilter = value;
                      });
                      _loadTasks();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          // 同步状态指示器
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SyncIndicator(isSyncing: true, size: 20),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _handlePullToRefresh,
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          // 离线状态横幅
          OfflineBanner(showPendingCount: true, pendingCount: _pendingCount),
          // 主体内容
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewTask,
        child: const Icon(Icons.add),
        tooltip: '新增任务',
      ),
    );
  }

  Widget _buildBody() {
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
              onPressed: _loadTasks,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _handlePullToRefresh,
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    '还没有日常任务',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击 + 号创建第一个任务吧',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handlePullToRefresh,
      child: ListView(children: _buildTaskGroups()),
    );
  }

  List<Widget> _buildTaskGroups() {
    final uncategorized = _tasks
        .where((t) => t.category == null || t.category!.trim().isEmpty)
        .toList();

    final Map<String, List<DailyTask>> grouped = {};
    for (final task in _tasks) {
      final cat = task.category?.trim();
      if (cat == null || cat.isEmpty) continue;
      grouped.putIfAbsent(cat, () => []).add(task);
    }

    final sortedCats = grouped.keys.toList()..sort((a, b) => a.compareTo(b));

    final List<Widget> items = [];

    if (uncategorized.isNotEmpty) {
      items.add(_buildSectionHeader('未分类'));
      items.addAll(uncategorized.map(_buildTaskItem));
    }

    for (final cat in sortedCats) {
      items.add(_buildSectionHeader(cat));
      items.addAll(grouped[cat]!.map(_buildTaskItem));
    }

    return items;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTaskItem(DailyTask task) {
    return DailyTaskCard(
      key: ValueKey(task.id),
      task: task,
      autoFocus: _autoFocusTaskId == task.id,
      onTitleChanged: (newTitle) => _updateTaskTitle(task.id, newTitle),
      onDelete: () => _deleteTask(task.id),
      onDetailsTap: () => _showTaskDetailsDrawer(task),
      onTaskUpdated: (updated) async {
        // 任务更新后，先更新本地状态，然后刷新缓存
        // 如果切换了active/paused状态，任务可能不再符合过滤条件
        if (updated.status != _dailyTaskStatusFilter) {
          // 状态不匹配，从列表移除
          setState(() {
            _tasks.removeWhere((t) => t.id == updated.id);
          });
        } else {
          // 状态匹配，更新本地任务
          setState(() {
            final idx = _tasks.indexWhere((t) => t.id == updated.id);
            if (idx != -1) {
              _tasks[idx] = updated;
            }
          });
        }

        // 后台刷新缓存，确保下次加载时数据是最新的
        _dailyTaskRepository.refreshDailyTasks(status: _dailyTaskStatusFilter);
      },
      onFinishEditing: () {
        if (_autoFocusTaskId == task.id) {
          setState(() {
            _autoFocusTaskId = null;
          });
        }
      },
      use24HourFormat: _use24HourFormat,
      showInfo: true,
    );
  }
}

/// 日常任务详情 Drawer
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
