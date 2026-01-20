import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/schedule/schedule.dart';

class CalendarHeaderSliver extends StatelessWidget {
  const CalendarHeaderSliver({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.scheduleUpdateCount,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.eventLoader,
    required this.hasPendingTasks,
    required this.isAllCompleted,
  });

  final DateTime focusedDay;
  final DateTime? selectedDay;
  final int scheduleUpdateCount;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onPageChanged;
  final List<Schedule> Function(DateTime) eventLoader;
  final bool Function(DateTime) hasPendingTasks;
  final bool Function(DateTime) isAllCompleted;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _CalendarHeaderDelegate(
        focusedDay: focusedDay,
        selectedDay: selectedDay,
        scheduleUpdateCount: scheduleUpdateCount,
        onDaySelected: onDaySelected,
        onPageChanged: onPageChanged,
        eventLoader: eventLoader,
        hasPendingTasks: hasPendingTasks,
        isAllCompleted: isAllCompleted,
      ),
    );
  }
}

class _CalendarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final int scheduleUpdateCount;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onPageChanged;
  final List<Schedule> Function(DateTime) eventLoader;
  final bool Function(DateTime) hasPendingTasks;
  final bool Function(DateTime) isAllCompleted;

  _CalendarHeaderDelegate({
    required this.focusedDay,
    required this.selectedDay,
    required this.scheduleUpdateCount,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.eventLoader,
    required this.hasPendingTasks,
    required this.isAllCompleted,
  });

  // 常量配置
  static const double _rowHeight = 52.0;
  static const double _titleHeight = 40.0;
  static const double _dayOfWeekHeight = 30.0;

  // 统一改为 6 行，以兼容所有月份
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

    // 计算阴影/边框的不透明度
    final double shadowOpacity = (clampedProgress * 0.1).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((shadowOpacity * 255).toInt()),
            offset: const Offset(0, 2),
            blurRadius: 4,
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
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2099, 12, 31),
                    focusedDay: focusedDay,
                    selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                    calendarFormat: CalendarFormat.month,
                    shouldFillViewport: true,
                    // 强制所有月份都渲染成 6 行
                    sixWeekMonthsEnforced: true,
                    // availableGestures: AvailableGestures.all,
                    // pageJumpingEnabled: true,
                    // pageAnimationEnabled: true,
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
                        // 检查是否有未完成的任务
                        final hasPending = hasPendingTasks(date);
                        final allCompleted = isAllCompleted(date);

                        // 优先显示红点（有未完成任务）
                        if (hasPending) {
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

                        // 如果所有任务都完成，显示绿色线
                        if (allCompleted) {
                          return Positioned(
                            bottom: 1,
                            child: Container(
                              width: 20,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(1.5),
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
    // 允许最大索引为 5 (即第6行)
    return rowIndex.clamp(0, _showRowsCount - 1);
  }

  @override
  double get maxExtent => _maxExtent;

  @override
  double get minExtent => _minExtent;

  @override
  bool shouldRebuild(covariant _CalendarHeaderDelegate oldDelegate) {
    return oldDelegate.focusedDay != focusedDay ||
        oldDelegate.selectedDay != selectedDay ||
        oldDelegate.scheduleUpdateCount != scheduleUpdateCount;
  }
}
