import 'package:flutter/material.dart';

class ScheduleConfirmCard extends StatelessWidget {
  const ScheduleConfirmCard({
    super.key,
    required this.parsed,
    required this.onConfirm,
    required this.onCancel,
    this.creating = false,
  });

  final Map<String, dynamic> parsed;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool creating;

  @override
  Widget build(BuildContext context) {
    final rows = <_InfoRow>[
      _InfoRow('标题', _valueOf(parsed['title'])),
      _InfoRow('备注', _valueOf(parsed['description'])),
      _InfoRow(
        '开始时间',
        _mergeDateTime(parsed['startDate'], parsed['startTime']),
      ),
      _InfoRow('结束时间', _mergeDateTime(parsed['endDate'], parsed['endTime'])),
      _InfoRow('地点', _valueOf(parsed['location'])),
      _InfoRow('类型', _valueOf(parsed['type'])),
      _InfoRow('优先级', _valueOf(parsed['priority'])),
      _InfoRow('提前提醒（分钟）', _valueOf(parsed['remindBefore'])),
    ].where((row) => row.value.isNotEmpty).toList();

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.event_available_outlined, size: 18),
                SizedBox(width: 6),
                Text(
                  '识别到日程信息',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${row.label}：${row.value}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF3D4350),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: creating ? null : onCancel,
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: creating ? null : onConfirm,
                    child: creating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('确认创建'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;
}

String _valueOf(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  return text == 'null' ? '' : text;
}

String _mergeDateTime(dynamic date, dynamic time) {
  final dateText = _valueOf(date);
  final timeText = _valueOf(time);
  if (dateText.isEmpty && timeText.isEmpty) return '';
  if (dateText.isEmpty) return timeText;
  if (timeText.isEmpty) return dateText;
  return '$dateText $timeText';
}
