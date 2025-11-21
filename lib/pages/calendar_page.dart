import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/schedule.dart';
import '../services/schedule_service.dart';
import '../widgets/schedule_card.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日历'),
        actions: [
          // 今天按钮
          TextButton(
            onPressed: _jumpToToday,
            child: const Text('今天', style: TextStyle(color: Colors.white)),
          ),
          // 新建按钮（预留）
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: 实现创建日程功能
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('创建日程功能开发中...')));
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : Column(
              children: [
                // 日历视图
                _buildCalendar(),

                const Divider(height: 1),

                // 日程列表
                Expanded(child: _buildScheduleList()),
              ],
            ),
    );
  }

  // 构建日历组件
  Widget _buildCalendar() {
    return TableCalendar<Schedule>(
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
        todayDecoration: BoxDecoration(
          color: Colors.blue[300],
          shape: BoxShape.circle,
        ),
        selectedDecoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        markerDecoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        markersMaxCount: 1,
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      // 自定义标记（红点）
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          if (events.isNotEmpty) {
            // 只显示未完成的日程
            final unfinishedEvents = events
                .where((e) => e.shouldShowMarker())
                .toList();
            if (unfinishedEvents.isNotEmpty) {
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

  // 构建日程列表
  Widget _buildScheduleList() {
    if (_selectedDay == null) {
      return const Center(child: Text('请选择日期'));
    }

    final schedules = _getSchedulesForDay(_selectedDay!);

    if (schedules.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
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
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: schedules.length,
            itemBuilder: (context, index) {
              final schedule = schedules[index];
              return ScheduleCard(
                schedule: schedule,
                isExpanded: _expandedScheduleIds.contains(schedule.id),
                onTap: () => _toggleScheduleExpanded(schedule.id),
              );
            },
          ),
        ),
      ],
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
            onPressed: () {
              // TODO: 实现创建日程功能
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('创建日程功能开发中...')));
            },
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
