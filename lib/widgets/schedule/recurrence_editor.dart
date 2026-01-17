import 'package:flutter/material.dart';
import '../../models/schedule/recurrence_rule.dart';

/// 重复规则编辑器组件
///
/// 用于创建/编辑日程时配置重复规则
class RecurrenceEditor extends StatefulWidget {
  final RecurrenceRule? initialRule;
  final Function(RecurrenceRule?) onChanged;

  const RecurrenceEditor({
    super.key,
    this.initialRule,
    required this.onChanged,
  });

  @override
  State<RecurrenceEditor> createState() => _RecurrenceEditorState();
}

class _RecurrenceEditorState extends State<RecurrenceEditor> {
  bool _isEnabled = false;
  String _frequency = 'WEEKLY';
  int _interval = 1;
  Set<String> _selectedDays = {'MO'};
  RecurrenceEndType _endType = RecurrenceEndType.never;
  DateTime? _endDate;
  int _count = 10;

  @override
  void initState() {
    super.initState();
    if (widget.initialRule != null) {
      _isEnabled = true;
      _frequency = widget.initialRule!.frequency;
      _interval = widget.initialRule!.interval;
      _selectedDays = widget.initialRule!.byDay?.toSet() ?? {};
      if (widget.initialRule!.until != null) {
        _endType = RecurrenceEndType.until;
        _endDate = widget.initialRule!.until;
      } else if (widget.initialRule!.count != null) {
        _endType = RecurrenceEndType.count;
        _count = widget.initialRule!.count!;
      }
    }
  }

  void _notifyChange() {
    if (!_isEnabled) {
      widget.onChanged(null);
      return;
    }

    final rule = RecurrenceRule(
      frequency: _frequency,
      interval: _interval,
      byDay: _frequency == 'WEEKLY' && _selectedDays.isNotEmpty
          ? _selectedDays.toList()
          : null,
      until: _endType == RecurrenceEndType.until ? _endDate : null,
      count: _endType == RecurrenceEndType.count ? _count : null,
    );

    widget.onChanged(rule);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 重复开关
        SwitchListTile(
          title: const Text(
            '重复',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: _isEnabled && widget.initialRule != null
              ? Text(
                  widget.initialRule!.toDisplayText(),
                  style: const TextStyle(fontSize: 12),
                )
              : null,
          value: _isEnabled,
          onChanged: (value) {
            setState(() {
              _isEnabled = value;
              _notifyChange();
            });
          },
          secondary: const Icon(Icons.repeat),
        ),

        // 展开配置
        if (_isEnabled) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 频率选择
                _buildFrequencySection(),
                const SizedBox(height: 16),

                // 间隔选择
                _buildIntervalSection(),
                const SizedBox(height: 16),

                // 周几选择（仅 WEEKLY 显示）
                if (_frequency == 'WEEKLY') ...[
                  _buildWeekdaySection(),
                  const SizedBox(height: 16),
                ],

                // 结束条件
                _buildEndSection(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFrequencySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('重复频率', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.today, size: 16),
                  SizedBox(width: 4),
                  Text('每天'),
                ],
              ),
              selected: _frequency == 'DAILY',
              onSelected: (_) {
                setState(() {
                  _frequency = 'DAILY';
                  _notifyChange();
                });
              },
            ),
            ChoiceChip(
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.view_week, size: 16),
                  SizedBox(width: 4),
                  Text('每周'),
                ],
              ),
              selected: _frequency == 'WEEKLY',
              onSelected: (_) {
                setState(() {
                  _frequency = 'WEEKLY';
                  _notifyChange();
                });
              },
            ),
            ChoiceChip(
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month, size: 16),
                  SizedBox(width: 4),
                  Text('每月'),
                ],
              ),
              selected: _frequency == 'MONTHLY',
              onSelected: (_) {
                setState(() {
                  _frequency = 'MONTHLY';
                  _notifyChange();
                });
              },
            ),
            ChoiceChip(
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event, size: 16),
                  SizedBox(width: 4),
                  Text('每年'),
                ],
              ),
              selected: _frequency == 'YEARLY',
              onSelected: (_) {
                setState(() {
                  _frequency = 'YEARLY';
                  _notifyChange();
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIntervalSection() {
    final unitMap = {
      'DAILY': '天',
      'WEEKLY': '周',
      'MONTHLY': '月',
      'YEARLY': '年',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('重复间隔', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('每'),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: DropdownButtonFormField<int>(
                value: _interval,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(),
                ),
                items: List.generate(10, (i) => i + 1)
                    .map((i) => DropdownMenuItem(value: i, child: Text('$i')))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _interval = value ?? 1;
                    _notifyChange();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(unitMap[_frequency] ?? '次'),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekdaySection() {
    final days = [
      {'key': 'MO', 'label': '一'},
      {'key': 'TU', 'label': '二'},
      {'key': 'WE', 'label': '三'},
      {'key': 'TH', 'label': '四'},
      {'key': 'FR', 'label': '五'},
      {'key': 'SA', 'label': '六'},
      {'key': 'SU', 'label': '日'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('重复日期', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: days.map((day) {
            final key = day['key']!;
            final label = day['label']!;
            final isSelected = _selectedDays.contains(key);

            return FilterChip(
              label: Text('周$label'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedDays.add(key);
                  } else {
                    if (_selectedDays.length > 1) {
                      _selectedDays.remove(key);
                    } else {
                      // 至少保留一个
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('至少选择一天'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                  _notifyChange();
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEndSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('结束条件', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),

        // 永不结束
        RadioListTile<RecurrenceEndType>(
          title: const Text('永不结束'),
          value: RecurrenceEndType.never,
          groupValue: _endType,
          onChanged: (value) {
            setState(() {
              _endType = value!;
              _notifyChange();
            });
          },
          contentPadding: EdgeInsets.zero,
        ),

        // 截止日期
        RadioListTile<RecurrenceEndType>(
          title: const Text('截止日期'),
          value: RecurrenceEndType.until,
          groupValue: _endType,
          onChanged: (value) {
            setState(() {
              _endType = value!;
              if (_endDate == null) {
                _endDate = DateTime.now().add(const Duration(days: 30));
              }
              _notifyChange();
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
        if (_endType == RecurrenceEndType.until)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 8),
            child: GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate:
                      _endDate ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() {
                    _endDate = date;
                    _notifyChange();
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today, size: 20),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  _endDate != null
                      ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
                      : '选择日期',
                  style: TextStyle(
                    color: _endDate != null ? Colors.black87 : Colors.grey,
                  ),
                ),
              ),
            ),
          ),

        // 重复次数
        RadioListTile<RecurrenceEndType>(
          title: const Text('重复次数'),
          value: RecurrenceEndType.count,
          groupValue: _endType,
          onChanged: (value) {
            setState(() {
              _endType = value!;
              _notifyChange();
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
        if (_endType == RecurrenceEndType.count)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 8),
            child: Row(
              children: [
                const Text('重复'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: _count.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (value) {
                      final num = int.tryParse(value);
                      if (num != null && num > 0) {
                        setState(() {
                          _count = num;
                          _notifyChange();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text('次'),
              ],
            ),
          ),
      ],
    );
  }
}
