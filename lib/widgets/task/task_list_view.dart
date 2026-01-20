import 'package:flutter/material.dart';

import '../../models/schedule/schedule.dart';
import '../schedule/schedule_card.dart';
import 'task_empty_state.dart';

class TaskListView extends StatelessWidget {
  const TaskListView({
    super.key,
    required this.tasks,
    required this.isSelectionMode,
    required this.selectedTaskIds,
    required this.expandedTaskIds,
    required this.use24HourFormat,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.showCreateButton,
    required this.onCreate,
    required this.onToggleTaskSelection,
    required this.onToggleTaskExpanded,
    required this.onStatusChanged,
    required this.onEdit,
    required this.onDelete,
    required this.formatDateTime,
    required this.buildStatusBadge,
  });

  final List<Schedule> tasks;
  final bool isSelectionMode;
  final Set<String> selectedTaskIds;
  final Set<String> expandedTaskIds;
  final bool use24HourFormat;
  final IconData emptyIcon;
  final String emptyMessage;
  final bool showCreateButton;
  final VoidCallback onCreate;
  final void Function(String taskId) onToggleTaskSelection;
  final void Function(String taskId) onToggleTaskExpanded;
  final void Function(Schedule task, String newStatus) onStatusChanged;
  final void Function(Schedule task) onEdit;
  final void Function(Schedule task) onDelete;
  final String Function(DateTime dateTime) formatDateTime;
  final Widget Function(String status) buildStatusBadge;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return TaskEmptyState(
        icon: emptyIcon,
        message: emptyMessage,
        showCreateButton: showCreateButton,
        onCreate: onCreate,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        isSelectionMode && selectedTaskIds.isNotEmpty ? 80 : 12,
      ),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final isExpanded = expandedTaskIds.contains(task.id);
        final isSelected = isSelectionMode && selectedTaskIds.contains(task.id);

        if (isSelectionMode) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onToggleTaskSelection(task.id),
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
                    onChanged: (_) => onToggleTaskSelection(task.id),
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
                        formatDateTime(task.startTime),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      if (task.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                  trailing: buildStatusBadge(task.status),
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ScheduleCard(
            schedule: task,
            isExpanded: isExpanded,
            onTap: () => onToggleTaskExpanded(task.id),
            onStatusChanged: (newStatus) => onStatusChanged(task, newStatus),
            onEdit: () => onEdit(task),
            onDelete: () => onDelete(task),
            use24HourFormat: use24HourFormat,
          ),
        );
      },
    );
  }
}
