# 日历页面设计方案

## 一、功能需求概述

### 核心功能
1. **日历大视图**：月视图显示整月日期
2. **日程标记**：有日程的日期显示红点提示
3. **日期选择**：点击日期查看当天所有日程
4. **日程列表**：显示选中日期的日程简要信息
5. **详情展开**：点击箭头展开查看完整日程详情

---

## 二、数据模型设计

### Schedule 模型（根据 Swagger 文档）

```dart
class Schedule {
  final String id;
  final String userId;
  final String title;              // 日程标题
  final String? description;       // 描述
  final DateTime startTime;        // 开始时间
  final DateTime endTime;          // 结束时间
  final bool allDay;               // 是否全天
  final String? location;          // 地点
  final String status;             // 状态：pending/completed/cancelled
  final String? type;              // 类型：meeting/task/event
  final String? priority;          // 优先级：high/medium/low
  final String? recurrence;        // 重复规则
  final String? participants;      // 参与者（JSON字符串）
  final String? notes;             // 备注
  final String? attachments;       // 附件（JSON字符串）
  final String? daomengId;         // 到梦ID
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
```

---

## 三、UI 设计

### 3.1 整体布局

```
┌─────────────────────────────────────┐
│  日历            [今天] [+新建]     │  ← AppBar
├─────────────────────────────────────┤
│                                     │
│  ◄  2025年11月  ►                  │  ← 月份选择器
│                                     │
│  日  一  二  三  四  五  六         │  ← 星期标题
│  ─────────────────────────────      │
│  27  28  29  30  31   1   2        │
│   3   4  ●5   6   7  ●8   9        │  ← 日期网格
│  10  11  12  13  14  15  16        │     ● = 有日程
│  17  18  19  20 【21】22  23        │    【】= 选中日期
│  24  25  26  27  28  29  30        │
│                                     │
├─────────────────────────────────────┤
│  2025年11月21日 的日程（3）        │  ← 日程列表标题
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────┐    │
│ │ 📅 团队会议         ▼      │    │  ← 日程卡片（折叠状态）
│ │ 14:00-15:30                 │
│ │ 📍 会议室A  🟢 进行中       │
│ └─────────────────────────────┘    │
│                                     │
│ ┌─────────────────────────────┐    │
│ │ 📋 项目评审         ▲      │    │  ← 日程卡片（展开状态）
│ │ 16:00-17:00                 │
│ │ 📍 会议室B  ⚪ 待开始      │
│ │ ───────────────────────     │
│ │ 描述：季度项目评审会议      │
│ │ 优先级：高 🔴              │
│ │ 参与者：张三、李四          │
│ │ 备注：需准备PPT             │
│ └─────────────────────────────┘    │
│                                     │
│ ┌─────────────────────────────┐    │
│ │ ✅ 完成报告         ▼      │    │  ← 已完成日程
│ │ 全天                        │
│ │ ✓ 已完成                    │
│ └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

### 3.2 日期单元格设计

```dart
// 普通日期
┌───────┐
│  15   │
└───────┘

// 今天（蓝色背景）
┌───────┐
│【15】 │  ← 蓝色圆形背景
└───────┘

// 选中日期（深蓝背景）
┌───────┐
│《15》 │  ← 深蓝色圆形背景
└───────┘

// 有日程的日期（底部红点）
┌───────┐
│  15   │
│   ●   │  ← 红色小圆点
└───────┘

