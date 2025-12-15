# 日常（Daily Tasks）API 前端集成指南

## 📌 概述

日常功能用于帮助用户建立和追踪每日习惯。每条日常任务可以在每天标记为"完成"或"未完成"，系统会自动记录打卡历史和统计完成率。

---

## 🔑 核心概念

### DailyTask（日常任务）
- `id`: 任务唯一标识
- `title`: 任务名称（如"晨跑"、"写日志"）
- `description`: 任务描述（可选）
- `startTime`: 推荐执行时刻，传 RFC3339（包含时区），后端会归一到 `1970-01-01` 保留时分秒（按 UTC 存储）
- `status`: 任务状态，`active` 或 `paused`
- `category`: 分类标签（可选，如"健康"、"工作"）
- `color`: 颜色代码（可选，用于 UI 展示）
- `createdAt`: 创建时间
- `updatedAt`: 更新时间

### DailyTaskLog（打卡记录）
- `id`: 记录唯一标识
- `taskId`: 关联的日常任务 ID
- `date`: 打卡日期（YYYY-MM-DD，不含时间）
- `completed`: 该天是否完成（true/false）
- `note`: 可选备注
- `createdAt`: 记录创建时间

---

## 🚀 API 端点

### 1. 创建日常任务
```
POST /api/daily-tasks
```

**请求头**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**请求体**
```json
{
  "title": "晨跑",
  "description": "每天清晨 6 点跑 5 km",
  "startTime": "1970-01-01T06:00:00+08:00",
  "category": "健康",
  "color": "#FF6B6B"
}
```

> 也可以不传任何字段：后端会生成一个空白日常（只包含 id、userId、status=active），随后用 PUT 补充内容。

**响应（201 Created）**
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "晨跑",
    "description": "每天清晨 6 点跑 5 km",
    "startTime": "1970-01-01T06:00:00Z",
    "status": "active",
    "category": "健康",
    "color": "#FF6B6B",
    "userId": "user123",
    "createdAt": "2025-12-14T10:00:00Z",
    "updatedAt": "2025-12-14T10:00:00Z"
  }
}
```

---

### 2. 获取日常任务列表
```
GET /api/daily-tasks?status=active
```

**查询参数**
- `status` (可选): `active` 或 `paused`，默认返回所有

**响应（200 OK）**
```json
{
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "title": "晨跑",
      "description": "每天清晨 6 点跑 5 km",
      "startTime": "1970-01-01T06:00:00Z",
      "status": "active",
      "category": "健康",
      "color": "#FF6B6B",
      "userId": "user123",
      "createdAt": "2025-12-14T10:00:00Z",
      "updatedAt": "2025-12-14T10:00:00Z"
    },
    {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "title": "喝水 8 杯",
      "startTime": "1970-01-01T09:00:00Z",
      "status": "active",
      "category": "健康",
      "createdAt": "2025-12-14T11:00:00Z",
      "updatedAt": "2025-12-14T11:00:00Z"
    }
  ]
}
```

---

### 3. 获取单个日常任务详情
```
GET /api/daily-tasks/{taskId}
```

**路径参数**
- `taskId`: 日常任务 ID

**响应（200 OK）**
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "晨跑",
    "description": "每天清晨 6 点跑 5 km",
    "startTime": "1970-01-01T06:00:00Z",
    "status": "active",
    "category": "健康",
    "color": "#FF6B6B",
    "userId": "user123",
    "createdAt": "2025-12-14T10:00:00Z",
    "updatedAt": "2025-12-14T10:00:00Z"
  }
}
```

---

### 4. 更新日常任务
```
PUT /api/daily-tasks/{taskId}
```

**请求体**（所有字段可选，仅更新提供的字段）
```json
{
  "title": "晨跑 + 冥想",
  "description": "6 点跑步，7 点冥想",
  "startTime": "1970-01-01T06:30:00+08:00",
  "category": "健康",
  "color": "#4ECDC4"
}
```

**响应（200 OK）**
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "晨跑 + 冥想",
    "description": "6 点跑步，7 点冥想",
    "startTime": "1970-01-01T06:30:00Z",
    "status": "active",
    "category": "健康",
    "color": "#4ECDC4",
    "userId": "user123",
    "updatedAt": "2025-12-14T12:00:00Z"
  }
}
```

---

### 5. 切换日常任务状态
```
PATCH /api/daily-tasks/{taskId}/status
```

**请求体**
```json
{
  "status": "paused"
}
```

**允许值**
- `active`: 激活（恢复追踪）
- `paused`: 暂停（保留历史，不删除）

**响应（200 OK）**
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "晨跑",
    "status": "paused",
    "updatedAt": "2025-12-14T12:30:00Z"
  }
}
```

---

