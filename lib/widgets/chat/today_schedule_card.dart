import 'package:flutter/material.dart';

class TodayScheduleCard extends StatelessWidget {
  const TodayScheduleCard({
    super.key,
    required this.payload,
    this.onViewAll,
    this.onAskAi,
  });

  final Map<String, dynamic> payload;
  final VoidCallback? onViewAll;
  final VoidCallback? onAskAi;

  @override
  Widget build(BuildContext context) {
    final state = payload['state']?.toString() ?? 'active';
    final dateLabel = payload['dateLabel']?.toString() ?? '';
    final offline = payload['offline'] == true;
    final items = _parseItems(payload['items']);
    final overflow = (payload['overflow'] as num?)?.toInt() ?? 0;
    final totalToday = (payload['totalToday'] as num?)?.toInt() ?? items.length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(state, dateLabel, offline),
            if (state == 'active') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Column(children: items.map(_buildScheduleItem).toList()),
              ),
              if (overflow > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Text(
                    '还有 $overflow 个日程 · 查看全部',
                    style: const TextStyle(
                      color: Color(0xFF70757A),
                      fontSize: 12,
                    ),
                  ),
                ),
              const Divider(height: 22),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: onViewAll,
                      child: const Text('查看全部日程'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: onAskAi,
                      child: const Text('让 AI 帮我规划今天'),
                    ),
                  ],
                ),
              ),
            ] else if (state == 'completed') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Text(
                  '今天的 $totalToday 个日程都已完成，辛苦了！',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: const Text(
                  '没有日程约束，好好享受今天吧。',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onViewAll,
                    child: const Text('新建日程 +'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String state, String dateLabel, bool offline) {
    String title;
    IconData icon;
    switch (state) {
      case 'completed':
        title = '今日全部完成';
        icon = Icons.celebration_outlined;
        break;
      case 'empty':
        title = '今天暂无安排';
        icon = Icons.wb_sunny_outlined;
        break;
      default:
        title = '今日待办';
        icon = Icons.calendar_today_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFE8F0FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1D4ED8)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D4ED8),
            ),
          ),
          const Spacer(),
          if (offline)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '离线数据',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ),
          Text(
            dateLabel,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'pending';
    final isInProgress = status == 'in_progress';
    final dotColor = isInProgress
        ? const Color(0xFFFF8F00)
        : const Color(0xFF1976D2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isInProgress ? dotColor : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: dotColor, width: 1.5),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['timeText']?.toString() ?? '未设置时间',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item['title']?.toString() ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
                if (isInProgress)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      '进行中',
                      style: TextStyle(fontSize: 12, color: Color(0xFFFF8F00)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _parseItems(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }
}
