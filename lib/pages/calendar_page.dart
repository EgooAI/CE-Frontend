import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/schedule.dart';
import '../services/schedule_service.dart';
import '../widgets/schedule_card.dart';
import '../widgets/create_schedule_bottom_sheet.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _scheduleService = ScheduleService();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  Map<DateTime, List<Schedule>> _scheduleMap = {};
  Set<String> _expandedScheduleIds = {};

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadSchedules();
  }

  // 加载日程数据
  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final schedules = await _scheduleService.getSchedules();
      setState(() {
        _scheduleMap = _buildScheduleMap(schedules);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
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

  // 显示创建日程对话框
  void _showCreateDialog() {
    showCreateScheduleBottomSheet(
      context,
      initialDate: _selectedDay ?? DateTime.now(),
      onSave: _handleCreate,
    );
  }

  // 显示编辑日程对话框
  void _showEditDialog(Schedule schedule) {
    showCreateScheduleBottomSheet(
      context,
      existingSchedule: schedule,
      onSave: (updatedSchedule) => _handleUpdate(schedule.id, updatedSchedule),
    );
  }

  // 创建日程
  Future<void> _handleCreate(Schedule schedule) async {
    try {
      await _scheduleService.createSchedule(schedule.toJson());

      // 刷新列表
      await _loadSchedules();

      if (mounted) {
        Future.microtask(() {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('日程已创建'),
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
      await _scheduleService.updateSchedule(id, updatedSchedule.toJson());

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
      await _scheduleService.deleteSchedule(id);

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

  // 更新日程状态
  Future<void> _handleStatusChange(Schedule schedule, String newStatus) async {
    try {
      // 创建更新后的日程对象
      final updatedSchedule = schedule.copyWith(status: newStatus);

      await _scheduleService.updateSchedule(
        schedule.id,
        updatedSchedule.toJson(),
      );

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
          // 今天按钮（蓝色）
          TextButton(
            onPressed: _jumpToToday,
            style: TextButton.styleFrom(foregroundColor: Colors.blue[300]),
            child: const Text(
              '今天',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          // 新建按钮
          IconButton(icon: const Icon(Icons.add), onPressed: _showCreateDialog),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : CustomScrollView(
              slivers: [
                // 日历视图（可滚动）
                SliverToBoxAdapter(
                  child: Column(
                    children: [_buildCalendar(), const Divider(height: 40)],
                  ),
                ),
                // 日程列表
                _buildScheduleList(),
              ],
            ),
    );
  }

  // 构建日历组件
  Widget _buildCalendar() {
    return TableCalendar<Schedule>(
      // 本地化设置
      locale: 'zh_CN',
      // 性能优化：缓存日程加载结果
      startingDayOfWeek: StartingDayOfWeek.monday,
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: _calendarFormat,
      eventLoader: _getSchedulesForDay,
      onDaySelected: _onDaySelected,
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
      // 样式配置
      calendarStyle: CalendarStyle(
        // 今天的日期用淡蓝色
        todayDecoration: BoxDecoration(
          color: Colors.blue[100],
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
        // 选中的日期用蓝色
        selectedDecoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        // 其他日期无装饰
        defaultDecoration: const BoxDecoration(),
        defaultTextStyle: const TextStyle(color: Colors.black87),
        weekendDecoration: const BoxDecoration(),
        weekendTextStyle: TextStyle(color: Colors.red[300]),
        outsideDecoration: const BoxDecoration(),
        outsideTextStyle: const TextStyle(color: Colors.grey),
        disabledDecoration: const BoxDecoration(),
        disabledTextStyle: const TextStyle(color: Colors.grey),
        holidayDecoration: const BoxDecoration(),
        markerDecoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        markersMaxCount: 1,
        canMarkersOverflow: false,
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(decoration: BoxDecoration()),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      // 自定义日期单元格构建器，完全禁用点击反馈
      calendarBuilders: CalendarBuilders(
        // 自定义默认日期单元格
        defaultBuilder: (context, day, focusedDay) {
          return _buildDateCell(day, false, false);
        },
        // 自定义今天的单元格
        todayBuilder: (context, day, focusedDay) {
          return _buildDateCell(day, true, false);
        },
        // 自定义选中的单元格
        selectedBuilder: (context, day, focusedDay) {
          return _buildDateCell(day, false, true);
        },
        // 自定义标记（红点）
        markerBuilder: (context, date, events) {
          if (events.isNotEmpty) {
            if (events.any((e) => e.shouldShowMarker())) {
              return Positioned(
                bottom: 1,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                ),
              );
            }
          }
          return null;
        },
      ),
    );
  }

  // 构建日期单元格（带轻微点击动画）
  Widget _buildDateCell(DateTime day, bool isToday, bool isSelected) {
    Color? backgroundColor;
    Color textColor = Colors.black87;
    FontWeight fontWeight = FontWeight.normal;

    if (isSelected) {
      backgroundColor = Colors.blue;
      textColor = Colors.white;
      fontWeight = FontWeight.bold;
    } else if (isToday) {
      backgroundColor = Colors.blue[100];
      fontWeight = FontWeight.bold;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(color: textColor, fontWeight: fontWeight),
        ),
      ),
    );
  }

  // 构建日程列表
  Widget _buildScheduleList() {
    if (_selectedDay == null) {
      return SliverFillRemaining(child: Center(child: Text('请选择日期')));
    }

    final schedules = _getSchedulesForDay(_selectedDay!);

    if (schedules.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // 列表标题
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey[100],
          child: Row(
            children: [
              Text(
                '${_selectedDay!.year}年${_selectedDay!.month}月${_selectedDay!.day}日 的日程',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${schedules.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 日程卡片列表
        ...schedules.map((schedule) {
          final isExpanded = _expandedScheduleIds.contains(schedule.id);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ScheduleCard(
              schedule: schedule,
              isExpanded: isExpanded,
              onTap: () => _toggleScheduleExpanded(schedule.id),
              onStatusChanged: (newStatus) =>
                  _handleStatusChange(schedule, newStatus),
              onEdit: () => _showEditDialog(schedule),
              onDelete: () => _showDeleteConfirmDialog(schedule),
            ),
          );
        }),
      ]),
    );
  }

  // 空状态视图
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            '这一天还没有日程',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.add),
            label: const Text('创建日程'),
          ),
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
            onPressed: _loadSchedules,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
