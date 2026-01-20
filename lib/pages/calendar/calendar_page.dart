import 'package:ce_frontend/services/core/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/schedule/schedule.dart';
import '../../models/daily/daily_task.dart';

import '../../repositories/schedule_repository.dart';
import '../../services/daily/daily_task_service.dart';
import '../../services/schedule/schedule_service.dart';
import '../../services/sync/sync_queue_service.dart';
import '../../widgets/schedule/create_schedule_bottom_sheet.dart';
import '../../widgets/common/offline_banner.dart';
import '../../widgets/common/sync_indicator.dart';
import '../../widgets/calendar/calendar_header_sliver.dart';
import '../../widgets/calendar/calendar_schedule_list.dart';
import 'package:get_it/get_it.dart';
// import 'package:flutter_animate/flutter_animate.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  // 用于追踪数据更新，确保 TableCalendar 在数据变化时重建
  int _scheduleUpdateCount = 0;

  // 判断当前选中日期是否为今天
  bool _isTodaySelected() {
    final now = DateTime.now();
    if (_selectedDay == null) return false;
    return _isSameDay(_selectedDay!, now);
  }

  // 判断两个日期是否为同一天（忽略时分秒）
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  final _scheduleRepository = ScheduleRepository();
  final _dailyTaskService = DailyTaskService();
  // 用于特殊操作（如删除重复模板）的 Service 直接引用
  final _scheduleService = ScheduleService();
  final _syncQueue = GetIt.instance<SyncQueueService>();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _use24HourFormat = true;

  Map<DateTime, List<Schedule>> _scheduleMap = {};
  final Set<String> _expandedScheduleIds = {};
  // 活跃的日常任务列表（不按天区分，按选中日期展示）
  List<DailyTask> _dailyTasks = [];
  // 是否在日历中显示日常任务
  bool _showDailyTasksInCalendar = true;

  bool _isSyncing = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadSchedules();
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
        // 同步完成后刷新数据
        _loadSchedules();
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

  /// 下拉刷新（强制从 API 获取最新数据）
  Future<void> _handlePullToRefresh() async {
    try {
      final year = _focusedDay.year;
      final month = _focusedDay.month;

      // 使用 refreshSchedules 强制刷新，忽略缓存
      final monthSchedules = await _scheduleRepository.refreshSchedules(
        year: year,
        month: month,
      );

      final schedules = monthSchedules.where((s) => s.type != 'daily').toList();

      if (_showDailyTasksInCalendar) {
        try {
          final tasks = await _dailyTaskService.getDailyTasks(status: 'active');
          setState(() {
            _dailyTasks = tasks;
          });
        } catch (e) {
          debugPrint('加载日常任务失败: $e');
        }
      }

      // 将日程转换为 Map
      final scheduleMap = <DateTime, List<Schedule>>{};
      for (final schedule in schedules) {
        final date = DateTime(
          schedule.startTime.year,
          schedule.startTime.month,
          schedule.startTime.day,
        );
        scheduleMap.putIfAbsent(date, () => []).add(schedule);
      }

      if (mounted) {
        setState(() {
          _scheduleMap = scheduleMap;
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

  Future<void> _loadConfig() async {
    try {
      final profile = await AuthService().getUser();
      if (profile == null) return;
      if (!mounted) return;
      setState(() {
        _use24HourFormat = profile.config.use24HourFormat;
        _showDailyTasksInCalendar =
            profile.config.dailyScheduleDisplayInCalendar == true;
        // 如果关闭了显示，清空日常任务列表
        if (!_showDailyTasksInCalendar) {
          _dailyTasks = [];
        }
      });
    } catch (_) {
      // 忽略配置加载失败
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 避免重复请求：初始化已加载，这里仅保持配置同步
    _loadConfig();
  }

  // 公开的刷新方法，供外部调用
  void refreshData() {
    _loadSchedules();
    _loadConfig();
  }

  // 公开的方法：跳转到指定日期
  void jumpToDate(DateTime date) {
    setState(() {
      _focusedDay = date;
      _selectedDay = date;
    });
  }

  // 加载日程数据
  Future<void> _loadSchedules() async {
    try {
      List<Schedule> schedules = [];

      // 使用 Repository 按月加载（启用缓存）
      final year = _focusedDay.year;
      final month = _focusedDay.month;
      final monthSchedules = await _scheduleRepository.getSchedules(
        year: year,
        month: month,
      );

      schedules = monthSchedules.where((s) => s.type != 'daily').toList();

      List<DailyTask> loadedDailyTasks = [];
      // 如果启用在日历显示日常任务，加载日常数据
      if (_showDailyTasksInCalendar) {
        try {
          loadedDailyTasks = await _dailyTaskService.getDailyTasks(
            status: 'active',
          );
        } catch (e) {
          debugPrint('加载日常任务失败: $e');
        }
      }

      if (mounted) {
        setState(() {
          _scheduleMap = _buildScheduleMap(schedules);
          _dailyTasks = loadedDailyTasks;
          _scheduleUpdateCount++; // 增加数据版本计数，触发 delegate 重建
        });
      }

      // 解决首屏命中缓存但不渲染的问题：
      // 主动触发一次与“手动切换日期”相同的刷新路径，确保列表和标记立即更新。
      if (_selectedDay != null) {
        _onDaySelected(_selectedDay!, _focusedDay);
      }
    } catch (e) {
      // 加载失败不设置状态，保持现有数据
    }
  }

  // 构建日期->日程映射
  Map<DateTime, List<Schedule>> _buildScheduleMap(List<Schedule> schedules) {
    final map = <DateTime, List<Schedule>>{};

    for (var schedule in schedules) {
      // 标准化日期（去掉时分秒）
      final date = DateTime(
        schedule.startTime.year,
        schedule.startTime.month,
        schedule.startTime.day,
      );

      if (map[date] == null) {
        map[date] = [];
      }
      map[date]!.add(schedule);
    }

    // 按开始时间排序
    for (var schedules in map.values) {
      schedules.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    return map;
  }

  // 获取指定日期的日程
  List<Schedule> _getSchedulesForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _scheduleMap[normalizedDay] ?? [];
  }

  // 判断某天是否有未完成的任务（包括日程和日常任务）
  bool _hasPendingTasks(DateTime day) {
    final schedules = _getSchedulesForDay(day);

    // 检查是否有未完成的日程
    final hasPendingSchedule = schedules.any(
      (s) => s.status != 'completed' && s.status != 'cancelled',
    );

    // 如果是今天且启用了日常任务显示，检查日常任务
    if (_showDailyTasksInCalendar && _isSameDay(day, DateTime.now())) {
      // 检查是否有未打卡的活跃日常任务（status=active 且 todayCompleted!=true）
      final hasPendingDailyTask = _dailyTasks.any(
        (task) => task.status == 'active' && task.todayCompleted != true,
      );
      return hasPendingSchedule || hasPendingDailyTask;
    }

    return hasPendingSchedule;
  }

  // 判断某天的所有任务是否都已完成
  bool _isAllCompleted(DateTime day) {
    final schedules = _getSchedulesForDay(day);

    // 如果没有任何日程
    if (schedules.isEmpty) {
      // 如果是今天且启用了日常任务显示，只要日常任务都打卡了就显示绿条
      if (_showDailyTasksInCalendar && _isSameDay(day, DateTime.now())) {
        return _dailyTasks.isNotEmpty &&
            _dailyTasks.every(
              (task) => task.status != 'active' || task.todayCompleted == true,
            );
      }
      return false;
    }

    // 所有日程都已完成或取消
    final allSchedulesCompleted = schedules.every(
      (s) => s.status == 'completed' || s.status == 'cancelled',
    );

    // 如果是今天且启用了日常任务，还需要检查日常任务
    if (_showDailyTasksInCalendar && _isSameDay(day, DateTime.now())) {
      // 如果有日常任务，它们也必须都打卡了（或者是暂停状态）
      if (_dailyTasks.isNotEmpty) {
        final allDailyTasksCompleted = _dailyTasks.every(
          (task) => task.status != 'active' || task.todayCompleted == true,
        );
        return allSchedulesCompleted && allDailyTasksCompleted;
      }
    }

    return allSchedulesCompleted;
  }

  // 日期选择回调
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _expandedScheduleIds.clear(); // 切换日期时收起所有卡片
      });
    }
  }

  // 跳转到今天
  void _jumpToToday() {
    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
      _expandedScheduleIds.clear();
    });
  }

  // 切换日程卡片展开/折叠
  void _toggleScheduleExpanded(String scheduleId) {
    setState(() {
      if (_expandedScheduleIds.contains(scheduleId)) {
        _expandedScheduleIds.remove(scheduleId);
      } else {
        _expandedScheduleIds.add(scheduleId);
      }
    });
  }

  // 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog(Schedule schedule) async {
    final isRecurringInstance = schedule.parentId != null;

    if (isRecurringInstance) {
      String selectedOption = 'single';

      final result = await showDialog<Map<String, String>?>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('删除重复日程'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('「${schedule.title}」是重复系列中的一条。请选择删除方式：'),
                    const SizedBox(height: 16),
                    RadioListTile<String>(
                      title: const Text('仅删除该事件'),
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
                      title: const Text('删除模板 + 所有事件（含历史）'),
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
        _handleDelete(schedule.id);
      } else {
        await _handleDeleteSeries(schedule.parentId!, action);
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除「${schedule.title}」吗？'),
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
        _handleDelete(schedule.id);
      }
    }
  }

  // 显示创建日程对话框
  void _showCreateDialog() {
    showCreateScheduleBottomSheet(
      context,
      initialDate: _selectedDay ?? DateTime.now(),
      onSave: _handleCreate,
      use24HourFormat: _use24HourFormat,
    );
  }

  // 显示编辑日程对话框
  void _showEditDialog(Schedule schedule) {
    showCreateScheduleBottomSheet(
      context,
      existingSchedule: schedule,
      onSave: (updatedSchedule) => _handleUpdate(schedule.id, updatedSchedule),
      use24HourFormat: _use24HourFormat,
    );
  }

  // 显示日常任务详情
  void _showDailyTaskDetails(DailyTask task) {
    // 暂时显示简单提示，未来可以实现完整的详情页
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${task.title}\n状态: ${task.status == 'active' ? '活跃' : '暂停'}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 创建日程
  Future<void> _handleCreate(Schedule schedule) async {
    try {
      await _scheduleRepository.createSchedule(schedule);

      // 刷新列表
      await _loadSchedules();

      if (mounted) {
        Future.microtask(() {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('日程已创建'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 更新日程
  Future<void> _handleUpdate(String id, Schedule updatedSchedule) async {
    try {
      await _scheduleRepository.updateSchedule(updatedSchedule);

      // 刷新列表
      await _loadSchedules();

      if (mounted) {
        Future.microtask(() {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('日程已更新'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 删除日程
  Future<void> _handleDelete(String id, {bool showSnackBar = true}) async {
    try {
      await _scheduleRepository.deleteSchedule(id);

      // 刷新列表
      await _loadSchedules();

      if (mounted && showSnackBar) {
        Future.microtask(() {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('日程已删除'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 删除重复日程模板
  Future<void> _handleDeleteSeries(
    String parentId,
    String deleteInstances,
  ) async {
    try {
      await _scheduleService.deleteRecurrenceTemplate(
        parentId,
        deleteInstances: deleteInstances,
      );

      // 刷新列表
      await _loadSchedules();

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
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 更新日程状态
  Future<void> _handleStatusChange(Schedule schedule, String newStatus) async {
    try {
      // 创建更新后的日程对象
      final updatedSchedule = schedule.copyWith(status: newStatus);

      await _scheduleRepository.updateSchedule(updatedSchedule);

      // 刷新列表
      await _loadSchedules();

      if (mounted) {
        final statusText = newStatus == 'completed'
            ? '已完成'
            : newStatus == 'cancelled'
            ? '已取消'
            : '进行中';

        Future.microtask(() {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('已标记为$statusText'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
        title: const Text('日历'),
        actions: [
          // 同步状态指示器
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SyncIndicator(isSyncing: true, size: 20),
            ),
          TextButton(
            onPressed: _jumpToToday,
            child: const Text(
              '今天',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(icon: const Icon(Icons.add), onPressed: _showCreateDialog),
        ],
      ),
      body: Column(
        children: [
          // 离线状态横幅
          OfflineBanner(showPendingCount: true, pendingCount: _pendingCount),
          // 主体内容
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handlePullToRefresh,
              child: CustomScrollView(
                slivers: [
                  // 1. 核心：可跟随手指收缩的日历头部
                  CalendarHeaderSliver(
                    focusedDay: _focusedDay,
                    selectedDay: _selectedDay,
                    scheduleUpdateCount: _scheduleUpdateCount,
                    onDaySelected: _onDaySelected,
                    onPageChanged: (focusedDay) {
                      final isMonthChanged =
                          focusedDay.year != _focusedDay.year ||
                          focusedDay.month != _focusedDay.month;
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                      if (isMonthChanged) {
                        _loadSchedules();
                      }
                    },
                    eventLoader: _getSchedulesForDay,
                    hasPendingTasks: _hasPendingTasks,
                    isAllCompleted: _isAllCompleted,
                  ),

                  // 2. 日程列表
                  CalendarScheduleList(
                    selectedDay: _selectedDay,
                    schedules: _selectedDay == null
                        ? const []
                        : _getSchedulesForDay(_selectedDay!),
                    dailyTasks: _dailyTasks,
                    showDailyTasksInCalendar: _showDailyTasksInCalendar,
                    isTodaySelected: _isTodaySelected(),
                    expandedScheduleIds: _expandedScheduleIds,
                    use24HourFormat: _use24HourFormat,
                    onCreateSchedule: _showCreateDialog,
                    onDailyTaskUpdated: _loadSchedules,
                    onDailyTaskDetails: _showDailyTaskDetails,
                    onToggleScheduleExpanded: _toggleScheduleExpanded,
                    onStatusChanged: _handleStatusChange,
                    onEditSchedule: _showEditDialog,
                    onDeleteSchedule: _showDeleteConfirmDialog,
                  ),

                  // 底部安全距离
                  const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
                ],
              ),
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

  // 构建日历组件
  // Widget _buildCalendar() {
  //   // 判断是否处于展开（月视图）状态
  //   final isMonth = _calendarFormat == CalendarFormat.month;

  //   return Column(
  //     children: [
  //       // ------------------------------------------------------
  //       // 1. 自定义头部 + 星期栏 (使用 AnimatedSize 包裹)
  //       // ------------------------------------------------------
  //       AnimatedSize(
  //         // 这里的时长要和 TableCalendar 保持一致，确保同步
  //         duration: const Duration(milliseconds: 300),
  //         curve: Curves.easeInOut,
  //         alignment: Alignment.topCenter, // 收缩时向上对齐
  //         child: isMonth
  //             ? Column(
  //                 children: [
  //                   // 1.1 年月标题 (e.g. 2025年11月)
  //                   Padding(
  //                     padding: const EdgeInsets.symmetric(vertical: 8.0),
  //                     child: Text(
  //                       DateFormat.yMMM('zh_CN').format(_focusedDay),
  //                       style: const TextStyle(
  //                         fontSize: 18.0,
  //                         fontWeight: FontWeight.bold,
  //                       ),
  //                     ),
  //                   ),
  //                   // 1.2 星期栏 (周一 ... 周日)
  //                   Padding(
  //                     padding: const EdgeInsets.only(bottom: 8.0),
  //                     child: Row(
  //                       mainAxisAlignment: MainAxisAlignment.spaceAround,
  //                       children: ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
  //                           .map(
  //                             (day) => Text(
  //                               day,
  //                               style: TextStyle(
  //                                 color: Colors.grey[600],
  //                                 fontSize: 13,
  //                               ),
  //                             ),
  //                           )
  //                           .toList(),
  //                     ),
  //                   ),
  //                 ],
  //               )
  //             : const SizedBox(width: double.infinity), // 收起时，子组件变为空，高度自动动画缩为0
  //       ),

  //       // ------------------------------------------------------
  //       // 2. 日历本体 (只负责显示日期网格)
  //       // ------------------------------------------------------
  //       TableCalendar<Schedule>(
  //         locale: 'zh_CN',
  //         startingDayOfWeek: StartingDayOfWeek.monday,
  //         firstDay: DateTime.utc(2020, 1, 1),
  //         lastDay: DateTime.utc(2030, 12, 31),
  //         focusedDay: _focusedDay,
  //         selectedDayPredicate: (day) => isSameDay(_selectedDay, day),

  //         // 动画配置：务必和上面的 AnimatedSize 保持一致
  //         formatAnimationDuration: const Duration(milliseconds: 300),
  //         formatAnimationCurve: Curves.easeInOut,

  //         // 核心：彻底隐藏自带的 Header 和 DaysOfWeek
  //         headerVisible: false,
  //         daysOfWeekVisible: false,

  //         availableGestures: AvailableGestures.all,

  //         eventLoader: _getSchedulesForDay,
  //         onDaySelected: _onDaySelected,
  //         // onFormatChanged: (format) {
  //         //   if (_calendarFormat != format) {
  //         //     setState(() {
  //         //       _calendarFormat = format;
  //         //     });
  //         //   }
  //         // },
  //         onPageChanged: (focusedDay) {
  //           setState(() {
  //             _focusedDay = focusedDay;
  //           });
  //         },

  //         // 样式保持原样
  //         calendarStyle: CalendarStyle(
  //           todayDecoration: BoxDecoration(
  //             color: Colors.blue[100],
  //             shape: BoxShape.circle,
  //           ),
  //           todayTextStyle: const TextStyle(
  //             color: Colors.black,
  //             fontWeight: FontWeight.bold,
  //           ),
  //           selectedDecoration: const BoxDecoration(
  //             color: Colors.blue,
  //             shape: BoxShape.circle,
  //           ),
  //           selectedTextStyle: const TextStyle(
  //             color: Colors.white,
  //             fontWeight: FontWeight.bold,
  //           ),
  //           markersMaxCount: 1,
  //           markerDecoration: const BoxDecoration(
  //             color: Colors.red,
  //             shape: BoxShape.circle,
  //           ),
  //         ),

  //         // Builder 保持原样
  //         calendarBuilders: CalendarBuilders(
  //           defaultBuilder: (context, day, focusedDay) =>
  //               _buildDateCell(day, false, false),
  //           todayBuilder: (context, day, focusedDay) =>
  //               _buildDateCell(day, true, false),
  //           selectedBuilder: (context, day, focusedDay) =>
  //               _buildDateCell(day, false, true),
  //           markerBuilder: (context, date, events) {
  //             if (events.isNotEmpty &&
  //                 events.any((e) => e.shouldShowMarker())) {
  //               return Positioned(
  //                 bottom: 1,
  //                 child: Container(
  //                   width: 6,
  //                   height: 6,
  //                   decoration: const BoxDecoration(
  //                     shape: BoxShape.circle,
  //                     color: Colors.red,
  //                   ),
  //                 ),
  //               );
  //             }
  //             return null;
  //           },
  //         ),
  //       ),
  //     ],
  //   );
  // }

  // 构建日期单元格（带轻微点击动画）
  // Widget _buildDateCell(DateTime day, bool isToday, bool isSelected) {
  //   Color? backgroundColor;
  //   Color textColor = Colors.black87;
  //   FontWeight fontWeight = FontWeight.normal;

  //   if (isSelected) {
  //     backgroundColor = Colors.blue;
  //     textColor = Colors.white;
  //     fontWeight = FontWeight.bold;
  //   } else if (isToday) {
  //     backgroundColor = Colors.blue[100];
  //     fontWeight = FontWeight.bold;
  //   }

  //   return AnimatedContainer(
  //     duration: const Duration(milliseconds: 200),
  //     margin: const EdgeInsets.all(4),
  //     decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
  //     child: Center(
  //       child: Text(
  //         '${day.day}',
  //         style: TextStyle(color: textColor, fontWeight: fontWeight),
  //       ),
  //     ),
  //   );
  // }

  // 错误视图
}
