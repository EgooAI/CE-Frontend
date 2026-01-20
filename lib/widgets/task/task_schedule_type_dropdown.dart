import 'package:flutter/material.dart';

class TaskScheduleTypeDropdown extends StatelessWidget {
  const TaskScheduleTypeDropdown({
    super.key,
    required this.selectedScheduleType,
    required this.scheduleTypeOptions,
    required this.onChanged,
  });

  final String selectedScheduleType;
  final Map<String, String> scheduleTypeOptions;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:
            Theme.of(context).appBarTheme.backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          padding: const EdgeInsets.all(8),
          value: selectedScheduleType,
          isDense: true,
          style: Theme.of(context).appBarTheme.titleTextStyle,
          icon: Icon(
            Icons.arrow_drop_down,
            color: Theme.of(context).appBarTheme.iconTheme?.color,
          ),
          focusColor: Colors.white.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(12.0),
          dropdownColor: Colors.white,
          items: scheduleTypeOptions.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                style: const TextStyle(color: Colors.black, fontSize: 16),
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
        ),
      ),
    );
  }
}
