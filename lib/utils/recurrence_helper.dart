import 'package:flutter/material.dart';
import '../models/schedule/schedule.dart';
import '../models/schedule/recurrence_rule.dart';

/// 重复日程辅助工具类
class RecurrenceHelper {
  /// 判断是否为重复日程的实例
  static bool isRecurringInstance(Schedule schedule) {
    return schedule.parentId != null && schedule.parentId!.isNotEmpty;
  }

  /// 判断是否有重复规则（用于创建时）
  static bool hasRecurrenceRule(Schedule schedule) {
    return schedule.recurrence != null && schedule.recurrence!.isNotEmpty;
  }

  /// 构建重复标识徽章
  static Widget buildRecurrenceBadge(Schedule schedule) {
    if (!isRecurringInstance(schedule) && !hasRecurrenceRule(schedule)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat, size: 12, color: Colors.purple),
          const SizedBox(width: 4),
          Text(
            '重复',
            style: TextStyle(
              fontSize: 10,
              color: Colors.purple[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (schedule.iterationIndex != null) ...[
            const SizedBox(width: 2),
            Text(
              '·${schedule.iterationIndex}',
              style: TextStyle(fontSize: 9, color: Colors.purple[600]),
            ),
          ],
        ],
      ),
    );
  }

  /// 解析 RRULE 字符串为用户友好文本
  static String parseRRuleToText(String? rrule) {
    if (rrule == null || rrule.isEmpty) {
      return '不重复';
    }

    try {
      final rule = RecurrenceRule.fromRRule(rrule);
      return rule.toDisplayText();
    } catch (e) {
      return '重复';
    }
  }

  /// 构建重复规则展示行（用于详情页）
  static Widget buildRecurrenceInfoRow(Schedule schedule) {
    if (!isRecurringInstance(schedule) && !hasRecurrenceRule(schedule)) {
      return const SizedBox.shrink();
    }

    final text = parseRRuleToText(schedule.recurrence);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.repeat, size: 16, color: Colors.purple),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '重复规则',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(fontSize: 13)),
                if (schedule.iterationIndex != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '这是系列任务的第 ${schedule.iterationIndex} 次',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建系列操作提示（用于编辑/删除对话框）
  static Widget buildSeriesOperationWarning(Schedule schedule) {
    if (!isRecurringInstance(schedule)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '这是重复日程的一个实例',
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '修改只影响这一次，不会影响系列中的其他实例',
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
