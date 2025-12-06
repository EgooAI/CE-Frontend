# 重复日程 (Recurrence) API 文档

## 概述

重复日程功能采用**模板-实例分离**架构：
- **模板 (Template)**：存储重复规则和基础配置，不直接显示在日历上
- **实例 (Instance)**：根据模板生成的具体某一天的任务，用户实际看到和操作的对象
- **懒生成 (Lazy Generation)**：不会一次性生成未来所有实例，而是通过定时任务滚动生成下一个实例

## 核心概念

### 1. Recurrence 配置格式（JSON 对象）

前端传入的 `recurrence` 字段为 JSON 对象，格式如下：

```json
{
  "frequency": "WEEKLY",              // 必填：DAILY, WEEKLY, MONTHLY, YEARLY
  "interval": 1,                      // 可选：间隔，默认 1（每隔多少天/周/月）
  "by_day": ["MO", "WE", "FR"],      // 可选：仅在周几（周一、三、五）
  "until": "2026-12-31T00:00:00Z",   // 可选：截止日期（RFC3339 格式）
  "count": 10                         // 可选：重复次数
}
```

**字段说明：**
- `frequency`（必填）：重复频率
  - `DAILY`：每天
  - `WEEKLY`：每周
  - `MONTHLY`：每月
  - `YEARLY`：每年
- `interval`（可选）：间隔倍数，默认 1
  - 例如：`interval=2` + `frequency=WEEKLY` 表示每 2 周
- `by_day`（可选）：仅在指定的星期几重复，数组格式
  - 可选值：`SU`, `MO`, `TU`, `WE`, `TH`, `FR`, `SA`
  - 仅在 `frequency=WEEKLY` 时有效
- `until`（可选）：截止日期，RFC3339 格式（如 `2026-12-31T00:00:00Z`）
- `count`（可选）：重复次数（与 `until` 二选一）

**后端存储：**
- 后端会将 JSON 对象转换为 RFC 5545 RRULE 字符串存储在数据库中
- 例如：`FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,WE,FR;UNTIL=20261231T000000Z`

### 2. 数据模型

#### Schedule 实例（用户可见）
```json
{
  "id": "instance-uuid",
  "title": "每周团队会议",
  "startTime": "2025-12-08T10:00:00Z",
  "endTime": "2025-12-08T11:00:00Z",
  "parentId": "template-uuid",           // 指向模板 ID
  "iterationIndex": 3,                    // 第几次实例（从 1 开始）
  "recurrence": "FREQ=WEEKLY;INTERVAL=1", // 继承模板的 RRULE
  "status": "pending",
  "remindBefore": 15,
  // ... 其他字段
}
```

#### RecurrenceTemplate 模板（后台存储）
前端通常不直接操作，由后端自动管理。

---

## API 接口

### 1. 创建重复日程

**接口：** `POST /api/schedules`

**请求体：**
```json
{
  "title": "每周团队会议",
  "startTime": "2025-12-08T10:00:00Z",
  "endTime": "2025-12-08T11:00:00Z",
  "location": "会议室A",
  "type": "meeting",
  "priority": "high",
  "status": "pending",
  "remindBefore": 15,
  "recurrence": {
    "frequency": "WEEKLY",
    "interval": 1
  }
}
```

**响应示例：**
```json
{
  "code": 201,
  "message": "Recurring schedule created successfully with template ID: xxx, first instance ID: yyy",
  "data": null
}
```

**说明：**
- 如果请求包含 `recurrence` 字段且 `frequency` 不为空，系统将：
  1. 将 JSON 格式转换为 RRULE 字符串
  2. 创建一个模板 (RecurrenceTemplate)
  3. 生成第一个实例 (Schedule)，`parentId` 指向模板，`iterationIndex=1`
  4. 为第一个实例创建提醒
- 后续实例由定时任务自动生成（每 10 分钟扫描一次）
- 返回的实例中 `recurrence` 字段为 RRULE 字符串格式（后端存储格式）

---

### 2. 获取日程列表

**接口：** `GET /api/schedules`

**查询参数：**
```
startTime=2025-12-01T00:00:00Z  # 可选，过滤开始时间
endTime=2025-12-31T23:59:59Z    # 可选，过滤结束时间
limit=50                         # 可选，限制返回数量
```