### 6. 删除日常任务
```
DELETE /api/daily-tasks/{taskId}
 - `todayCompleted`: 今日是否已完成（派生字段，列表接口直接返回）
> **注意**：删除操作为软删除，任务不会立即从数据库删除，但前端查询时不会返回。

---

### 7. 打卡（标记今天完成情况）
```
POST /api/daily-tasks/{taskId}/log
```

**请求体**
```json
{
  "completed": true,
  "note": "跑了 5.5 km，感觉不错"
}
```

**参数说明**
- `completed` (必需): 布尔值，是否完成
- `note` (可选): 备注信息

**响应（200 OK）**
```json
{
  "data": {
    "id": "log-uuid-here",
    "taskId": "550e8400-e29b-41d4-a716-446655440000",
    "userId": "user123",
    "date": "2025-12-14",
    "completed": true,
    "note": "跑了 5.5 km，感觉不错",
    "createdAt": "2025-12-14T18:30:00Z"
  }
}
```

> **特殊逻辑**：
> - 若该天已有记录，则更新；若无，则创建。
> - 一个任务在一天内只能有一条记录。

---

### 8. 获取打卡记录
```
GET /api/daily-tasks/{taskId}/logs?days=30
```

**查询参数**
- `days` (可选): 获取过去多少天的记录，默认 30 天

**响应（200 OK）**
```json
{
  "data": [
    {
      "id": "log-uuid-1",
      "taskId": "550e8400-e29b-41d4-a716-446655440000",
      "userId": "user123",
      "date": "2025-12-14",
      "completed": true,
      "note": "跑了 5.5 km",
### 7.1 取消今日打卡（软删除）
```
DELETE /api/daily-tasks/{taskId}/log/today
```

**响应（200 OK）**
```json
{
  "message": "Today log cancelled"
}
```

> 若今天尚无打卡记录，接口返回错误；已存在时执行软删除。
      "createdAt": "2025-12-14T18:30:00Z"
    },
### 用户时区配置
在用户配置中新增：
- `config.timezone`: IANA 时区（推荐，如 `Asia/Shanghai`）
- `config.utcOffsetMinutes`: 时区偏移（分钟，兜底）

列表接口会按用户时区计算本地零点对应的 UTC 范围，直接返回 `todayCompleted`，前端无需逐个请求日志。
    {
      "id": "log-uuid-2",
      "taskId": "550e8400-e29b-41d4-a716-446655440000",
      "userId": "user123",
      "date": "2025-12-13",
      "completed": false,
      "note": "下雨了，改天再跑",
      "createdAt": "2025-12-13T20:00:00Z"
    }
  ]
}
```

---

### 9. 获取统计信息
```
GET /api/daily-tasks/{taskId}/stats
```

**响应（200 OK）**
```json
{
  "data": {
    "taskId": "550e8400-e29b-41d4-a716-446655440000",
    "title": "晨跑",
    "monthTotal": 20,
    "monthCompleted": 16,
    "completionRate": 80,
    "consecutiveDays": 3
  }
}
```

**字段说明**
- `monthTotal`: 本月总有记录的天数
- `monthCompleted`: 本月完成的天数
- `completionRate`: 完成率（百分比）
- `consecutiveDays`: 从今天往前连续完成的天数

---

## 💡 前端实现示例

### Vue 3 示例

#### 1. 创建日常任务
```javascript
async function createDailyTask() {
  const response = await fetch('/api/daily-tasks', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      title: '晨跑',
      description: '每天早上 6 点跑 5 km',
      startTime: new Date('1970-01-01T06:00:00Z').toISOString(),
      category: '健康',
      color: '#FF6B6B'
    })
  });
  
  const { data } = await response.json();
  console.log('创建成功:', data);
}
```

#### 2. 获取日常任务列表
```javascript
const dailyTasks = ref([]);

