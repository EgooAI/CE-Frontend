import 'package:flutter/material.dart';

class DailyStatusFilterDropdown extends StatelessWidget {
  const DailyStatusFilterDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: TextStyle(color: Colors.grey[800], fontSize: 13),
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700], size: 20),
          items: [
            DropdownMenuItem(
              value: 'active',
              child: Text('活跃', style: TextStyle(color: Colors.grey[800])),
            ),
            DropdownMenuItem(
              value: 'paused',
              child: Text('暂停', style: TextStyle(color: Colors.grey[800])),
            ),
          ],
          onChanged: (newValue) {
            if (newValue != null && newValue != value) {
              onChanged(newValue);
            }
          },
        ),
      ),
    );
  }
}
