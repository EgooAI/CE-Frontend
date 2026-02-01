import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../models/schedule/schedule.dart';
import '../../repositories/schedule_repository.dart';
import '../../services/core/auth_service.dart';
import '../../services/schedule/schedule_service.dart';
import '../../services/sync/sync_queue_service.dart';
import '../../widgets/schedule/create_schedule_bottom_sheet.dart';
import '../../widgets/schedule/schedule_card.dart';
import '../../widgets/common/offline_banner.dart';
import '../../widgets/common/sync_indicator.dart';
import '../../widgets/task/task_schedule_type_dropdown.dart';
import '../../widgets/task/task_error_view.dart';
import '../../widgets/task/task_batch_action_bar.dart';
import '../../widgets/task/task_list_view.dart';
import '../../utils/crud_force_refresh.dart';
import '../main_page.dart';

/// 任务页面：所有日程的集中显示管理
class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage>
    with SingleTickerProviderStateMixin {
  final _scheduleRepository = ScheduleRepository();
  final _syncQueue = GetIt.instance<SyncQueueService>();

  late TabController _tabController;
  List<Schedule> _allTasks = [];
  final Set<String> _expandedTaskIds = {};
  bool _use24HourFormat = true;

  // 批量选择模式
  bool _isSelectionMode = false;
  final Set<String> _selectedTaskIds = {};

  String _selectedScheduleType = 'all';

  final Map<String, String> _scheduleTypeOptions = {
    'all': '全部日程',
    'task': '任务',
    'meeting': '会议',
    'event': '事件',
  };

  String? _errorMessage;
  bool _isSyncing = false;
  int _pendingCount = 0;

  // Tab 配置
  final List<TaskTab> _tabs = [
    TaskTab(label: '待办/进行中', status: 'active', icon: Icons.view_agenda),
    TaskTab(label: '已完成', status: 'completed', icon: Icons.check_circle),
    TaskTab(label: '未完成', status: 'failed', icon: Icons.warning_amber_rounded),
    TaskTab(label: '已取消', status: 'cancelled', icon: Icons.cancel),
  ];

  final Map<String, bool> _activeSectionExpanded = {
    'upcoming': true,
    'pending': true,
    'in_progress': true,
  };
  int _expandResetTick = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    _requestExpandAllActiveSections();
    _loadTasks(staleWhileRevalidate: true);
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

  /// 手动触发同步
  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    try {
      await _syncQueue.processPendingTasks();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('同步完成')));
        _loadTasks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('同步失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 避免重复请求：初始化已加载，这里仅保持配置同步
    _loadConfig();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  // 公开的刷新方法，供外部调用
  void refreshData() {
    _loadTasks(staleWhileRevalidate: true);
    _loadConfig();
    _requestExpandAllActiveSections();
  }

  void _requestExpandAllActiveSections() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _activeSectionExpanded.updateAll((key, value) => true);
        _expandResetTick++;
      });
    });
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging && mounted) {
      _requestExpandAllActiveSections();
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
      // 忽略配置加载失败
    }
  }

  Future<void> _refreshTasksInBackground() async {
    try {
      final allSchedules = await _scheduleRepository.getAllSchedules(
        forceRefresh: false,
      );

      allSchedules.sort((a, b) => a.startTime.compareTo(b.startTime));

      if (mounted) {
        setState(() {
          _allTasks = allSchedules;
          _errorMessage = null;
        });
      }
    } catch (_) {
      // 静默失败：保留缓存内容
    }
  }

  // 加载任务数据
  Future<void> _loadTasks({
    bool staleWhileRevalidate = false,
    bool forceRefresh = false,
  }) async {
    setState(() {
      _errorMessage = null;
    });

    if (staleWhileRevalidate && !forceRefresh) {
      final cachedTasks = await _scheduleRepository.getCachedAllSchedules();
      if (cachedTasks != null) {
        cachedTasks.sort((a, b) => a.startTime.compareTo(b.startTime));
        setState(() {
          _allTasks = cachedTasks;
        });
      }

      _refreshTasksInBackground();
      return;
    }

    try {
      final allSchedules = await _scheduleRepository.getAllSchedules(
        forceRefresh: forceRefresh,
      );

      // 显示所有类型的日程（不区分 task/event/meeting）
      // 按开始时间排序
      allSchedules.sort((a, b) => a.startTime.compareTo(b.startTime));

      setState(() {
        _allTasks = allSchedules;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _handlePullToRefresh() async {
    try {
      await _loadTasks(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('已刷新'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('刷新失败: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
      }
    }
  }

  // 根据状态筛选任务
  List<Schedule> _getTasksByStatus(
    String status,
    List<Schedule> tasksToFilter,
  ) {
    if (status == 'active') {
      return _getActiveTasks(tasksToFilter);
    }

    if (status == 'upcoming') {
      // 即将开始：今天的待办任务
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final tomorrowStart = DateTime(now.year, now.month, now.day + 1);

      return tasksToFilter.where((task) {
        return task.status == 'pending' &&
            !task.startTime.isBefore(todayStart) &&
            task.startTime.isBefore(tomorrowStart);
      }).toList();
    }

    return tasksToFilter.where((task) => task.status == status).toList();
  }

  List<Schedule> _getUpcomingTasks(List<Schedule> tasksToFilter) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = DateTime(now.year, now.month, now.day + 1);

    return tasksToFilter.where((task) {
      return task.status == 'pending' &&
          !task.startTime.isBefore(todayStart) &&
          task.startTime.isBefore(tomorrowStart);
    }).toList();
  }

  List<Schedule> _getPendingTasks(List<Schedule> tasksToFilter) {
    final upcomingIds = _getUpcomingTasks(
      tasksToFilter,
    ).map((task) => task.id).toSet();
    return tasksToFilter.where((task) {
      return task.status == 'pending' && !upcomingIds.contains(task.id);
    }).toList();
  }

  List<Schedule> _getInProgressTasks(List<Schedule> tasksToFilter) {
    return tasksToFilter.where((task) => task.status == 'in_progress').toList();
  }

  List<Schedule> _getActiveTasks(List<Schedule> tasksToFilter) {
    final upcoming = _getUpcomingTasks(tasksToFilter);
    final pending = _getPendingTasks(tasksToFilter);
    final inProgress = _getInProgressTasks(tasksToFilter);
    final unique = <String, Schedule>{};
    for (final task in [...upcoming, ...pending, ...inProgress]) {
      unique[task.id] = task;
    }
    return unique.values.toList();
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
      use24HourFormat: _use24HourFormat,
    );
  }

  // 显示编辑任务对话框
  void _showEditDialog(Schedule task) {
    showCreateScheduleBottomSheet(
      context,
      existingSchedule: task,
      onSave: (updatedTask) => _handleUpdate(task.id, updatedTask),
      use24HourFormat: _use24HourFormat,
    );
  }

  // 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog(Schedule task) async {
    final isRecurringInstance = task.parentId != null;

    if (isRecurringInstance) {
      String selectedOption = 'single';

      final result = await showDialog<Map<String, String>?>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('删除重复任务'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('「${task.title}」是重复系列中的一条。请选择删除方式：'),
                    const SizedBox(height: 16),
                    RadioListTile<String>(
                      title: const Text('仅删除该任务'),
                      value: 'single',
                      groupValue: selectedOption,
                      onChanged: (v) =>
                          setState(() => selectedOption = v ?? 'single'),
                    ),
                    RadioListTile<String>(
                      title: const Text('仅删除模板'),
                      subtitle: const Text('保留所有已生成的实例'),
                      value: 'none',
                      groupValue: selectedOption,
                      onChanged: (v) =>
                          setState(() => selectedOption = v ?? 'single'),
                    ),
                    RadioListTile<String>(
                      title: const Text('删除模板 + 所有待办'),
                      subtitle: const Text('删除未开始的实例'),
                      value: 'future',
                      groupValue: selectedOption,
                      onChanged: (v) =>
                          setState(() => selectedOption = v ?? 'single'),
                    ),
                    RadioListTile<String>(
                      title: const Text('删除模板 + 所有任务（含历史）'),
                      value: 'all',
                      groupValue: selectedOption,
                      onChanged: (v) =>
                          setState(() => selectedOption = v ?? 'single'),
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
                    style: TextButton.styleFrom(
                      foregroundColor: selectedOption == 'single'
                          ? Colors.grey
                          : Colors.red,
                    ),
                    child: const Text('确认删除'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == null) return;

      final action = result['action'] ?? 'single';
      if (action == 'single') {
        _handleDelete(task.id);
      } else {
        await _handleDeleteSeries(task.parentId!, action);
      }
    } else {
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
  }

  // 创建任务
  Future<void> _handleCreate(Schedule task) async {
    try {
      await runCrudWithForceRefresh(
        action: () => _scheduleRepository.createSchedule(task),
        forceRefresh: () => _loadTasks(forceRefresh: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 任务创建成功'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // 询问是否跳转到日历页面
        final shouldNavigate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('跳转到日历'),
            content: const Text('是否跳转到日历页面查看任务?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('跳转'),
              ),
            ],
          ),
        );

        if (shouldNavigate == true && mounted) {
          // 切换到日历页面并跳转到任务日期
          try {
            if (context.mounted) {
              // 向上查找 MainPage 的 State 并调用 navigateToScheduleDate
              final mainPageState = context
                  .findAncestorStateOfType<State<MainPage>>();
              if (mainPageState != null) {
                (mainPageState as dynamic).navigateToScheduleDate(
                  task.startTime,
                );
              } else {
                debugPrint('无法找到 MainPage');
              }
            }
          } catch (e) {
            debugPrint('切换到日历页面失败: $e');
          }
        }
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
      await runCrudWithForceRefresh(
        action: () => _scheduleRepository.updateSchedule(updatedTask),
        forceRefresh: () => _loadTasks(forceRefresh: true),
      );

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
      await runCrudWithForceRefresh(
        action: () => _scheduleRepository.deleteSchedule(id),
        forceRefresh: () => _loadTasks(forceRefresh: true),
      );

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

  // 删除重复任务模板
  Future<void> _handleDeleteSeries(
    String parentId,
    String deleteInstances,
  ) async {
    try {
      final scheduleService = GetIt.instance<ScheduleService>();
      await runCrudWithForceRefresh(
        action: () => scheduleService.deleteRecurrenceTemplate(
          parentId,
          deleteInstances: deleteInstances,
        ),
        forceRefresh: () => _loadTasks(forceRefresh: true),
      );

      if (mounted) {
        final deleteText =
            {'future': '模板+待办实例', 'all': '模板+全部实例'}[deleteInstances] ?? '仅模板';

        Future.microtask(() {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('已删除：$deleteText'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
          }
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

  // 切换选择模式
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedTaskIds.clear();
      }
    });
  }

  // 切换任务选中状态
  void _toggleTaskSelection(String taskId) {
    if (!mounted) return;
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
      } else {
        _selectedTaskIds.add(taskId);
      }
    });
  }

  // 全选/取消全选
  void _toggleSelectAll(List<Schedule> tasks) {
    if (!mounted) return;
    setState(() {
      final taskIds = tasks.map((t) => t.id).toSet();
      if (_selectedTaskIds.containsAll(taskIds)) {
        _selectedTaskIds.clear();
      } else {
        _selectedTaskIds.clear();
        _selectedTaskIds.addAll(taskIds);
      }
    });
  }

  // 批量删除确认
  Future<void> _showBatchDeleteConfirmDialog() async {
    if (_selectedTaskIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择要删除的任务')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认批量删除'),
        content: Text('确定要删除选中的 ${_selectedTaskIds.length} 个任务吗？\n\n此操作不可恢复！'),
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
      await _handleBatchDelete();
    }
  }

  // 批量删除任务
  Future<void> _handleBatchDelete() async {
    final idsToDelete = _selectedTaskIds.toList();
    int successCount = 0;
    int failCount = 0;

    // 显示加载提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('正在删除 ${idsToDelete.length} 个任务...'),
          duration: const Duration(seconds: 30),
        ),
      );
    }

    await runCrudWithForceRefresh(
      action: () async {
        for (final id in idsToDelete) {
          try {
            await _scheduleRepository.deleteSchedule(id);
            successCount++;
          } catch (e) {
            failCount++;
          }
        }
      },
      forceRefresh: () => _loadTasks(forceRefresh: true),
    );

    // 清空选择并刷新
    setState(() {
      _selectedTaskIds.clear();
      _isSelectionMode = false;
    });

    // 强刷在 runCrudWithForceRefresh 内完成

    // 显示结果
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              failCount == 0
                  ? '成功删除 $successCount 个任务'
                  : '成功删除 $successCount 个，失败 $failCount 个',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
          ),
        );
    }
  }

  // 更新任务状态
  Future<void> _handleStatusChange(Schedule task, String newStatus) async {
    try {
      final updatedTask = task.copyWith(status: newStatus);
      await runCrudWithForceRefresh(
        action: () => _scheduleRepository.updateSchedule(updatedTask),
        forceRefresh: () => _loadTasks(forceRefresh: true),
      );

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
    final List<Schedule> currentFilteredTasks = _allTasks.where((task) {
      if (_selectedScheduleType == 'all') {
        return true; // "全部日程"，不过滤
      }
      // 假设你的 Schedule-Model 中有一个 'type' 字段
      // (e.g., task.type == 'daily' or 'task' or 'meeting')
      return task.type == _selectedScheduleType;
    }).toList();

    final selectedCount = _isSelectionMode ? _selectedTaskIds.length : 0;

    return Scaffold(
      appBar: AppBar(
        // title: const Text('任务'),
        title: _isSelectionMode
            ? Text('已选择 $selectedCount 项')
            : TaskScheduleTypeDropdown(
                selectedScheduleType: _selectedScheduleType,
                scheduleTypeOptions: _scheduleTypeOptions,
                onChanged: (newValue) {
                  setState(() {
                    _selectedScheduleType = newValue;
                  });
                },
              ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
                tooltip: '取消选择',
              )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () {
                final currentStatus = _tabs[_tabController.index].status;
                final currentTasks = currentStatus == 'active'
                    ? _getActiveTasks(currentFilteredTasks)
                    : _getTasksByStatus(currentStatus, currentFilteredTasks);
                _toggleSelectAll(currentTasks);
              },
              tooltip: '全选',
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: _toggleSelectionMode,
              tooltip: '批量选择',
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showCreateDialog,
              tooltip: '创建任务',
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: const Color(0xFF1F2329),
          unselectedLabelColor: const Color(0xFF9AA0A6),
          indicatorColor: const Color(0xFF1F2329),
          tabs: _tabs.map((tab) {
            // final tasks = _getTasksByStatus(tab.status);
            final tasks = tab.status == 'active'
                ? _getActiveTasks(currentFilteredTasks)
                : _getTasksByStatus(tab.status, currentFilteredTasks);
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
      body: Column(
        children: [
          // 离线状态横幅
          OfflineBanner(showPendingCount: true, pendingCount: _pendingCount),
          // 主体内容
          Expanded(
            child: _errorMessage != null
                ? TaskErrorView(
                    message: _errorMessage ?? '加载失败',
                    onRetry: _loadTasks,
                  )
                : Stack(
                    children: [
                      TabBarView(
                        controller: _tabController,
                        children: _tabs
                            .map(
                              (tab) => tab.status == 'active'
                                  ? _buildCombinedTaskList(currentFilteredTasks)
                                  : _buildTaskList(
                                      tab.status,
                                      currentFilteredTasks,
                                    ),
                            )
                            .toList(),
                      ),
                      // 批量操作底部栏
                      if (_isSelectionMode && _selectedTaskIds.isNotEmpty)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: TaskBatchActionBar(
                            selectedCount: _selectedTaskIds.length,
                            onDelete: _showBatchDeleteConfirmDialog,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      // 浮动同步按钮
      floatingActionButton: FloatingSyncButton(
        isSyncing: _isSyncing,
        pendingCount: _pendingCount,
        onTap: _triggerManualSync,
      ),
    );
  }

  // 构建任务列表
  Widget _buildTaskList(String status, List<Schedule> tasksToFilter) {
    final tasks = _getTasksByStatus(status, tasksToFilter);

    final emptyInfo = _getEmptyInfo(status);

    return TaskListView(
      tasks: tasks,
      isSelectionMode: _isSelectionMode,
      selectedTaskIds: _selectedTaskIds,
      expandedTaskIds: _expandedTaskIds,
      use24HourFormat: _use24HourFormat,
      emptyIcon: emptyInfo.icon,
      emptyMessage: emptyInfo.message,
      showCreateButton: status == 'pending' || status == 'upcoming',
      onCreate: _showCreateDialog,
      onToggleTaskSelection: _toggleTaskSelection,
      onToggleTaskExpanded: _toggleTaskExpanded,
      onStatusChanged: _handleStatusChange,
      onEdit: _showEditDialog,
      onDelete: _showDeleteConfirmDialog,
      onRefresh: _handlePullToRefresh,
      formatDateTime: _formatDateTime,
      buildStatusBadge: _buildStatusBadge,
    );
  }

  Widget _buildCombinedTaskList(List<Schedule> tasksToFilter) {
    final upcoming = _getUpcomingTasks(tasksToFilter)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final pending = _getPendingTasks(tasksToFilter)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final inProgress = _getInProgressTasks(tasksToFilter)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final allTasks = [...upcoming, ...pending, ...inProgress];

    if (allTasks.isEmpty) {
      final emptyInfo = _getEmptyInfo('active');
      return TaskListView(
        tasks: const [],
        isSelectionMode: _isSelectionMode,
        selectedTaskIds: _selectedTaskIds,
        expandedTaskIds: _expandedTaskIds,
        use24HourFormat: _use24HourFormat,
        emptyIcon: emptyInfo.icon,
        emptyMessage: emptyInfo.message,
        showCreateButton: true,
        onCreate: _showCreateDialog,
        onToggleTaskSelection: _toggleTaskSelection,
        onToggleTaskExpanded: _toggleTaskExpanded,
        onStatusChanged: _handleStatusChange,
        onEdit: _showEditDialog,
        onDelete: _showDeleteConfirmDialog,
        onRefresh: _handlePullToRefresh,
        formatDateTime: _formatDateTime,
        buildStatusBadge: _buildStatusBadge,
      );
    }

    return RefreshIndicator(
      onRefresh: _handlePullToRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          _isSelectionMode && _selectedTaskIds.isNotEmpty ? 80 : 12,
        ),
        children: [
          _buildActiveSection(
            key: 'upcoming',
            title: '即将开始',
            icon: Icons.upcoming,
            color: Colors.orange,
            tasks: upcoming,
          ),
          const SizedBox(height: 8),
          _buildActiveSection(
            key: 'pending',
            title: '待进行',
            icon: Icons.pending_actions,
            color: Colors.grey,
            tasks: pending,
          ),
          const SizedBox(height: 8),
          _buildActiveSection(
            key: 'in_progress',
            title: '进行中',
            icon: Icons.play_circle,
            color: Colors.blue,
            tasks: inProgress,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSection({
    required String key,
    required String title,
    required IconData icon,
    required Color color,
    required List<Schedule> tasks,
  }) {
    final isExpanded = _activeSectionExpanded[key] ?? true;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          key: PageStorageKey<String>('active_${key}_$_expandResetTick'),
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _activeSectionExpanded[key] = expanded;
            });
          },
          tilePadding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          collapsedBackgroundColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          title: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                '${tasks.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.75),
                ),
              ),
            ],
          ),
          children: tasks.isEmpty
              ? const [SizedBox.shrink()]
              : [
                  Column(
                    children: tasks
                        .map(
                          (task) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildTaskItem(task),
                          ),
                        )
                        .toList(),
                  ),
                ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(Schedule task) {
    final isExpanded = _expandedTaskIds.contains(task.id);
    final isSelected = _isSelectionMode && _selectedTaskIds.contains(task.id);

    if (_isSelectionMode) {
      return InkWell(
        onTap: () => _toggleTaskSelection(task.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleTaskSelection(task.id),
            ),
            title: Text(
              task.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(task.startTime),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (task.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            trailing: _buildStatusBadge(task.status),
          ),
        ),
      );
    }

    return ScheduleCard(
      schedule: task,
      isExpanded: isExpanded,
      onTap: () => _toggleTaskExpanded(task.id),
      onStatusChanged: (newStatus) => _handleStatusChange(task, newStatus),
      onEdit: () => _showEditDialog(task),
      onDelete: () => _showDeleteConfirmDialog(task),
      use24HourFormat: _use24HourFormat,
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
      case 'active':
        return EmptyInfo(icon: Icons.view_agenda, message: '暂无待办或进行中的任务');
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

  // 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 构建状态徽章
  Widget _buildStatusBadge(String status) {
    String label;
    Color color;

    switch (status) {
      case 'pending':
        label = '待办';
        color = Colors.grey;
        break;
      case 'in_progress':
        label = '进行中';
        color = Colors.blue;
        break;
      case 'completed':
        label = '已完成';
        color = Colors.green;
        break;
      case 'cancelled':
        label = '已取消';
        color = Colors.red;
        break;
      default:
        label = status;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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
