# CE-Frontend

基于 Flutter 的跨平台移动应用（Android/iOS/Web）

## 功能特性

- ✅ 用户认证（登录/注册）
- ✅ 日程管理（日历视图）
- ✅ AI 聊天助手
- ✅ 语音输入（iOS/Android/Web）
- ✅ 个人资料管理

## 快速开始

### 1. 环境要求

- Flutter SDK 3.10+
- Dart SDK 3.10+
- Android Studio / VS Code
- Xcode（仅 macOS，用于 iOS 开发）

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 配置 API 凭证

#### 科大讯飞语音识别（Android/Web）

1. 复制环境变量模板：
   ```bash
   cp .env.example .env
   ```

2. 编辑 `.env` 文件，填入从 [科大讯飞开放平台](https://console.xfyun.cn/) 获取的凭证（实时语音转写大模型版）：
   ```env
   XFYUN_APP_ID=你的AppID
   XFYUN_ACCESS_KEY_ID=你的AccessKeyId
   XFYUN_ACCESS_KEY_SECRET=你的AccessKeySecret
   ```

3. 使用脚本运行（自动读取 `.env`）：
   ```powershell
   # Windows PowerShell
   .\run.ps1
   
   # 指定设备
   .\run.ps1 -Device chrome
   ```

   或手动传递参数：
   ```bash
   flutter run \
     --dart-define=XFYUN_APP_ID=你的AppID \
     --dart-define=XFYUN_API_KEY=你的APIKey \
     --dart-define=XFYUN_API_SECRET=你的APISecret
   ```

### 4. 运行应用

```bash
# 运行在默认设备
flutter run

# 运行在 Web
flutter run -d chrome

# 运行在 Android
flutter run -d android

# 运行在 iOS
flutter run -d ios
```

### 5. 编译发布版本

使用脚本（推荐）：

```powershell
# Android APK
.\build.ps1 -Platform apk

# Android App Bundle
.\build.ps1 -Platform appbundle

# Web
.\build.ps1 -Platform web

# iOS
.\build.ps1 -Platform ios
```

或手动编译：

```bash
flutter build apk --release \
  --dart-define=XFYUN_APP_ID=你的AppID \
  --dart-define=XFYUN_ACCESS_KEY_ID=你的AccessKeyId \
  --dart-define=XFYUN_ACCESS_KEY_SECRET=你的AccessKeySecret
```

## 项目结构

```
lib/
├── main.dart              # 应用入口
├── models/                # 数据模型
├── pages/                 # 页面组件
├── services/              # API 服务层
│   ├── xfyun_asr_service.dart      # 科大讯飞语音识别
│   ├── audio_recorder_service.dart # 音频录制
│   └── ...
└── widgets/               # 可复用组件
```

## 技术栈

- **框架**: Flutter 3.10+
- **语言**: Dart 3.10+
- **状态管理**: StatefulWidget
- **网络请求**: Dio
- **本地存储**: SharedPreferences
- **语音识别**: 
  - iOS: speech_to_text（苹果原生）
  - Android/Web: 科大讯飞实时语音转写大模型版（支持中英+202种方言）

## 文档

- [科大讯飞语音识别集成指南](.github/xfyun-voice-integration.md)
- [项目开发指导](.github/copilot-instructions.md)