**响应示例：**
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "id": "instance-1",
      "title": "每周团队会议",
      "startTime": "2025-12-08T10:00:00Z",
      "parentId": "template-uuid",
      "iterationIndex": 1,
      "recurrence": "FREQ=WEEKLY;INTERVAL=1",
      "reminders": [
        {
          "id": "reminder-1",
          "remindAt": "2025-12-08T09:45:00Z",
          "reminded": false
        }
      ]
    },
    {
      "id": "instance-2",
      "title": "每周团队会议",
      "startTime": "2025-12-15T10:00:00Z",
      "parentId": "template-uuid",
      "iterationIndex": 2,
      "recurrence": "FREQ=WEEKLY;INTERVAL=1"
    }
  ]
}
```

**前端处理建议：**
- 根据 `parentId` 分组，同一 `parentId` 的实例属于同一系列
- 显示时可标记"重复"图标，或在详情页展示"这是系列任务的第 X 次"
- `recurrence` 字段可解析后展示为用户友好的文本（如"每周重复"）

---

### 3. 获取单个日程详情

**接口：** `GET /api/schedules/{id}`

**响应示例：**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": "instance-1",
    "title": "每周团队会议",
    "startTime": "2025-12-08T10:00:00Z",
    "parentId": "template-uuid",
    "iterationIndex": 1,
    "recurrence": "FREQ=WEEKLY;INTERVAL=1",
    "reminders": [...]
  }
}
```

---

### 4. 更新单个实例

**接口：** `PUT /api/schedules/{id}`

**请求体：**
```json
{
  "title": "团队会议（本周改时间）",
  "startTime": "2025-12-08T14:00:00Z"  // 修改某一次的时间
}
```

**说明：**
- 更新单个实例不会影响模板和其他实例
- 如果修改了 `startTime` 或 `remindBefore`，系统会自动：
  1. 软删除该实例的旧提醒
  2. 基于新时间创建新提醒
- 该实例的 `parentId` 和 `iterationIndex` 保持不变

**注意事项：**
- 当前版本不支持"从此次开始修改所有未来实例"
- 如需修改整个系列，建议删除模板后重新创建

---

### 5. 删除单个实例

**接口：** `DELETE /api/schedules/{id}`

**说明：**
- 软删除该实例（`deleted_at` 字段标记）
- 该实例的提醒也会被软删除
- 不影响模板和其他实例
- 定时任务仍会基于模板生成后续实例

---

### 6. 修改重复日程系列（模板）

**接口：** `PUT /api/schedules/series/{parentId}`

**说明：**
- 修改重复日程模板的配置
- 前端传入完整的模板数据（所有字段）
- **不影响已生成的实例**（保持历史记录不变）
- 后续定时任务会基于新模板生成新实例

**请求体示例：**
```json
{
  "title": "每周团队会议（更新后）",
  "startTime": "2025-12-08T14:00:00Z",
  "endTime": "2025-12-08T15:00:00Z",
  "location": "会议室B",
  "type": "meeting",
  "priority": "high",
  "status": "pending",
  "remindBefore": 30,
  "recurrence": {
    "frequency": "WEEKLY",
    "interval": 2,
    "by_day": ["MO", "FR"]
  }
}
```

**响应示例：**
```json
{
  "code": 200,
  "message": "Recurrence template updated successfully",
  "data": {
    "templateId": "template-uuid"
  }
}
```

**注意事项：**
- 前端需要传入完整的模板数据（包括所有字段）
- 已生成的实例不会自动更新，保持原有配置
- 如果修改了 `recurrence` 规则，定时任务会基于新规则生成后续实例
- 如果修改了 `startTime`，新实例将使用新的开始时间
- 只有模板的创建者（通过 userId 验证）可以修改

**应用场景：**
- 调整重复规则（如从每周改为每两周）
- 修改会议时间（如从上午改到下午）
- 更新会议地点或标题
- 调整提醒时间

---

### 7. 删除重复日程系列（模板）

**接口：** `DELETE /api/schedules/series/{parentId}`

**查询参数：**
```
deleteInstances=none|future|all  # 可选，默认 none
```

**参数说明：**
- `none`（默认）：只删除模板，保留所有已生成的实例（包括已完成和待办）
- `future`：删除模板 + 所有待办（pending）实例
- `all`：删除模板 + 所有实例（包括已完成的历史记录）

**请求示例：**
```bash
# 只删除模板，保留所有实例
DELETE /api/schedules/series/template-uuid

# 删除模板和所有待办实例
DELETE /api/schedules/series/template-uuid?deleteInstances=future

# 删除模板和所有实例（包括已完成）
DELETE /api/schedules/series/template-uuid?deleteInstances=all
```

**响应示例：**
```json
{
  "code": 200,
  "message": "Recurrence series deleted successfully",
  "data": {
    "deletedInstances": 5,    // 被删除的实例数量
    "retainedInstances": 3    // 保留的实例数量
  }
}
```

