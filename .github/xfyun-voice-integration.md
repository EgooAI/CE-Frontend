# 科大讯飞语音识别集成指南（大模型版）

## 概述

本项目使用**平台差异化策略**实现跨平台语音识别：

- **iOS**: 使用 `speech_to_text` 插件（苹果原生语音识别）
- **Android**: 使用科大讯飞 WebSocket **实时语音转写大模型版** API
  - 支持中英 + 202种方言混合识别
  - 基于星火大模型预训练技术
  - 更高的识别准确率
- **Web**: ⚠️ 暂不支持语音识别
  - `record` 插件在 Web 平台支持有限
  - 未来可能使用 Web Audio API 实现

## 架构设计

### 核心文件

1. **`lib/services/xfyun_asr_service.dart`** - 科大讯飞 WebSocket 客户端
2. **`lib/services/audio_recorder_service.dart`** - 音频录制服务（封装 `record` 插件）
3. **`lib/pages/chat_page.dart`** - 集成语音输入的聊天页面

### 依赖包

```yaml
dependencies:
  # iOS 语音识别
  speech_to_text: ^7.3.0
  
  # 科大讯飞 WebSocket 实时语音识别（Android + Web）
  web_socket_channel: ^3.0.1
  
  # 音频录制（Android + iOS）
  record: ^5.1.2
  
  # 加密库（用于科大讯飞 API 签名）
  crypto: ^3.0.5
```

## 科大讯飞 API 配置

### 1. 申请 API 凭证

