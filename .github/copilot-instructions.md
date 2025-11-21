# GitHub Copilot 项目指导文档

## 项目概述

**项目名称：** CE-Frontend  
**技术栈：** Flutter + Dart  
**后端 API：** `http://10.0.2.2:8080/api`  
**项目类型：** 跨平台移动应用（Android/iOS）

---

## 代码规范

### Dart/Flutter 规范

- 使用 `const` 构造函数优化性能
- 遵循 Effective Dart 命名规范
- 使用 `null safety`，明确可空类型
- Widget 命名使用 `PascalCase`，文件名使用 `snake_case`
- 私有成员使用下划线前缀 `_`

### 文件组织

```
lib/
  ├── main.dart              # 应用入口
  ├── models/                # 数据模型
  │   ├── user.dart
  │   ├── schedule.dart
  │   └── conversation.dart
  ├── pages/                 # 页面组件
  │   ├── calendar_page.dart
  │   ├── chat_page.dart
  │   ├── task_page.dart
  │   └── profile_page.dart
  ├── services/              # API 服务层
  │   ├── api_client.dart
  │   ├── auth_service.dart
  │   └── schedule_service.dart
  └── widgets/               # 可复用组件
      └── schedule_card.dart
```

### API 调用规范

- 所有 API 调用通过 `ApiClient` 统一管理
- 使用 Dio 作为 HTTP 客户端
- 错误处理使用 `try-catch` 包裹 `DioException`
- Token 管理通过 `SharedPreferences` 持久化

---

## 当前项目状态

### 已完成功能

- ✅ 用户登录/注册
- ✅ JWT Token 认证
- ✅ 个人主页（含邮箱修改）
- ✅ 聊天页面（基础）
- ✅ 任务页面（占位）
- ✅ **日历页面（完整实现）**
  - 月视图日历
  - 日程列表展示
  - 红点标记未完成日程
  - 可展开/折叠的日程卡片
- ✅ 路由导航系统

### 核心数据模型

#### User 模型

```dart
class User {
  final String id;
  final String email;              // 注册邮箱
  final String username;
  final DateTime? createdAt;
  final String? notificationEmail; // 暂不使用
}
```

#### AuthResponse 模型

```dart
class AuthResponse {
  final String token;
  final User user;
}
```

#### Schedule 模型

