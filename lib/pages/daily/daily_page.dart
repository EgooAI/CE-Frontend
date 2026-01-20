import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../models/daily/daily_task.dart';
import '../../repositories/daily_task_repository.dart';
import '../../services/core/auth_service.dart';
import '../../services/sync/sync_queue_service.dart';
import '../../widgets/common/offline_banner.dart';
import '../../widgets/common/sync_indicator.dart';
import '../../widgets/daily/daily_status_filter_dropdown.dart';
import '../../widgets/daily/daily_error_view.dart';
import '../../widgets/daily/daily_empty_state.dart';
import '../../widgets/daily/daily_task_group_list.dart';
import '../../widgets/daily/daily_task_details_drawer.dart';

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
    // 避免重复请求：初始化已加载，这里仅保持配置同步
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
      final profile = await AuthService().getUser();
      if (profile == null) return;
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
            DailyStatusFilterDropdown(
              value: _dailyTaskStatusFilter,
              onChanged: (value) {
                setState(() {
                  _dailyTaskStatusFilter = value;
                });
                _loadTasks();
              },
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
      return DailyErrorView(message: _errorMessage!, onRetry: _loadTasks);
    }

    if (_tasks.isEmpty) {
      return DailyEmptyState(onRefresh: _handlePullToRefresh);
    }

    return DailyTaskGroupList(
      tasks: _tasks,
      statusFilter: _dailyTaskStatusFilter,
      autoFocusTaskId: _autoFocusTaskId,
      use24HourFormat: _use24HourFormat,
      onRefresh: _handlePullToRefresh,
      onTitleChanged: _updateTaskTitle,
      onDelete: _deleteTask,
      onDetailsTap: _showTaskDetailsDrawer,
      onTaskUpdated: (updated) async {
        if (updated.status != _dailyTaskStatusFilter) {
          setState(() {
            _tasks.removeWhere((t) => t.id == updated.id);
          });
        } else {
          setState(() {
            final idx = _tasks.indexWhere((t) => t.id == updated.id);
            if (idx != -1) {
              _tasks[idx] = updated;
            }
          });
        }

        _dailyTaskRepository.refreshDailyTasks(status: _dailyTaskStatusFilter);
      },
      onFinishEditing: (taskId) {
        if (_autoFocusTaskId == taskId) {
          setState(() {
            _autoFocusTaskId = null;
          });
        }
      },
    );
  }
}
