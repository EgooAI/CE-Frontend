import 'package:flutter/material.dart';

import '../../models/daily/daily_task.dart';
import '../../models/schedule/schedule.dart';
import '../daily/daily_task_card.dart';
import '../schedule/schedule_card.dart';

class CalendarScheduleList extends StatelessWidget {
  const CalendarScheduleList({
    super.key,
    required this.selectedDay,
    required this.schedules,
    required this.dailyTasks,
    required this.showDailyTasksInCalendar,
    required this.isTodaySelected,
    required this.expandedScheduleIds,
    required this.use24HourFormat,
    required this.onCreateSchedule,
    required this.onDailyTaskUpdated,
    required this.onDailyTaskDetails,
    required this.onToggleScheduleExpanded,
    required this.onStatusChanged,
    required this.onEditSchedule,
    required this.onUpdateSchedule,
    required this.onDeleteSchedule,
  });

  final DateTime? selectedDay;
  final List<Schedule> schedules;
  final List<DailyTask> dailyTasks;
  final bool showDailyTasksInCalendar;
  final bool isTodaySelected;
  final Set<String> expandedScheduleIds;
  final bool use24HourFormat;
  final VoidCallback onCreateSchedule;
  final void Function(DailyTask updatedTask) onDailyTaskUpdated;
  final void Function(DailyTask task) onDailyTaskDetails;
  final void Function(String scheduleId) onToggleScheduleExpanded;
  final void Function(Schedule schedule, String newStatus) onStatusChanged;
  final void Function(Schedule schedule) onEditSchedule;
  final Future<void> Function(Schedule updatedSchedule) onUpdateSchedule;
  final void Function(Schedule schedule) onDeleteSchedule;

  @override
  Widget build(BuildContext context) {
    if (selectedDay == null) {
      return SliverFillRemaining(child: const Center(child: Text('请选择日期')));
    }

    final hasDailyTasks =
        showDailyTasksInCalendar && dailyTasks.isNotEmpty && isTodaySelected;

    // 如果既没有日程也没有日常任务，显示空状态
    if (schedules.isEmpty && !hasDailyTasks) {
      return SliverFillRemaining(
        child: _CalendarEmptyState(onCreate: onCreateSchedule),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // 列表标题（仅当有日程时显示）
        if (schedules.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Row(
              children: [
                Text(
                  '${selectedDay!.year}年${selectedDay!.month}月${selectedDay!.day}日 的日程',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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

        // 日常任务卡片（若启用）
        if (hasDailyTasks) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('今日日常', style: TextStyle(color: Colors.grey[700])),
          ),
          ...dailyTasks.map(
            (task) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DailyTaskCard(
                task: task,
                use24HourFormat: use24HourFormat,
                showInfo: false,
                onTaskUpdated: (updatedTask) {
                  onDailyTaskUpdated(updatedTask);
                },
                onDetailsTap: () => onDailyTaskDetails(task),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // 日程卡片列表（仅当有日程时显示）
        if (schedules.isNotEmpty)
          ...schedules.map((schedule) {
            final isExpanded = expandedScheduleIds.contains(schedule.id);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ScheduleCard(
                schedule: schedule,
                isExpanded: isExpanded,
                onTap: () => onToggleScheduleExpanded(schedule.id),
                onStatusChanged: (newStatus) =>
                    onStatusChanged(schedule, newStatus),
                onEdit: () => onEditSchedule(schedule),
                onUpdate: onUpdateSchedule,
                onDelete: () => onDeleteSchedule(schedule),
                use24HourFormat: use24HourFormat,
              ),
            );
          }),
      ]),
    );
  }
}

class _CalendarEmptyState extends StatelessWidget {
  const _CalendarEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
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
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('创建日程'),
          ),
        ],
      ),
    );
  }
}
