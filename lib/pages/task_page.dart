import 'package:flutter/material.dart';
import '../models/schedule.dart';
import '../services/schedule_service.dart';
import '../widgets/schedule_card.dart';
import '../widgets/create_schedule_bottom_sheet.dart';

/// 任务页面：所有日程的集中显示管理
class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage>
    with SingleTickerProviderStateMixin {
  final _scheduleService = ScheduleService();

  late TabController _tabController;
  List<Schedule> _allTasks = [];
  final Set<String> _expandedTaskIds = {};

  bool _isLoading = true;
  String? _errorMessage;

  // Tab 配置
  final List<TaskTab> _tabs = [
    TaskTab(label: '即将开始', status: 'upcoming', icon: Icons.upcoming),
    TaskTab(label: '待进行', status: 'pending', icon: Icons.pending_actions),
    TaskTab(label: '进行中', status: 'in_progress', icon: Icons.play_circle),
    TaskTab(label: '已完成', status: 'completed', icon: Icons.check_circle),
    TaskTab(label: '已取消', status: 'cancelled', icon: Icons.cancel),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadTasks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 公开的刷新方法，供外部调用
  void refreshData() {
    _loadTasks();
  }

  // 加载任务数据
  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allSchedules = await _scheduleService.getSchedules();

      // 显示所有类型的日程（不区分 task/event/meeting）
      // 按开始时间排序
      allSchedules.sort((a, b) => a.startTime.compareTo(b.startTime));

      setState(() {
        _allTasks = allSchedules;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // 根据状态筛选任务
  List<Schedule> _getTasksByStatus(String status) {
    if (status == 'upcoming') {
      // 即将开始：今天的待办任务
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final tomorrowStart = DateTime(now.year, now.month, now.day + 1);

      return _allTasks.where((task) {
        return task.status == 'pending' &&
            !task.startTime.isBefore(todayStart) &&
            task.startTime.isBefore(tomorrowStart);
      }).toList();
    }

    return _allTasks.where((task) => task.status == status).toList();
  }

  // 切换任务卡片展开/折叠
  void _toggleTaskExpanded(String taskId) {
    setState(() {
      if (_expandedTaskIds.contains(taskId)) {
        _expandedTaskIds.remove(taskId);
      } else {
        _expandedTaskIds.add(taskId);
      }
    });
  }

  // 显示创建任务对话框
  void _showCreateDialog() {
    showCreateScheduleBottomSheet(
      context,
      initialDate: DateTime.now(),
      onSave: _handleCreate,
    );
  }

  // 显示编辑任务对话框
  void _showEditDialog(Schedule task) {
    showCreateScheduleBottomSheet(
      context,
      existingSchedule: task,
      onSave: (updatedTask) => _handleUpdate(task.id, updatedTask),
    );
  }

  // 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog(Schedule task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除任务「${task.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _handleDelete(task.id);
    }
  }

  // 创建任务
  Future<void> _handleCreate(Schedule task) async {
    try {
      await _scheduleService.createSchedule(task.toJson());
      await _loadTasks();

      if (mounted) {
        Future.microtask(() {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('任务已创建'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 更新任务
  Future<void> _handleUpdate(String id, Schedule updatedTask) async {
    try {
      await _scheduleService.updateSchedule(id, updatedTask.toJson());
      await _loadTasks();

      if (mounted) {
        Future.microtask(() {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('任务已更新'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 删除任务
  Future<void> _handleDelete(String id) async {
    try {
      await _scheduleService.deleteSchedule(id);
      await _loadTasks();

      if (mounted) {
        Future.microtask(() {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('任务已删除'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
        });
      }
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

  // 更新任务状态
  Future<void> _handleStatusChange(Schedule task, String newStatus) async {
    try {
      final updatedTask = task.copyWith(status: newStatus);
      await _scheduleService.updateSchedule(task.id, updatedTask.toJson());
      await _loadTasks();

      if (mounted) {
        final statusText = newStatus == 'completed'
            ? '已完成'
            : newStatus == 'cancelled'
            ? '已取消'
            : '进行中';

        Future.microtask(() {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('已标记为$statusText'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('状态更新失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateDialog,
            tooltip: '创建任务',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((tab) {
            final tasks = _getTasksByStatus(tab.status);
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, size: 18),
                  const SizedBox(width: 4),
                  Text(tab.label),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(tab.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${tasks.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(tab.status),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) => _buildTaskList(tab.status)).toList(),
            ),
    );
  }

  // 构建任务列表
  Widget _buildTaskList(String status) {
    final tasks = _getTasksByStatus(status);

    if (tasks.isEmpty) {
      return _buildEmptyState(status);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final isExpanded = _expandedTaskIds.contains(task.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ScheduleCard(
            schedule: task,
            isExpanded: isExpanded,
            onTap: () => _toggleTaskExpanded(task.id),
            onStatusChanged: (newStatus) =>
                _handleStatusChange(task, newStatus),
            onEdit: () => _showEditDialog(task),
            onDelete: () => _showDeleteConfirmDialog(task),
          ),
        );
      },
    );
  }

  // 空状态视图
  Widget _buildEmptyState(String status) {
    final emptyInfo = _getEmptyInfo(status);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(emptyInfo.icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            emptyInfo.message,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          if (status == 'pending' || status == 'upcoming') ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('创建任务'),
            ),
          ],
        ],
      ),
    );
  }

  // 错误视图
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? '加载失败',
            style: const TextStyle(fontSize: 16, color: Colors.red),
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

  // 获取状态颜色
  Color _getStatusColor(String status) {
    switch (status) {
      case 'upcoming':
        return Colors.orange;
      case 'pending':
        return Colors.grey;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // 获取空状态信息
  EmptyInfo _getEmptyInfo(String status) {
    switch (status) {
      case 'upcoming':
        return EmptyInfo(icon: Icons.today, message: '今天没有即将开始的任务');
      case 'pending':
        return EmptyInfo(icon: Icons.check_circle_outline, message: '暂无待办任务');
      case 'in_progress':
        return EmptyInfo(icon: Icons.play_circle_outline, message: '暂无进行中的任务');
      case 'completed':
        return EmptyInfo(icon: Icons.done_all, message: '还没有完成的任务');
      case 'cancelled':
        return EmptyInfo(icon: Icons.cancel_outlined, message: '没有已取消的任务');
      default:
        return EmptyInfo(icon: Icons.inbox, message: '暂无任务');
    }
  }
}

// Tab 配置类
class TaskTab {
  final String label;
  final String status;
  final IconData icon;

  TaskTab({required this.label, required this.status, required this.icon});
}

// 空状态信息类
class EmptyInfo {
  final IconData icon;
  final String message;

  EmptyInfo({required this.icon, required this.message});
}