// 今天+有日程
┌───────┐
│【15】 │
│   ●   │
└───────┘
```

### 3.3 日程卡片设计

#### 折叠状态（默认）
```
┌─────────────────────────────────┐
│ 📅 团队会议              ▼     │  ← 标题 + 图标 + 展开箭头
│ 14:00-15:30                     │  ← 时间范围
│ 📍 会议室A  🟢 进行中           │  ← 地点 + 状态
└─────────────────────────────────┘
```

#### 展开状态
```
┌─────────────────────────────────┐
│ 📅 团队会议              ▲     │  ← 收起箭头
│ 14:00-15:30                     │
│ 📍 会议室A  🟢 进行中           │
│ ─────────────────────────────   │  ← 分割线
│ 📝 描述                         │
│ 讨论Q4季度目标和项目进展       │
│                                 │
│ 📊 类型：会议                   │
│ 🔥 优先级：高 🔴               │
│ 👥 参与者：张三、李四、王五     │
│ 🔄 重复：无                     │
│ 📎 附件：无                     │
│ 📌 备注：请提前准备资料         │
└─────────────────────────────────┘
```

### 3.4 状态颜色标识

```dart
状态：
- 🔵 进行中 (蓝色) - status: "in_progress"
- ⚪ 待开始 (灰色) - status: "pending"
- ✅ 已完成 (绿色) - status: "completed"
- ❌ 已取消 (红色) - status: "cancelled"

优先级：
- 🔴 高 (红色) - priority: "high"
- 🟡 中 (黄色) - priority: "medium"
- 🟢 低 (绿色) - priority: "low"

类型图标：
- 📅 会议 - type: "meeting"
- 📋 任务 - type: "task"
- 🎉 活动 - type: "event"
- 📝 其他 - type: null
```

---

## 四、技术实现方案

### 4.1 依赖包选择

**推荐方案 A：table_calendar（推荐）**
```yaml
dependencies:
  table_calendar: ^3.1.2  # 功能强大，高度可定制
```
- ✅ 功能完整，支持多种视图
- ✅ 自定义性强
- ✅ 活跃维护，文档完善
- ✅ 支持标记、事件显示

**方案 B：flutter_calendar_carousel**
```yaml
dependencies:
  flutter_calendar_carousel: ^2.4.2
```
- ✅ 轻量级
- ❌ 自定义相对复杂

**方案 C：自己实现（不推荐）**
- ❌ 开发工作量大
- ❌ 需要处理大量边界情况

**建议：使用 table_calendar**

### 4.2 页面结构

```dart
CalendarPage (StatefulWidget)
├── AppBar
│   ├── Title: "日历"
│   ├── Actions: [今天按钮, 新建按钮]
├── Body: Column
│   ├── TableCalendar Widget (日历视图)
│   │   ├── 月份选择器
│   │   ├── 星期标题
│   │   ├── 日期网格
│   │   └── 红点标记（有日程的日期）
│   ├── Divider
│   └── Expanded: ScheduleListView (日程列表)
│       └── ListView.builder
│           └── ScheduleCard (可展开的日程卡片)
```

### 4.3 状态管理

```dart
class _CalendarPageState {
  DateTime _focusedDay = DateTime.now();      // 当前焦点月份
  DateTime? _selectedDay = DateTime.now();    // 选中的日期
  List<Schedule> _allSchedules = [];          // 所有日程
  Map<DateTime, List<Schedule>> _scheduleMap = {}; // 日期->日程映射
  Set<String> _expandedScheduleIds = {};      // 展开的日程ID集合
  bool _isLoading = true;                     // 加载状态
}
```

### 4.4 数据流程

```
1. initState()
   ↓
2. _loadSchedules() → GET /api/schedules
   ↓
3. _buildScheduleMap() → 按日期分组
   ↓
4. setState() → 更新UI
   ↓
5. 用户点击日期 → _onDaySelected()
   ↓
6. setState() → 更新选中日期和日程列表
```

### 4.5 API 调用

```dart
// ScheduleService
class ScheduleService {
  // 获取所有日程
  Future<List<Schedule>> getSchedules() async {
    final response = await ApiClient.instance.get('/schedules');
    return (response.data as List)
        .map((json) => Schedule.fromJson(json))
        .toList();
  }
  