**说明：**
- 模板删除后，定时任务将不再生成新实例（通过检查 `deleted_at` 字段）
- 删除操作是软删除（`deleted_at` 字段标记），可恢复
- 删除实例时，关联的提醒也会被软删除
- 只有模板的创建者（通过 userId 验证）可以删除

**应用场景：**
- `none`：用户想停止生成新实例，但保留历史记录（如"暂停这个系列"）
- `future`：取消未来所有待办，但保留已完成的记录（如"系列任务完成，不再继续"）
- `all`：完全清除这个系列的所有痕迹（如"这个系列创建错了，全部删除"）

---

### 8. 获取所有重复日程模板

**接口：** `GET /api/schedules/templates`

**响应示例：**
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "id": "template-uuid-1",
      "title": "每周团队会议",
      "startTime": "2025-12-08T10:00:00Z",
      "endTime": "2025-12-08T11:00:00Z",
      "recurrence": "FREQ=WEEKLY;INTERVAL=1",
      "instanceCount": 8,          // 总实例数
      "completedCount": 3,         // 已完成实例数
      "pendingCount": 5,           // 待办实例数
      "createdAt": "2025-12-01T08:00:00Z",
      "updatedAt": "2025-12-01T08:00:00Z"
    },
    {
      "id": "template-uuid-2",
      "title": "每日晨会",
      "startTime": "2025-12-01T09:00:00Z",
      "recurrence": "FREQ=DAILY;INTERVAL=1;UNTIL=20251231T000000Z",
      "instanceCount": 15,
      "completedCount": 10,
      "pendingCount": 5
    }
  ]
}
```

**说明：**
- 返回当前用户所有的重复日程模板
- 每个模板包含统计信息：
  - `instanceCount`：该系列总共生成的实例数量
  - `completedCount`：已完成的实例数量（status='completed'）
  - `pendingCount`：待办的实例数量（status='pending'）
- 可用于：
  - 展示"我的重复日程"列表
  - 统计重复任务的完成率
  - 提供"管理系列"入口（如批量删除、暂停等）

**前端展示建议：**
- 在日程管理页面添加"重复系列"标签页
- 显示每个系列的标题、重复规则、完成进度
- 提供"查看详情"、"停止生成"、"删除系列"等操作

---

---

### 9. 获取用户提醒列表（包含关联日程）

**接口：** `GET /api/schedules/reminders`

**查询参数：**
```
status=pending  # 可选：pending(未提醒)/sent(已提醒)/all(全部，默认)
limit=100       # 可选：返回数量限制，默认 100
```

**响应示例：**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "total": 5,
    "reminders": [
      {
        "id": "reminder-1",
        "scheduleId": "instance-1",
        "remindAt": "2025-12-08T09:45:00Z",
        "reminded": false,
        "schedule": {
          "id": "instance-1",
          "title": "每周团队会议",
          "startTime": "2025-12-08T10:00:00Z",
          "endTime": "2025-12-08T11:00:00Z",
          "location": "会议室A",
          "remindBefore": 15,
          "parentId": "template-uuid",
          "iterationIndex": 1,
          "recurrence": "FREQ=WEEKLY;INTERVAL=1"
        }
      }
    ]
  }
}
```

**说明：**
- 提醒列表会自动包含关联的日程（`schedule` 字段）
- 可以直接读取 `schedule.title`、`schedule.startTime` 等字段

---

## 前端开发建议

### 1. UI 展示

**日程列表页：**
- 识别 `parentId` 字段，对重复日程显示"重复"图标
- 可在标题旁显示"第 X 次"（基于 `iterationIndex`）
- 解析 `recurrence` 字段，展示为"每天"、"每周"、"每月"等

**日程详情页：**
- 显示"重复规则"字段
- 提供"只修改这一次"和"修改整个系列"选项（暂时只支持前者）

**创建/编辑页：**
- 添加"重复"开关
- 展开后提供：
  - 频率选择：每天/每周/每月
  - 间隔输入：每 X 天/周/月
  - 截止条件：永不结束 / 结束于某日期

### 2. Recurrence 对象生成辅助

前端可以根据用户选择生成 recurrence 对象：

