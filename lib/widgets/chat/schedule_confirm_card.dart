import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScheduleConfirmCard extends StatelessWidget {
  const ScheduleConfirmCard({
    super.key,
    required this.parsed,
    required this.onConfirm,
    required this.onCancel,
    this.onEdit,
    this.creating = false,
  });

  final Map<String, dynamic> parsed;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;
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
      _InfoRow('类型', _mapType(parsed['type'])),
      _InfoRow('优先级', _mapPriority(parsed['priority'])),
      _InfoRow('提前提醒（分钟）', _valueOf(parsed['remindBefore'])),
    ].where((row) => row.value.isNotEmpty).toList();

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行 + 右上角叉号
            Row(
              children: [
                const Icon(Icons.event_available_outlined, size: 18),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '识别到日程信息',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: creating ? null : onCancel,
                    tooltip: '取消',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
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
                    onPressed: creating ? null : onEdit,
                    child: const Text('修改'),
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

String _mapType(dynamic value) {
  const map = {'meeting': '会议', 'task': '任务', 'event': '活动', 'reminder': '提醒'};
  final raw = _valueOf(value);
  return map[raw] ?? raw;
}

String _mapPriority(dynamic value) {
  const map = {'low': '低', 'medium': '中', 'high': '高'};
  final raw = _valueOf(value);
  return map[raw] ?? raw;
}

String _mergeDateTime(dynamic date, dynamic time) {
  final dateText = _valueOf(date);
  final timeText = _valueOf(time);
  if (dateText.isEmpty && timeText.isEmpty) return '';

  // 尝试解析日期部分
  DateTime? dateOnly;
  if (dateText.isNotEmpty) {
    dateOnly = DateTime.tryParse(dateText);
  }

  // 尝试解析时间部分（支持 HH:mm 和完整 ISO 格式）
  DateTime? timeDt;
  if (timeText.isNotEmpty) {
    // 纯时间格式 "HH:mm" 或 "H:mm"
    final hhmm = RegExp(r'^(\d{1,2}):(\d{2})$');
    final m = hhmm.firstMatch(timeText);
    if (m != null) {
      final base = dateOnly ?? DateTime.now();
      timeDt = DateTime(
        base.year,
        base.month,
        base.day,
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
      );
    } else {
      // 完整 ISO 日期时间格式
      timeDt = DateTime.tryParse(timeText)?.toLocal();
    }
  }

  // 格式化输出
  if (timeDt != null) {
    final dateFmt = DateFormat('M月d日', 'zh_CN');
    final timeFmt = DateFormat('HH:mm', 'zh_CN');
    return '${dateFmt.format(timeDt)} ${timeFmt.format(timeDt)}';
  }
  if (dateOnly != null) {
    return DateFormat('M月d日', 'zh_CN').format(dateOnly);
  }
  // 均无法解析，退回原始拼接
  if (dateText.isEmpty) return timeText;
  if (timeText.isEmpty) return dateText;
  return '$dateText $timeText';
}