  // 获取指定日期范围的日程
  Future<List<Schedule>> getSchedulesByDateRange(
    DateTime start, 
    DateTime end
  ) async {
    // 如果后端支持日期范围查询
    final response = await ApiClient.instance.get(
      '/schedules',
      queryParameters: {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      },
    );
    // ...
  }
}
```

### 4.6 日期映射逻辑

```dart
Map<DateTime, List<Schedule>> _buildScheduleMap(List<Schedule> schedules) {
  final map = <DateTime, List<Schedule>>{};
  
  for (var schedule in schedules) {
    // 标准化日期（去掉时分秒）
    final date = DateTime(
      schedule.startTime.year,
      schedule.startTime.month,
      schedule.startTime.day,
    );
    
    if (map[date] == null) {
      map[date] = [];
    }
    map[date]!.add(schedule);
  }
  
  // 按开始时间排序
  for (var schedules in map.values) {
    schedules.sort((a, b) => a.startTime.compareTo(b.startTime));
  }
  
  return map;
}
```

---

## 五、交互设计

### 5.1 日历交互

| 操作 | 响应 |
|------|------|
| 点击日期 | 选中该日期，显示该日期的日程列表 |
| 左右滑动 | 切换上/下月 |
| 点击月份 | 打开月份选择器（可选） |
| 点击"今天" | 跳转到今天并选中 |
| 双击日期 | 快速创建该日期的日程（可选） |

### 5.2 日程列表交互

| 操作 | 响应 |
|------|------|
| 点击日程卡片 | 展开/折叠详情 |
| 长按日程卡片 | 显示操作菜单（编辑/删除） |
| 左滑日程卡片 | 显示快捷操作（完成/删除）（可选） |
| 点击"+新建" | 跳转到创建日程页面 |

### 5.3 加载状态

```dart
// 初始加载
Center(child: CircularProgressIndicator())

// 空状态（选中日期无日程）
Center(
  child: Column(
    children: [
      Icon(Icons.event_available, size: 64, color: Colors.grey),
      Text('这一天还没有日程'),
      TextButton(
        onPressed: () => _createSchedule(_selectedDay),
        child: Text('创建日程'),
      ),
    ],
  ),
)

// 错误状态
Center(
  child: Column(
    children: [
      Icon(Icons.error_outline, size: 64, color: Colors.red),
      Text('加载失败'),
      TextButton(
        onPressed: _loadSchedules,
        child: Text('重试'),
      ),
    ],
  ),
)
```

---

## 六、性能优化

### 6.1 数据优化
- ✅ 使用 `Map<DateTime, List<Schedule>>` 快速查找
- ✅ 日程按开始时间预排序
- ✅ 懒加载：只加载当前月份±1个月的数据（可选）

### 6.2 UI 优化
- ✅ 使用 `ListView.builder` 按需构建
- ✅ 使用 `const` 构造函数
- ✅ 日历使用 `TableCalendar` 的内置优化
- ✅ 展开动画使用 `AnimatedContainer`

### 6.3 内存优化
- ✅ 及时清理不需要的数据
- ✅ 图片（附件）使用缓存
- ✅ 避免重复解析 JSON

---

## 七、待实现功能清单

### 第一阶段（MVP）
1. ✅ 日历视图显示
2. ✅ 从后端获取日程
3. ✅ 有日程的日期显示红点
4. ✅ 点击日期显示日程列表
5. ✅ 日程卡片折叠/展开
6. ✅ 基础日程信息展示

### 第二阶段（增强）
1. 🔲 创建/编辑/删除日程
2. 🔲 日程搜索功能
3. 🔲 日程筛选（按类型/状态）
4. 🔲 日程提醒通知
5. 🔲 日程导出（iCal格式）
6. 🔲 按月加载优化（加载当前月±1个月）

### 第三阶段（高级）
1. 🔲 拖拽调整日程时间
2. 🔲 周视图/日视图切换
3. 🔲 日程冲突检测
4. 🔲 重复日程支持
5. 🔲 多人协作日程

---

## 八、需要创建/修改的文件

### 新建文件
```
lib/
├── models/
│   └── schedule.dart              # Schedule 数据模型
├── services/
│   └── schedule_service.dart      # 日程 API 服务
├── pages/
│   └── calendar_page.dart         # 日历页面（重写）
└── widgets/
    ├── schedule_card.dart         # 日程卡片组件
    └── calendar_event_marker.dart # 日历红点标记组件（可选）