```dart
class Schedule {
  final String id;
  final String userId;
  final String title;              // 日程标题
  final String? description;       // 描述（可选）
  final DateTime startTime;        // 开始时间
  final DateTime endTime;          // 结束时间
  final bool isAllDay;            // 是否全天
  final String status;            // pending/in_progress/completed/cancelled
  final String? priority;         // low/medium/high（可选）
  final String? type;             // meeting/task/event/reminder（可选）
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

---

## 待开发功能需求

### 📧 邮箱修改功能（已完成 - Phase 1）

#### 需求说明

在个人主页添加"修改邮箱"功能，用户可以修改其登录邮箱。

#### 设计决策

- **简化方案**：暂时不考虑 `notificationEmail` 字段
- **直接修改**：用户修改的就是登录邮箱 `email` 字段
- **页面设计**：点击编辑按钮 → 进入邮箱编辑页面 → 修改并保存

#### UI 设计

**ProfilePage（个人主页）改进：**

```
┌────────────────────────────────────┐
│  个人主页                    [登出] │
├────────────────────────────────────┤
│        [头像]                       │
│                                     │
│       用户名                        │
│                                     │
│  📧 邮箱                            │
│     user@example.com       [编辑]  │
│                                     │
│  🕐 注册时间：2025-01-01           │
└────────────────────────────────────┘
```

**EditEmailPage（邮箱编辑页面 - 新建）：**

```
┌────────────────────────────────────┐
│  ← 修改邮箱                  [保存] │
├────────────────────────────────────┤
│                                     │
│  当前邮箱                          │
│  user@example.com                  │
│  ───────────────────────────────   │
│                                     │
│  新邮箱                            │
│  ┌─────────────────────────────┐  │
│  │ newemail@example.com        │  │
│  └─────────────────────────────┘  │
│                                     │
│  确认新邮箱                        │
│  ┌─────────────────────────────┐  │
│  │ newemail@example.com        │  │
│  └─────────────────────────────┘  │
│                                     │
│  📧 邮箱验证码                     │
│  ┌──────────────┐ [发送验证码]    │
│  │ 123456       │                  │
│  └──────────────┘                  │
│  ⏱️ 60秒后可重新发送              │
│                                     │
│  💡 提示：                          │
│  • 邮箱将用于登录和接收通知        │
│  • 请确保邮箱地址正确              │
│  • 验证码已发送到新邮箱            │
│  • 修改后需使用新邮箱重新登录      │
│                                     │
└────────────────────────────────────┘
```

**方案 B：简化版（邮件功能未完成前）：**

```
┌────────────────────────────────────┐
│  ← 修改邮箱                  [保存] │
├────────────────────────────────────┤
│                                     │
│  当前邮箱                          │
│  user@example.com                  │
│  ───────────────────────────────   │
│                                     │
│  新邮箱                            │
│  ┌─────────────────────────────┐  │
│  │ newemail@example.com        │  │
│  └─────────────────────────────┘  │
│                                     │
│  确认新邮箱                        │
│  ┌─────────────────────────────┐  │
│  │ newemail@example.com        │  │
│  └─────────────────────────────┘  │
│                                     │
│  ⚠️ 提示：                          │
│  • 邮箱将用于登录和接收通知        │
│  • 请确保邮箱地址正确              │
│  • 修改后需使用新邮箱重新登录      │
│  • 邮箱验证功能开发中...           │
│                                     │
└────────────────────────────────────┘
```

#### 实现要点

1. **前端验证**

   - 邮箱格式验证（正则表达式）
   - 两次输入一致性验证
   - 不能与当前邮箱相同

2. **后端 API 接口**（已确认）

   - **接口：** `PUT /api/profile`
   - **请求体：**（根据 Swagger 文档 `handlers.updateReq`）
     ```json
     {
       "email": "newemail@example.com",
       "username": "username", // 可选
       "password": "password" // 可选
     }
     ```
   - **响应格式：**
     ```json
     {
       "user": {
         "id": "uuid",
         "username": "username",
         "email": "newemail@example.com",
         "createdAt": "2025-01-01T00:00:00.000Z",
         "updatedAt": "2025-01-21T00:00:00.000Z",
         "notificationEmail": null,
         "conversations": null,
         "schedules": null,
         "notificationLogs": null,
         "webhookConfigs": null
       }
     }
     ```
   - **技术栈：** Go + Gin + GORM
   - **认证：** JWT Bearer Token

3. **状态管理**

   - 使用 `StatefulWidget` 管理表单
   - 使用 `GlobalKey<FormState>` 验证
   - 保存成功后更新本地用户信息

4. **用户体验**
   - 显示加载状态
   - 成功后显示 SnackBar 并返回
   - 错误时显示具体错误信息
   - **修改成功后需要重新登录**（已确认）

#### 需要创建的文件

- `lib/pages/edit_email_page.dart` - 邮箱编辑页面
- `lib/services/user_service.dart` - 用户信息服务（可选，或在 `AuthService` 中扩展）

#### 需要修改的文件

- `lib/pages/profile_page.dart` - 添加编辑按钮和导航
- `lib/main.dart` - 添加路由配置
- `lib/services/auth_service.dart` - 添加更新邮箱方法（如果不创建新服务）

#### 邮箱验证规则

```dart
// 邮箱格式验证
RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')

// 验证流程
1. 非空验证
2. 格式验证
3. 两次输入一致性
4. 与当前邮箱不同
```

#### 后端接口确认结果 ✅

- ✅ **API 端点：** `PUT /api/profile`
- ✅ **修改后行为：** 需要重新登录（前端需引导用户退出并重新登录）
- ✅ **邮箱验证：** 需要邮箱验证（发送验证码确认）
- ❌ **频率限制：** 暂不考虑
- ❌ **密码确认：** 不需要输入当前密码
- ⚠️ **邮件发送：** 后端邮件发送接口尚未开发完成，先占位

#### 待实现的功能细节

1. **邮箱验证码功能**（需后端配合）

   - 用户输入新邮箱后，点击"发送验证码"
   - 后端发送 6 位数字验证码到新邮箱
   - 用户输入验证码进行验证
   - 验证通过后才能保存

2. **重新登录流程**
   - 邮箱修改成功后，清除本地 Token
   - 显示提示："邮箱已更新，请使用新邮箱重新登录"
   - 自动跳转到登录页面

#### 需要后端补充的 API（邮箱验证码）

```
POST /api/email/send-code
请求体: { "email": "new@example.com" }
响应: { "success": true, "message": "验证码已发送" }