**示例代码（JavaScript）：**
```javascript
function generateRecurrence(frequency, interval = 1, options = {}) {
  const recurrence = {
    frequency: frequency.toUpperCase(),
    interval: interval
  };
  
  // 添加 by_day（仅对 WEEKLY 有效）
  if (options.byDay && Array.isArray(options.byDay)) {
    recurrence.by_day = options.byDay;
  }
  
  // 添加 until（截止日期）
  if (options.until) {
    recurrence.until = new Date(options.until).toISOString();
  }
  
  // 添加 count（重复次数）
  if (options.count) {
    recurrence.count = parseInt(options.count);
  }
  
  return recurrence;
}

// 使用示例 1：每周一、三、五
const recurrence1 = generateRecurrence('WEEKLY', 1, {
  byDay: ['MO', 'WE', 'FR']
});
// 输出: { frequency: "WEEKLY", interval: 1, by_day: ["MO", "WE", "FR"] }

// 使用示例 2：每 2 周，截止到 2026-01-01
const recurrence2 = generateRecurrence('WEEKLY', 2, {
  until: '2026-01-01'
});
// 输出: { frequency: "WEEKLY", interval: 2, until: "2026-01-01T00:00:00.000Z" }

// 使用示例 3：每天，重复 30 次
const recurrence3 = generateRecurrence('DAILY', 1, {
  count: 30
});
// 输出: { frequency: "DAILY", interval: 1, count: 30 }
```

### 3. Recurrence 对象解析展示

**示例代码：**
```javascript
function parseRecurrenceToText(recurrence) {
  if (!recurrence || !recurrence.frequency) {
    return '不重复';
  }
  
  const freqMap = {
    'DAILY': '每天',
    'WEEKLY': '每周',
    'MONTHLY': '每月',
    'YEARLY': '每年'
  };
  
  let text = freqMap[recurrence.frequency] || recurrence.frequency;
  
  if (recurrence.interval && recurrence.interval > 1) {
    const unitMap = {
      'DAILY': '天',
      'WEEKLY': '周',
      'MONTHLY': '月',
      'YEARLY': '年'
    };
    text = `每 ${recurrence.interval} ${unitMap[recurrence.frequency] || '次'}`;
  }
  
  // 添加周几信息
  if (recurrence.by_day && recurrence.by_day.length > 0) {
    const dayMap = {
      'SU': '周日', 'MO': '周一', 'TU': '周二', 'WE': '周三',
      'TH': '周四', 'FR': '周五', 'SA': '周六'
    };
    const days = recurrence.by_day.map(d => dayMap[d] || d).join('、');
    text += `（${days}）`;
  }
  
  // 添加截止条件
  if (recurrence.until) {
    const date = new Date(recurrence.until).toLocaleDateString('zh-CN');
    text += `，截止到 ${date}`;
  } else if (recurrence.count) {
    text += `，共 ${recurrence.count} 次`;
  }
  
  return text;
}

// 使用示例
const text1 = parseRecurrenceToText({
  frequency: 'WEEKLY',
  interval: 1,
  by_day: ['MO', 'WE', 'FR']
});
// 输出: "每周（周一、周三、周五）"

const text2 = parseRecurrenceToText({
  frequency: 'MONTHLY',
  interval: 2,
  count: 6
});
// 输出: "每 2 月，共 6 次"
```

### 4. 系列任务的统计

**示例：查询某系列的完成情况**
```javascript
// 假设已获取日程列表
const schedules = [...]; // 从 API 获取

// 按 parentId 分组
const seriesMap = schedules.reduce((acc, schedule) => {
  if (schedule.parentId) {
    if (!acc[schedule.parentId]) {
      acc[schedule.parentId] = [];
    }
    acc[schedule.parentId].push(schedule);
  }
  return acc;
}, {});

// 统计某个系列的完成率
function getSeriesCompletionRate(parentId) {
  const instances = seriesMap[parentId] || [];
  const completed = instances.filter(s => s.status === 'completed').length;
  const total = instances.length;
  return total > 0 ? (completed / total * 100).toFixed(1) : 0;
}
```

---

## 后端自动化机制

### 1. 定时任务（每 10 分钟执行）

后端会自动：
1. 扫描所有 `startTime <= 当前时间` 且有 `parentId` 的实例
2. 检查是否已有下一个实例（通过 `parentId + iterationIndex` 唯一约束）
3. 如果没有，根据模板的 RRULE 计算下一次时间
4. 创建新实例（`iterationIndex` 自增）并生成提醒

**注意：**
- 实例不是提前全部生成的，而是滚动生成
- 如果用户删除了某个实例，不影响后续实例的生成
- 如果 RRULE 包含 `UNTIL` 且已到期，将停止生成

### 2. 提醒机制

- 每个实例独立拥有提醒记录
- 提醒时间 = `startTime - remindBefore`（分钟）
- 提醒发送后，`reminded` 字段标记为 `true`

---

## 常见问题 (FAQ)

### Q1: 用户修改了某一次的时间，会影响后续实例吗？
**A:** 不会。每个实例独立存储，修改某一次不影响其他实例。