```

### 修改文件
```
pubspec.yaml                       # 添加 table_calendar 依赖
.github/copilot-instructions.md   # 更新项目文档
```

---

## 九、需要确认的问题

### ❓ 问题 1：日历包选择
使用 `table_calendar` 还是其他方案？
- **推荐**：table_calendar（功能最完整）

### ✅ 问题 2：数据加载策略（已确认）
**选择**：方案 A - 一次性加载所有日程
- ✅ 实现简单
- ✅ MVP 阶段优先
- 📋 后期优化：改为按月加载（已加入计划）

### ✅ 问题 3：日程详情显示方式（已确认）
**选择**：方案 A - 卡片内展开
- ✅ 操作流畅，无需页面跳转
- ✅ 适合查看日程详情

### ✅ 问题 4：红点显示规则（已确认）
**选择**：方案 B - 只有未完成的日程才显示红点
- ✅ 避免视觉噪音
- ✅ 突出待办事项
- 排除已完成和已取消的日程

### ✅ 问题 5：日程状态判断逻辑（已确认）
**选择**：方案 B - 使用后端返回的状态
- ✅ 以后端 status 字段为准
- ✅ 数据一致性更好
- 前端直接使用 status 值显示对应颜色和文字

### ✅ 问题 6：全天日程显示（已确认）
**选择**：方案 A - 显示"全天"
- ✅ 简洁明了
- ✅ 用户友好

---

## 十、实现优先级

### P0（必须实现）
- ✅ 日历视图基础显示
- ✅ 从后端获取日程数据
- ✅ 日期选择和日程列表显示
- ✅ 日程简要信息展示

### P1（重要）
- ✅ 日程详情展开/折叠
- ✅ 有日程的日期红点标记
- ✅ 状态颜色标识
- ✅ 加载和错误状态处理

### P2（可选）
- 🔲 下拉刷新
- 🔲 日程卡片左滑快捷操作
- 🔲 "今天"按钮
- 🔲 空状态优化

---

## 十一、开发时间估算

- **数据模型 + 服务层**：30 分钟
- **日历视图集成**：1 小时
- **日程列表和卡片**：1.5 小时
- **交互逻辑和状态管理**：1 小时
- **样式优化和细节调整**：1 小时
- **测试和调试**：30 分钟

**总计：约 5.5 小时**

---

## 十二、示例代码片段

### 日历红点标记
```dart
TableCalendar(
  eventLoader: (day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _scheduleMap[normalizedDay] ?? [];
  },
  calendarBuilders: CalendarBuilders(
    markerBuilder: (context, date, events) {
      if (events.isNotEmpty) {
        return Positioned(
          bottom: 1,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
            ),
          ),
        );
      }
      return null;
    },
  ),
)
```

### 日程卡片
```dart
class ScheduleCard extends StatelessWidget {
  final Schedule schedule;
  final bool isExpanded;
  final VoidCallback onTap;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  _getTypeIcon(schedule.type),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      schedule.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ],
              ),
              
              // 时间
              SizedBox(height: 4),
              Text(_formatTime(schedule)),
              
              // 地点和状态
              SizedBox(height: 4),
              Row(
                children: [
                  if (schedule.location != null) ...[
                    Icon(Icons.location_on, size: 14),
                    SizedBox(width: 4),
                    Text(schedule.location!),
                    SizedBox(width: 12),
                  ],
                  _getStatusChip(schedule.status),
                ],
              ),
              
              // 展开的详细信息
              if (isExpanded) ...[
                Divider(),
                _buildDetailedInfo(schedule),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

---

**请确认以上设计方案，我将开始实现代码！** 🚀