async function fetchDailyTasks() {
  const response = await fetch('/api/daily-tasks?status=active', {
    headers: { 'Authorization': `Bearer ${accessToken}` }
  });
  
  const result = await response.json();
  dailyTasks.value = result.data;
}
```

#### 3. 打卡
```javascript
async function completeTask(taskId, completed = true, note = '') {
  const response = await fetch(`/api/daily-tasks/${taskId}/log`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      completed,
      note
    })
  });
  
  const { data } = await response.json();
  console.log('打卡成功:', data);
}
```

#### 4. 获取统计
```javascript
async function getStats(taskId) {
  const response = await fetch(`/api/daily-tasks/${taskId}/stats`, {
    headers: { 'Authorization': `Bearer ${accessToken}` }
  });
  
  const { data } = await response.json();
  console.log(`完成率: ${data.completionRate}%`);
  console.log(`连续天数: ${data.consecutiveDays} 天`);
}
```

---

## 🎨 前端页面建议设计

### 日常列表页面
```
┌────────────────────────────────────┐
│ 📅 我的日常 (3 个活跃)              │
├────────────────────────────────────┤
│ ┌──────────────────────────────┐  │
│ │ [×] 晨跑                      │  │
│ │     完成率 80% | 连续 3 天    │  │
│ │     06:00 开始               │  │
│ └──────────────────────────────┘  │
│                                    │
│ ┌──────────────────────────────┐  │
│ │ [√] 喝水 8 杯                │  │
│ │     完成率 95% | 连续 12 天   │  │
│ │     09:00 开始               │  │
│ └──────────────────────────────┘  │
│                                    │
│ ┌──────────────────────────────┐  │
│ │ [×] 写日志                    │  │
│ │     完成率 60% | 连续 0 天    │  │
│ │     21:00 开始               │  │
│ └──────────────────────────────┘  │
│                                    │
│ [+ 新增日常]                       │
└────────────────────────────────────┘
```

### 单个日常详情页
```
┌────────────────────────────────┐
│ 晨跑 🏃                         │
├────────────────────────────────┤
│ 描述：每天清晨 6 点跑 5 km    │
│ 分类：健康                     │
│ 推荐时间：06:00                │
├────────────────────────────────┤
│ 📊 本月统计                    │
│ 完成：20 天 / 28 天 (71%)     │
│ 连续：3 天                     │
├────────────────────────────────┤
│ 📋 打卡日历（最近 7 天）       │
│ [√] [√] [ ] [√] [ ] [√] [√]   │
│  14   13  12  11  10   9   8   │
├────────────────────────────────┤
│ [标记为完成] [编辑] [暂停]     │
└────────────────────────────────┘
```

---

## ⚠️ 错误处理

### 常见错误码
```json
{
  "code": "INVALID_INPUT",
  "message": "title 不能为空",
  "details": "..."
}
```

其他可能错误：
- `RESOURCE_NOT_FOUND`: 任务不存在
- `INVALID_INPUT`: 参数格式错误
- `UNAUTHORIZED`: 未认证（无效 token）
- `DATABASE_ERROR`: 服务器数据库错误

### 前端错误处理示例
```javascript
async function fetchWithErrorHandling(url, options) {
  try {
    const response = await fetch(url, options);
    if (!response.ok) {
      const error = await response.json();
      console.error(`错误 [${error.code}]: ${error.message}`);
      return null;
    }
    return await response.json();
  } catch (err) {
    console.error('网络错误:', err);
    return null;
  }
}
```

---

## 🔐 认证与授权

所有日常相关接口均需要有效的 JWT `access_token`，在请求头中传递：
```
Authorization: Bearer <access_token>
```

获取 token 方式：
```bash
POST /api/login
{
  "email": "user@example.com",
  "password": "password123"
}
```

响应包含 `access_token` 和 `refresh_token`。

---

## 📝 数据格式说明

### startTime 字段
- 存储格式：`1970-01-01THH:mm:ssZ`（只取时分秒，日期恒定为 1970-01-01）
- 示例：`1970-01-01T06:00:00Z` 表示每天早上 6 点
- 前端交互：
  ```javascript
  // 设置为早上 6 点
  const startTime = new Date('1970-01-01T06:00:00Z');
  
  // 或从用户选择的时间构造
  const userTime = new Date();
  userTime.setHours(6, 0, 0);
  const normalized = new Date('1970-01-01');
  normalized.setHours(userTime.getHours(), userTime.getMinutes(), userTime.getSeconds());
  ```

### date 字段（打卡记录）
- 格式：`YYYY-MM-DD`（仅日期，不含时间）
- 示例：`2025-12-14`
- 后端自动使用当前 UTC 日期

---

## 📞 常见问题

**Q: 打卡记录如何修改？**
A: 对同一任务同一天再次调用 POST `/daily-tasks/:id/log`，系统会自动更新而非创建新记录。

**Q: 删除日常任务后，打卡历史会丢失吗？**
A: 不会。删除为软删除，历史记录仍保存在数据库；如需恢复，后端可提供恢复接口。

**Q: 暂停和删除的区别？**
A: 暂停（status=paused）保留任务和历史；删除为软删除（DeletedAt 标记）。暂停的任务可随时激活。

**Q: startTime 字段是必需的吗？**
A: 不是。创建时可不填，系统默认为 nil；前端可选择性显示提醒时间功能。

**Q: 能否在手机端和 PC 端共享打卡数据？**
A: 可以。所有数据基于用户 ID 存储，同一用户在不同端登录后可共享历史和统计数据。

---

## 🔄 集成时间线

- **第一周**：实现基本 CRUD 和打卡功能，前端简单列表展示
- **第二周**：添加统计图表、打卡日历视图
- **第三周**：推送提醒集成（企业微信 / 邮件）
- **第四周**：排行榜、分享、徽章等激励功能

---

**API 文档版本**：v1.0  
**最后更新**：2025-12-14  
**维护者**：Backend Team