访问 [科大讯飞开放平台](https://console.xfyun.cn/)：

1. 注册/登录账号
2. 创建应用（选择"**实时语音转写大模型版**"服务）
3. 获取以下凭证：
   - **APPID**（应用ID）
   - **accessKeyId**（访问密钥ID）
   - **accessKeySecret**（访问密钥密文）

⚠️ **注意**: 大模型版使用的是 `accessKeyId` 和 `accessKeySecret`，不同于标准版的 `apiKey` 和 `apiSecret`

### 2. 配置凭证

本项目使用 `--dart-define` 方式管理 API 凭证，**不会将敏感信息硬编码到代码中**。

#### 方法 1：使用脚本（推荐）

1. **创建 `.env` 文件**（从模板复制）：
   ```powershell
   Copy-Item .env.example .env
   ```

2. **编辑 `.env` 文件**，填入真实凭证：
   ```env
   XFYUN_APP_ID=你的AppID
   XFYUN_ACCESS_KEY_ID=你的AccessKeyId
   XFYUN_ACCESS_KEY_SECRET=你的AccessKeySecret
   ```

3. **使用脚本运行/编译**：
   ```powershell
   # 运行应用
   .\run.ps1
   
   # 指定设备运行
   .\run.ps1 -Device chrome
   
   # 编译 APK
   .\build.ps1 -Platform apk
   
   # 编译 Web
   .\build.ps1 -Platform web
   ```

#### 方法 2：手动传递参数

直接在命令行使用 `--dart-define`：

```powershell
flutter run `
  --dart-define=XFYUN_APP_ID=你的AppID `
  --dart-define=XFYUN_ACCESS_KEY_ID=你的AccessKeyId `
  --dart-define=XFYUN_ACCESS_KEY_SECRET=你的AccessKeySecret
```

编译时同样传递参数：

```powershell
flutter build apk `
  --dart-define=XFYUN_APP_ID=你的AppID `
  --dart-define=XFYUN_ACCESS_KEY_ID=你的AccessKeyId `
  --dart-define=XFYUN_ACCESS_KEY_SECRET=你的AccessKeySecret
```

⚠️ **安全提示**: 
- `.env` 文件已添加到 `.gitignore`，不会被提交到 Git
- 使用 `String.fromEnvironment()` 在编译时读取配置
- 不要将真实凭证硬编码到代码中

## 技术细节

### 音频格式要求

科大讯飞实时语音转写大模型版 API 要求音频格式：

- **采样率**: 16kHz
- **位深度**: 16bit
- **声道**: 单声道（Mono）
- **编码**: PCM Raw（`pcm_s16le`）
- **发送频率**: 建议每 40ms 发送 1280 字节

`AudioRecorderService` 已自动配置为符合这些要求。

### WebSocket 通信流程

1. **鉴权**: 使用 HMAC-SHA1 签名生成 WebSocket 连接 URL
   - 参数按字母顺序排序
   - 使用 `accessKeySecret` 进行 HMAC-SHA1 加密
   - Base64 编码生成 signature
2. **连接**: 建立 WebSocket 连接到大模型版端点
   - `wss://office-api-ast-dx.iflyaisol.com/ast/communicate/v1`
3. **音频发送**: 直接发送二进制 PCM 音频数据（不需要 Base64 编码）
4. **结果接收**: 解析 JSON 格式的识别结果
   - 支持中间结果（type=1）和确定性结果（type=0）
   - 支持 202 种方言自动识别
5. **断开**: 发送包含 sessionId 的结束标识并关闭连接

### 平台检测逻辑

```dart
if (kIsWeb || Platform.isAndroid) {
  // 使用科大讯飞 WebSocket API
  _xunfeiAsr = XunfeiAsrService(...);
  _audioRecorder = AudioRecorderService(...);
} else if (Platform.isIOS) {
  // 使用 speech_to_text 插件
  _speechToText = stt.SpeechToText();
}
```

## UI 设计

### 输入框交互

- **麦克风按钮**: 位于输入框右侧（suffixIcon）
- **图标状态**:
  - 未监听: `Icons.mic_none` (灰色)
  - 监听中: `Icons.mic` (红色)
- **提示文本**: 
  - 未监听: "输入消息..."
  - 监听中: "监听中..." (蓝色)
- **实时显示**: 识别结果实时显示在输入框中
- **手动发送**: 用户点击发送按钮提交消息

## 权限配置

### Android

已在 `android/app/src/main/AndroidManifest.xml` 中添加：

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS

需要在 `ios/Runner/Info.plist` 中添加麦克风权限说明：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限以使用语音输入功能</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>需要语音识别权限以将语音转换为文字</string>
```

### Web

浏览器会自动请求麦克风权限，需要用户授权。

## 测试检查清单

### iOS 测试

- [ ] 麦克风权限请求正常弹出
- [ ] 语音识别准确率符合预期（中文）
- [ ] 实时识别结果正常显示
- [ ] 停止识别后可以正常发送消息

### Android 测试

- [ ] 麦克风权限请求正常弹出
- [ ] WebSocket 连接成功
- [ ] 音频录制启动正常
- [ ] 实时识别结果正常显示
- [ ] 识别准确率符合预期
- [ ] 网络错误处理正常

### Web 测试

⚠️ **Web 平台暂不支持语音识别**

原因：`record` 插件在 Web 平台的 `startStream` 方法不可用，导致无法实时捕获音频流。

未来改进方案：
- [ ] 使用 Web Audio API 直接捕获音频
- [ ] 实现 Web 专用的音频录制服务
- [ ] 或等待 `record` 插件完善 Web 支持

## 常见问题

### Q1: Web 平台无法录音

**原因**: 浏览器要求 HTTPS 才能使用麦克风。

**解决**: 
- 本地测试使用 `localhost` 或 `127.0.0.1`
- 生产环境部署到 HTTPS 域名

### Q2: Android 识别不准确

**原因**: 环境噪音或音频质量问题。

**解决**:
- 检查麦克风权限
- 调整录音参数（bitRate、sampleRate）
- 测试不同环境下的识别效果

### Q3: iOS 识别延迟高

**原因**: `speech_to_text` 依赖网络连接（Apple 服务器）。

**解决**:
- 确保网络连接良好
- 调整 `pauseFor` 参数减少延迟
- 考虑使用离线模型（需额外配置）

### Q4: 科大讯飞 API 配额用尽

**原因**: 免费套餐有调用次数限制。

**解决**:
- 查看控制台配额使用情况
- 升级到付费套餐
- 优化音频发送频率

## 优化建议

1. **错误重试**: 添加 WebSocket 断线重连机制
2. **音频缓存**: 实现音频数据缓冲，减少网络请求
3. **离线支持**: iOS 可配置离线模型，Android 可集成 Vosk
4. **降噪处理**: 添加音频预处理降噪算法
5. **配额管理**: 监控 API 调用次数，避免超出配额
6. **多语言支持**: 根据用户设置切换识别语言

## 参考资料

- [科大讯飞实时语音转写大模型版 API 文档](https://www.xfyun.cn/doc/spark/asr_llm/rtasr_llm.html)
- [科大讯飞控制台](https://console.xfyun.cn/)
- [speech_to_text 插件文档](https://pub.dev/packages/speech_to_text)
- [record 插件文档](https://pub.dev/packages/record)
- [Web Audio API 规范](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)

---

**文档版本**: v1.0  
**创建日期**: 2025-12-10  
**最后更新**: 2025-12-10