### Q2: 如何修改整个系列的规则？
**A:** 使用 `PUT /api/schedules/series/{parentId}` 接口修改模板配置。
- 前端传入完整的模板数据（所有字段）
- 已生成的实例不会自动更新
- 新生成的实例将使用新配置

### Q3: 用户能看到模板吗？
**A:** 不能。模板仅后台存储，用户只看到实例。

### Q4: 如何判断某个日程是重复任务的一部分？
**A:** 检查 `parentId` 字段：
- `parentId` 为 `null` → 一次性任务
- `parentId` 有值 → 重复任务的实例

### Q5: 如果删除了第一个实例，后续还会生成吗？
**A:** 会。定时任务基于模板和现有实例计算下一次，删除某个实例不影响生成逻辑。

### Q6: Recurrence 格式不合法会怎样？
**A:** 创建时会返回 400 错误。建议前端进行基础校验：
- `frequency` 必填且只能是 DAILY/WEEKLY/MONTHLY/YEARLY
- `interval` 必须是正整数
- `until` 必须是合法的 RFC3339 格式日期
- `count` 必须是正整数

### Q7: 返回的 recurrence 字段是什么格式？
**A:** 后端存储为 RRULE 字符串（如 `FREQ=WEEKLY;INTERVAL=1`），前端可解析展示或直接显示"重复"标识。

---

## 测试用例

### 测试 1: 创建每天重复的任务
```bash
POST /api/schedules
{
  "title": "每天晨会",
  "startTime": "2025-12-08T09:00:00Z",
  "recurrence": {
    "frequency": "DAILY",
    "interval": 1
  }
}
```
**预期：**
- 返回成功，创建模板 + 第一个实例
- 10 分钟后（定时任务执行），自动生成第二个实例（2025-12-09T09:00:00Z）

### 测试 2: 创建每周一、三、五重复的任务
```bash
POST /api/schedules
{
  "title": "健身打卡",
  "startTime": "2025-12-08T18:00:00Z",
  "recurrence": {
    "frequency": "WEEKLY",
    "interval": 1,
    "by_day": ["MO", "WE", "FR"]
  }
}
```
**预期：**
- 第一个实例：2025-12-08（周一）
- 后续自动生成周三、周五的实例

### 测试 3: 创建带截止日期的任务
```bash
POST /api/schedules
{
  "title": "项目冲刺每日站会",
  "startTime": "2025-12-08T10:00:00Z",
  "recurrence": {
    "frequency": "DAILY",
    "interval": 1,
    "until": "2025-12-31T00:00:00Z"
  }
}
```
**预期：**
- 生成到 2025-12-31 后停止

### 测试 4: 创建重复 10 次的任务
```bash
POST /api/schedules
{
  "title": "新员工培训",
  "startTime": "2025-12-08T14:00:00Z",
  "recurrence": {
    "frequency": "WEEKLY",
    "interval": 1,
    "count": 10
  }
}
```
**预期：**
- 共生成 10 个实例后停止

### 测试 5: 删除重复系列（保留所有实例）
```bash
DELETE /api/schedules/series/template-uuid
```
**预期：**
- 模板被软删除
- 所有实例保留
- 定时任务不再生成新实例

### 测试 6: 删除重复系列（删除未来实例）
```bash
DELETE /api/schedules/series/template-uuid?deleteInstances=future
```
**预期：**
- 模板被软删除
- 所有待办（pending）实例被软删除
- 已完成（completed）实例保留
- 返回 deletedInstances 和 retainedInstances 数量

### 测试 7: 获取所有模板
```bash
GET /api/schedules/templates
```
**预期：**
- 返回当前用户所有重复日程模板
- 每个模板包含 instanceCount、completedCount、pendingCount 统计信息

---

## 版本历史

- **v1.2** (2025-12-07)
  - 新增修改系列 API：PUT /api/schedules/series/:parentId（修改模板配置，不影响已生成实例）

- **v1.1** (2025-12-07)
  - 新增删除系列 API：DELETE /api/schedules/series/:parentId（支持 3 种删除策略）
  - 新增查询模板 API：GET /api/schedules/templates（包含实例统计）
  - 优化定时任务：跳过已删除的模板

- **v1.0** (2025-12-06)
  - 支持 FREQ=DAILY/WEEKLY/MONTHLY
  - 支持 INTERVAL 和 UNTIL
  - 懒生成机制
  - 模板-实例分离架构
  - 前端传入 JSON 格式，后端存储为 RRULE 字符串

---

## 联系方式

如有问题或需要新功能支持，请联系后端团队。
