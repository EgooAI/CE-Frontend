# 原生依赖预埋清单（2026-01-27）

## 背景

由于添加原生依赖（如 image_picker）需要重新发包，无法通过 Shorebird 热更新，因此一次性预埋常用的原生依赖，减少未来发包频率。

## 已预埋依赖

### 📁 文件操作

| 依赖 | 版本 | 用途 | 优先级 |
|-----|------|------|--------|
| **file_picker** | ^8.1.4 | 选择各类文件（PDF/Word/Excel等） | ⭐⭐⭐ 高 |
| **image_picker** | ^1.1.2 | 选择/拍摄图片 | ⭐⭐⭐ 已使用 |
| **image_cropper** | ^9.1.1 | 图片裁剪（头像编辑） | ⭐⭐ 中 |
| **flutter_image_compress** | ^2.3.0 | 图片压缩优化 | ⭐⭐ 中 |

**使用场景：**
- ✅ 聊天发送图片（已实现）
- 🔜 聊天发送文件（PDF、Word等）
- 🔜 头像裁剪编辑
- 🔜 图片压缩上传优化

---

### 🎬 媒体播放

| 依赖 | 版本 | 用途 | 优先级 |
|-----|------|------|--------|
| **video_player** | ^2.9.2 | 视频播放 | ⭐⭐⭐ 高 |
| **just_audio** | ^0.9.42 | 音频播放 | ⭐⭐⭐ 高 |

**使用场景：**
- 🔜 聊天视频消息
- 🔜 语音消息播放（已有录制，缺播放）
- 🔜 视频通话录像回放

---

### ✨ 功能增强

| 依赖 | 版本 | 用途 | 优先级 |
|-----|------|------|--------|
| **share_plus** | ^10.1.2 | 分享到其他应用 | ⭐⭐⭐ 高 |
| **flutter_local_notifications** | ^18.0.1 | 本地通知 | ⭐⭐⭐ 高 |
| **mobile_scanner** | ^6.0.2 | 二维码扫描 | ⭐⭐ 中 |

**使用场景：**
- 🔜 分享对话内容到微信/朋友圈
- 🔜 分享日程到其他应用
- 🔜 日程到期提醒通知
- 🔜 重要消息通知
- 🔜 扫码添加好友
- 🔜 扫码导入日程

---

### 🔒 安全存储

| 依赖 | 版本 | 用途 | 优先级 |
|-----|------|------|--------|
| **flutter_secure_storage** | ^10.0.2 | 加密存储敏感信息 | ⭐⭐⭐ 高 |

**使用场景：**
- 🔜 存储 JWT Token（比 SharedPreferences 更安全）
- 🔜 存储 API 密钥
- 🔜 存储用户敏感设置

---

### 📍 定位相关

| 依赖 | 版本 | 用途 | 优先级 |
|-----|------|------|--------|
| **geolocator** | ^13.0.2 | GPS定位 | ⭐ 低 |

**使用场景：**
- 🔜 基于位置的日程提醒（"到达XX地点时提醒"）
- 🔜 地理位置分享
- 🔜 附近的好友/活动

---

### 📱 设备信息

| 依赖 | 版本 | 用途 | 优先级 |
|-----|------|------|--------|
| **device_info_plus** | ^11.2.0 | 获取设备信息 | ⭐⭐ 中 |

**使用场景：**
- 🔜 错误日志上报（带设备型号）
- 🔜 统计分析
- 🔜 设备兼容性判断

---

## 权限配置需求

预埋这些依赖后，需要在 `AndroidManifest.xml` 和 `Info.plist` 中添加相应权限：

### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<!-- 已添加 -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>

<!-- 需要添加（本次发包时一并添加） -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

### iOS (`ios/Runner/Info.plist`)

```xml
<!-- 已添加 -->
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限以使用语音输入功能</string>
<key>NSCameraUsageDescription</key>
<string>需要相机权限以拍照和发送图片</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册以选择和发送图片</string>

<!-- 需要添加（本次发包时一并添加） -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>需要位置权限以提供基于位置的日程提醒</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>需要后台位置权限以提供到达提醒</string>
<key>NSUserTrackingUsageDescription</key>
<string>需要追踪权限以提供个性化服务</string>
```

---

## 成本分析

### 包体积增加

| 依赖 | Android | iOS | 说明 |
|-----|---------|-----|------|
| file_picker | ~50KB | ~100KB | 轻量 |
| image_cropper | ~500KB | ~800KB | 包含 UI 组件 |
| video_player | ~200KB | ~150KB | 系统播放器 |
| just_audio | ~300KB | ~200KB | 音频引擎 |
| share_plus | ~30KB | ~50KB | 轻量 |
| flutter_local_notifications | ~400KB | ~300KB | 通知组件 |
| mobile_scanner | ~1.5MB | ~1MB | 包含扫码引擎 |
| flutter_secure_storage | ~50KB | ~100KB | 轻量 |
| geolocator | ~100KB | ~150KB | 轻量 |
| device_info_plus | ~20KB | ~30KB | 轻量 |

**总计：** Android +3.15MB，iOS +2.88MB

**权衡：**
- ✅ 避免未来 5-10 次发包
- ✅ 用户只需下载一次
- ❌ 首次安装包稍大（可接受）

---

## 使用建议

### 立即使用的依赖

1. **flutter_secure_storage** - 替换 SharedPreferences 存储 Token
2. **share_plus** - 实现分享功能
3. **flutter_local_notifications** - 实现日程提醒

### 按需使用的依赖

其他依赖暂不初始化，真正需要时再调用，不影响性能。

---

## 未来功能规划

### Phase 4: 文件与媒体（1-2周）
- [ ] 聊天发送文件（file_picker）
- [ ] 聊天发送视频（image_picker + video）
- [ ] 语音消息播放（just_audio）
- [ ] 视频消息播放（video_player）

### Phase 5: 社交增强（2-3周）
- [ ] 分享对话到微信（share_plus）
- [ ] 分享日程到日历（share_plus）
- [ ] 扫码添加好友（mobile_scanner）
- [ ] 二维码名片（qr_flutter + mobile_scanner）

### Phase 6: 智能提醒（3-4周）
- [ ] 日程到期通知（flutter_local_notifications）
- [ ] 基于位置的提醒（geolocator + flutter_local_notifications）
- [ ] 重要消息通知

### Phase 7: 安全与优化（4-6周）
- [ ] Token 加密存储（flutter_secure_storage）
- [ ] 图片压缩优化（flutter_image_compress）
- [ ] 头像裁剪（image_cropper）

---

## 热更新策略

### ✅ 可以热更新的改动
- 纯 Dart 代码逻辑
- UI 布局调整
- 业务逻辑修复
- API 调用修改

### ❌ 不能热更新的改动
- 添加新的原生依赖
- 修改 Android/iOS 配置
- 添加新权限
- 修改原生代码

### 💡 最佳实践
本次预埋后，未来 90% 的功能更新都可以通过热更新完成，只需在以下情况发包：
1. Flutter SDK 大版本升级
2. 重大架构调整
3. 新增的原生功能（如果预埋列表未覆盖）

---

## 安装命令

```bash
flutter pub get
```

---

**文档版本：** v1.0  
**创建日期：** 2026-01-27  
**下次发包计划：** 预计 3-6 个月后