POST /api/email/verify-code
请求体: { "email": "new@example.com", "code": "123456" }
响应: { "success": true, "token": "verification_token" }
```

---

## 后续功能规划

### 短期计划

1. ✅ 邮箱修改功能（第一阶段完成）
   - ✅ 基础修改功能
   - 🔲 邮箱验证码（等后端邮件接口完成）
2. ✅ 日历页面（已完成）
   - ✅ 月视图日历展示
   - ✅ 日程列表查看
   - ✅ 日程详情展开/折叠
   - 🔲 创建/编辑/删除日程
   - 🔲 日程搜索和筛选
   - 🔲 月份数据懒加载优化
3. 🔲 密码修改功能
4. 🔲 用户名修改功能
5. 🔲 头像上传功能
6. 🔲 完善任务管理功能
7. 🔲 完善聊天功能

### 中期计划

1. 🔲 邮箱通知设置（独立 `notificationEmail` 字段）
2. 🔲 多语言支持
3. 🔲 主题切换（深色模式）
4. 🔲 离线缓存
5. 🔲 推送通知

### 长期计划

1. 🔲 社交功能（好友系统）
2. 🔲 团队协作
3. 🔲 数据统计和可视化
4. 🔲 第三方登录（Google、GitHub）

---

## 技术债务和优化

### 当前需要优化的问题

- ⚠️ Kotlin Gradle 编译错误（偶发）
  - 解决方案：清理缓存、检查 Gradle 配置
  - 临时方案：`flutter clean && flutter pub get`

- ⚠️ 日历页面性能优化
  - 当前实现：一次性加载所有日程
  - 优化方案：按月份懒加载，减少内存占用
  - 优先级：待数据量增大后考虑

### 代码质量

- 需要添加单元测试
- 需要添加集成测试
- 需要完善错误处理机制
- 需要添加日志系统

---

## 环境配置

### 开发环境

- **Flutter SDK:** 最新稳定版
- **Dart SDK:** 跟随 Flutter
- **IDE:** VS Code / Android Studio
- **测试设备:** Android 模拟器 (10.0.2.2 用于本地 API)

### 依赖包

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.x.x # HTTP 客户端
  shared_preferences: ^2.x.x # 本地存储
  table_calendar: ^3.1.2 # 日历组件

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0 # 代码检查
```

### 后端 API 配置

```dart
// lib/services/api_client.dart
static const String _baseUrl = 'http://10.0.2.2:8080/api';
```

---

## 调试技巧

### 常见问题

1. **Android 编译失败**

   ```bash
   flutter clean
   flutter pub get
   cd android && ./gradlew clean && cd ..
   flutter run
   ```

2. **API 连接失败**

   - 检查后端服务是否启动
   - Android 模拟器使用 `10.0.2.2` 访问宿主机
   - iOS 模拟器使用 `localhost` 或 `127.0.0.1`

3. **Token 过期**
   - 检查 JWT 过期时间
   - 实现自动刷新 Token 机制

---

## Git 提交规范

### Commit Message 格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type 类型

- `feat`: 新功能
- `fix`: 修复 Bug
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 重构
- `test`: 测试相关
- `chore`: 构建/工具相关

### 示例

```
feat(profile): 添加邮箱修改功能

- 创建 EditEmailPage 页面
- 添加邮箱格式验证
- 实现邮箱更新 API 调用

Closes #123
```

---

## 安全注意事项

1. **敏感信息**

   - 不要提交 API 密钥到代码库
   - 使用环境变量管理配置
   - Token 存储使用加密

2. **数据验证**

   - 前端验证 + 后端验证
   - 防止 XSS 攻击
   - 防止 SQL 注入（后端）

3. **权限管理**
   - 检查 Token 有效性
   - API 调用失败时清理 Token
   - 敏感操作需要二次确认

---

## 联系方式

- **前端开发者:** [待填写]
- **后端开发者:** [待填写]
- **项目经理:** [待填写]

---

**文档版本:** v1.3  
**创建日期:** 2025-11-21  
**最后更新:** 2025-11-21  
**状态:** 日历页面已完成，等待后端邮件接口

---

## 更新日志

### 2025-11-21 - v1.3

- ✅ **完成日历页面完整实现**
- 创建 Schedule 数据模型（包含所有 Swagger 字段）
- 实现 ScheduleService 服务层（CRUD 操作）
- 创建 ScheduleCard 可展开组件
- 实现 CalendarPage 月视图日历
- 集成 table_calendar ^3.1.2 依赖
- 实现红点标记功能（仅未完成日程）
- 实现状态颜色编码（蓝色=进行中，绿色=已完成，灰色=待办，红色=已取消）
- 支持全天日程显示
- 创建详细设计文档 `.github/calendar-design.md`

### 2025-11-21 - v1.2

- ✅ **完成邮箱修改功能第一阶段开发**
- 更新 User 模型，添加 `updatedAt` 字段
- 扩展 AuthService，添加 `updateEmail` 方法
- 创建 EditEmailPage 邮箱编辑页面
- 修改 ProfilePage 为 StatefulWidget，支持动态更新
- 配置路由，支持参数传递
- 实现完整的表单验证和错误处理

### 2025-11-21 - v1.1

- 确认后端 API 接口：`PUT /api/profile`
- 确认需要邮箱验证码功能
- 确认修改后需重新登录
- 添加简化版 UI 方案（邮件功能未完成前）

### 2025-11-21 - v1.0

- 创建项目指导文档
- 定义邮箱修改功能需求
- 明确技术栈和代码规范
