import 'package:flutter/material.dart';

import '../../models/daily/daily_task.dart';
import 'daily_task_card.dart';

class DailyTaskGroupList extends StatelessWidget {
  const DailyTaskGroupList({
    super.key,
    required this.tasks,
    required this.statusFilter,
    required this.autoFocusTaskId,
    required this.use24HourFormat,
    required this.onRefresh,
    required this.onTitleChanged,
    required this.onDelete,
    required this.onDetailsTap,
    required this.onTaskUpdated,
    required this.onFinishEditing,
  });

  final List<DailyTask> tasks;
  final String statusFilter;
  final String? autoFocusTaskId;
  final bool use24HourFormat;
  final Future<void> Function() onRefresh;
  final void Function(String taskId, String newTitle) onTitleChanged;
  final void Function(String taskId) onDelete;
  final void Function(DailyTask task) onDetailsTap;
  final void Function(DailyTask updatedTask) onTaskUpdated;
  final void Function(String taskId) onFinishEditing;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(children: _buildTaskGroups(context)),
    );
  }

  List<Widget> _buildTaskGroups(BuildContext context) {
    final uncategorized = tasks
        .where((t) => t.category == null || t.category!.trim().isEmpty)
        .toList();

    final Map<String, List<DailyTask>> grouped = {};
    for (final task in tasks) {
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
      autoFocus: autoFocusTaskId == task.id,
      onTitleChanged: (newTitle) => onTitleChanged(task.id, newTitle),
      onDelete: () => onDelete(task.id),
      onDetailsTap: () => onDetailsTap(task),
      onTaskUpdated: (updated) {
        if (updated.status != statusFilter) {
          onTaskUpdated(updated);
          return;
        }
        onTaskUpdated(updated);
      },
      onFinishEditing: () => onFinishEditing(task.id),
      use24HourFormat: use24HourFormat,
      showInfo: true,
    );
  }
}
