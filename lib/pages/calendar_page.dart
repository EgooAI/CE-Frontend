import 'package:ce_frontend/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/schedule.dart';
import '../services/schedule_service.dart';
import '../widgets/schedule_card.dart';
import '../widgets/create_schedule_bottom_sheet.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
// import 'package:flutter_animate/flutter_animate.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _scheduleService = ScheduleService();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<Schedule>> _scheduleMap = {};
  final Set<String> _expandedScheduleIds = {};

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadSchedules();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 每次页面显示时重新加载日程
    _loadSchedules();
  }

  // 公开的刷新方法，供外部调用
  void refreshData() {
    _loadSchedules();
  }

  // 加载日程数据
  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<Schedule> schedules = [];
      final initialSchedules = await _scheduleService.getSchedules();
      final currentUser = await AuthService().getProfile();
      if (currentUser != null &&
          currentUser.config.dailyScheduleDisplayInCalendar == false) {
        // 检查配置：如果“不显示日常”，则把 isDaily 为 true 的过滤掉
        schedules = initialSchedules.where((s) {
          // TODO: 这里需要你根据实际 Schedule 结构修改判断条件
          // 例如：return s.type != 'daily';
          // 或者：return !s.isRoutine;
          return s.isDaily == false;
        }).toList();
      } else {
        schedules = initialSchedules;
      }
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

  // 删除重复日程模板
  Future<void> _handleDeleteSeries(String templateId, String strategy) async {
    try {
      await _scheduleService.deleteRecurrenceTemplate(
        templateId,
        strategy: strategy,
      );

      // 刷新列表
      await _loadSchedules();

      if (mounted) {
        final strategyText =
            {'future': '模板+待办实例', 'all': '模板+全部实例'}[strategy] ?? '仅模板';

        Future.microtask(() {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('已删除：$strategyText'),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // 1. 核心：可跟随手指收缩的日历头部
                SliverPersistentHeader(
                  pinned: true, // 关键：收缩后固定在顶部
                  delegate: _CalendarHeaderDelegate(
                    focusedDay: _focusedDay,
                    selectedDay: _selectedDay,
                    onDaySelected: _onDaySelected,
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    },
                    eventLoader: _getSchedulesForDay,
                  ),
                ),

                // 2. 日程列表
                _buildScheduleList(),

                // 底部安全距离
                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
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

  // 构建日程列表
  Widget _buildScheduleList() {
    if (_selectedDay == null) {
      return SliverFillRemaining(child: const Center(child: Text('请选择日期')));
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

class _CalendarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Function(DateTime, DateTime) onDaySelected;
  final Function(DateTime) onPageChanged;
  final List<Schedule> Function(DateTime) eventLoader;

  _CalendarHeaderDelegate({
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.eventLoader,
  });

  // 常量配置
  static const double _rowHeight = 52.0;
  static const double _titleHeight = 40.0;
  static const double _dayOfWeekHeight = 30.0;

  // !!! 修改点 1: 统一改为 6 行，以兼容所有月份 !!!
  static const int _showRowsCount = 6;

  static const double _headerTotalHeight = _titleHeight + _dayOfWeekHeight;

  // 最大高度 = 头部 + 6行日期
  static const double _maxExtent =
      _headerTotalHeight + (_rowHeight * _showRowsCount) + 10;

  // 最小高度
  static const double _minExtent = _rowHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // 1. 计算需要上移的距离
    final int selectedRowIndex = _calculateSelectedRowIndex();
    final double targetSlideUpOffset =
        _headerTotalHeight + (selectedRowIndex * _rowHeight);

    // 2. 动画进度计算
    final double shrinkProgress = shrinkOffset / (maxExtent - minExtent);
    final double clampedProgress = shrinkProgress.clamp(0.0, 1.0);
    final double currentTranslateY = targetSlideUpOffset * clampedProgress;

    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    // -----------------------------------------------------------
    // 新增：计算阴影/边框的不透明度
    // -----------------------------------------------------------
    // 只有当收缩进度超过 0% 时才开始显示，完全收缩时达到最大不透明度
    // 这里的 0.1 是阴影的最大浓度，你可以根据需要调整 (0.0 ~ 1.0)
    final double shadowOpacity = (clampedProgress * 0.1).clamp(0.0, 1.0);

    // 如果想要边框而不是阴影，用这个透明度
    // final double borderOpacity = (clampedProgress * 0.15).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,

        // 方案 A: 底部阴影 (更有立体感)
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(
              (shadowOpacity * 255).toInt(),
            ), // 动态透明度
            offset: const Offset(0, 2), // 向下偏移 2px
            blurRadius: 4, // 模糊半径
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRect(
        child: OverflowBox(
          minHeight: maxExtent,
          maxHeight: maxExtent,
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: Offset(0, -currentTranslateY),
            child: Column(
              children: [
                // 1. 标题
                SizedBox(
                  height: _titleHeight,
                  child: Center(
                    child: Text(
                      DateFormat.yMMM('zh_CN').format(focusedDay),
                      style: const TextStyle(
                        fontSize: 17.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // 2. 星期
                SizedBox(
                  height: _dayOfWeekHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
                        .map(
                          (day) => Text(
                            day,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),

                // 3. 日历主体
                SizedBox(
                  height: _rowHeight * _showRowsCount, // 6行高度
                  child: TableCalendar<Schedule>(
                    locale: 'zh_CN',
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: focusedDay,
                    selectedDayPredicate: (day) => isSameDay(selectedDay, day),

                    calendarFormat: CalendarFormat.month,
                    shouldFillViewport: true,

                    // !!! 修改点 2: 强制所有月份都渲染成 6 行 !!!
                    // 这样5行月份的下面会补一行灰色的下月日期，保证高度不跳变
                    sixWeekMonthsEnforced: true,

                    headerVisible: false,
                    daysOfWeekVisible: false,
                    rowHeight: _rowHeight,

                    eventLoader: eventLoader,
                    onDaySelected: onDaySelected,
                    onPageChanged: onPageChanged,

                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 1,
                      markerDecoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (events.isNotEmpty) {
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
                        return null;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 计算选中日期在当前月份是第几行 (0-5)
  int _calculateSelectedRowIndex() {
    if (selectedDay == null) return 0;

    // 这里的逻辑适用于 Monday Start
    DateTime firstDayOfMonth = DateTime(focusedDay.year, focusedDay.month, 1);
    int daysDifference = firstDayOfMonth.weekday - 1;
    DateTime firstVisibleDay = firstDayOfMonth.subtract(
      Duration(days: daysDifference),
    );

    int index = selectedDay!.difference(firstVisibleDay).inDays;
    if (index < 0) return 0;

    int rowIndex = index ~/ 7;
    // 修改点 3: 允许最大索引为 5 (即第6行)
    return rowIndex.clamp(0, _showRowsCount - 1);
  }

  @override
  double get maxExtent => _maxExtent;

  @override
  double get minExtent => _minExtent;

  @override
  bool shouldRebuild(covariant _CalendarHeaderDelegate oldDelegate) {
    return oldDelegate.focusedDay != focusedDay ||
        oldDelegate.selectedDay != selectedDay;
  }
}
