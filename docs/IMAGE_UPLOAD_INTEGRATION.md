# 图片上传功能集成文档

## 概述

已完成聊天页面的图片上传功能集成，用户可以通过相册选择或拍照的方式添加图片到聊天消息中。

## 已完成功能

### 1. ✅ 图片选择和上传

- **从相册选择**：点击相机图标 → 从相册选择
- **拍照**：点击相机图标 → 拍照
- **自动上传**：选择图片后自动上传到服务器
- **上传状态**：显示上传中、成功、失败状态

### 2. ✅ 图片预览 UI

模仿微信聊天的图片预览设计：

```
┌─────────────────────────────────────────┐
│ [图片1] [图片2] [图片3] [+添加]         │
│  [X]     [X]     [X]                     │
└─────────────────────────────────────────┘
│ 🎤 [输入框...]              [发送] │
└─────────────────────────────────────────┘
```

**特性：**
- 横向滚动展示所有图片
- 最多支持 9 张图片
- 每张图片有删除按钮（右上角 X）
- 上传中显示 loading 动画
- 上传失败显示错误图标
- 加号按钮添加更多图片

### 3. ✅ 权限配置

**Android (`AndroidManifest.xml`):**
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
```

**iOS (`Info.plist`):**
```xml
<key>NSCameraUsageDescription</key>
<string>需要相机权限以拍照和发送图片</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册以选择和发送图片</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>需要保存照片到相册</string>
```

## 文件结构

### 新增文件

```
lib/
├── services/
│   └── upload/
│       └── image_upload_service.dart    # 图片上传服务
└── widgets/
    └── chat/
        └── image_preview_widget.dart    # 图片预览组件
```

### 修改文件

```
lib/
├── pages/
│   └── chat/
│       └── chat_page.dart               # 添加图片选择和上传逻辑
└── widgets/
    └── chat/
        └── chat_input_bar.dart          # 集成图片预览
```

## 使用流程

### 用户流程

1. **选择图片**
   - 点击输入框左侧的相机图标
   - 选择"从相册选择"或"拍照"
   - 系统打开相册/相机

2. **图片上传**
   - 选择图片后自动上传到服务器
   - 预览区域显示上传进度
   - 上传成功后显示图片缩略图

3. **编辑图片**
   - 点击删除按钮移除图片
   - 点击加号添加更多图片（最多9张）

4. **发送消息**
   - 输入文字内容（可选）
   - 点击发送按钮
   - 图片和文字一起发送给 AI

### 技术流程

```
用户点击相机图标
    ↓
显示选择菜单（相册/拍照）
    ↓
image_picker 选择图片
    ↓
创建 ImageAttachment（isUploading=true）
    ↓
ImageUploadService.uploadImage()
    ↓
POST /api/upload/image
    ↓
更新 ImageAttachment（url=xxx, isUploading=false）
    ↓
用户点击发送
    ↓
构建 attachments 数据
    ↓
POST /api/conversations/{id}/messages
    ↓
发送成功，清空图片列表
```

## API 集成

### 1. 图片上传接口

**接口：** `POST /api/upload/image`

**请求：**
```
Content-Type: multipart/form-data

file: [图片文件]
```

**响应：**
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "key": "images/2026/01/27/uuid.jpg",
    "url": "https://bucket.oss-cn-hangzhou.aliyuncs.com/images/2026/01/27/uuid.jpg?Expires=xxx&Signature=xxx",
    "filename": "photo.jpg",
    "size": 102400
  }
}
```

**重要字段说明：**
- `key`: OSS对象Key（永久有效），**必须存入数据库**
- `url`: 预签名URL（12小时有效），仅用于前端立即展示

### 2. 发送带图片的消息

**接口：** `POST /api/conversations/{id}/messages`

**请求：**
```json
{
  "role": "user",
  "content": "这张图片里有什么？",
  "attachments": {
    "images": [
      {
        "key": "images/2026/01/27/uuid.jpg",
        "name": "photo.jpg"
      }
    ]
  }
}
```

**注意：** 必须发送 `key` 字段（而不是 `url`），因为：
- ✅ `key` 是永久有效的文件标识
- ❌ `url` 会过期，不适合存储到数据库
- ✅ 后端会根据 `key` 动态生成新的预签名 URL

## 核心代码说明

### ImageAttachment 数据模型

```dart
class ImageAttachment {
  final File? file;          // 本地文件
  final String? key;         // OSS对象Key（永久有效，存数据库）
  final String? url;         // 预签名URL（临时有效，用于展示）
  final String name;         // 文件名
  final bool isUploading;    // 是否正在上传
  final String? error;       // 上传错误信息
}
```

### ImageInfo 数据模型（上传响应）

```dart
class ImageInfo {
  final String key;          // OSS对象Key（永久有效）
  final String url;          // 预签名URL（12小时有效）
  final String filename;     // 原始文件名
  final int size;            // 文件大小
}
```

### ChatPage 图片处理

```dart
// 选择图片
Future<void> _pickImage() async {
  final XFile? image = await _imagePicker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1920,
    maxHeight: 1920,
    imageQuality: 85,
  );
  if (image != null) {
    await _handleImageSelected(image);
  }
}

// 处理选中的图片
Future<void> _handleImageSelected(XFile xfile) async {
  // 1. 添加到列表（上传中状态）
  setState(() {
    _images.add(ImageAttachment(
      file: File(xfile.path),
      name: fileName,
      isUploading: true,
    ));
  });

  // 2. 上传图片
  final imageInfo = await _imageUploadService.uploadImage(file);

  // 3. 更新状态（同时保存 key 和 url）
  setState(() {
    _images[index] = _images[index].copyWith(
      key: imageInfo.key,         // OSS对象Key（永久有效，存数据库）
      url: imageInfo.url,         // 预签名URL（12小时有效，用于展示）
      isUploading: false,
    );
  });
}

// 发送消息
Future<void> _sendMessage() async {
  // 构建附件数据（使用 key 而不是 url）
  Map<String, dynamic>? attachments;
  if (_images.isNotEmpty) {
    attachments = {
      'images': _images
          .where((img) => img.key != null)  // 确保 key 存在
          .map((img) => {
                'key': img.key!,            // 发送 key 到后端
                'name': img.name,
              })
          .toList(),
    };
  }

  // 添加到消息
  final message = Message(
    role: 'user',
    content: content,
    attachments: attachments,  // attachments 包含 key 字段
  );
}
```

### 为什么使用 key 而不是 url？

根据后端 API 设计（详见 `IMAGE_UPLOAD_API.md`）：

1. **OSS Bucket 设置为私有**：无法通过 URL 直接访问
2. **预签名 URL 会过期**：
   - 上传后返回的 URL：12小时有效（用于立即展示）
   - LLM 处理时生成的 URL：30分钟有效
   - 前端查询时生成的 URL：24小时有效
3. **key 是永久标识**：存储 key 到数据库，查询时后端动态生成新的预签名 URL
4. **安全性更高**：通过临时 URL 授权访问，而不是永久公开

### 查询历史消息时的处理

当调用 `GET /api/conversations/{id}` 获取对话历史时：

```dart
// 后端返回的消息包含 key 和新生成的 url
{
  "attachments": {
    "images": [
      {
        "key": "images/2026/01/27/uuid.jpg",   // 永久标识
        "url": "https://...?Expires=xxx",       // 新生成的24小时URL
        "name": "photo.jpg"
      }
    ]
  }
}

// 前端使用 url 字段展示图片
<img src={message.attachments.images[0].url} alt="..." />

// 如果图片加载失败（URL过期），重新获取对话历史即可
```

## 配置要求

### 依赖包

```yaml
dependencies:
  image_picker: ^1.1.2
```

已在 `pubspec.yaml` 中添加。

### 图片限制

- **支持格式**：jpg, jpeg, png, gif, webp
- **最大尺寸**：1920x1920 像素（自动压缩）
- **图片质量**：85%
- **最大文件大小**：5MB（后端限制）
- **最多数量**：9 张图片

### 后端配置

确保后端已配置以下环境变量（参考 [IMAGE_UPLOAD_API.md](./IMAGE_UPLOAD_API.md)）：

```env
# 阿里云 OSS 配置
OSS_ENDPOINT=oss-cn-hangzhou.aliyuncs.com
OSS_ACCESS_KEY_ID=your_access_key_id
OSS_ACCESS_KEY_SECRET=your_access_key_secret
OSS_BUCKET_NAME=your_bucket_name

# 多模态模型配置
OPENAI_MODEL=gpt-4o  # 必须支持 vision 功能
```

## 测试清单

### 功能测试

- [ ] 从相册选择图片
- [ ] 拍照上传图片
- [ ] 上传多张图片（2-9张）
- [ ] 删除已选择的图片
- [ ] 上传失败时显示错误
- [ ] 发送纯文字消息
- [ ] 发送纯图片消息
- [ ] 发送图文混合消息
- [ ] 上传中禁止发送
- [ ] 发送后清空图片列表

### 权限测试

- [ ] Android 首次使用时请求相机权限
- [ ] Android 首次使用时请求相册权限
- [ ] iOS 首次使用时请求相机权限
- [ ] iOS 首次使用时请求相册权限
- [ ] 权限被拒绝时的提示

### UI 测试

- [ ] 图片预览正确显示
- [ ] 上传进度动画显示
- [ ] 删除按钮可点击
- [ ] 加号按钮在第9张后隐藏
- [ ] 横向滚动流畅
- [ ] 输入框与图片预览对接正确

## 已知限制

1. **图片数量**：最多 9 张图片
2. **文件大小**：后端限制 5MB
3. **格式支持**：仅图片格式，暂不支持视频、文件
4. **编辑功能**：暂无图片编辑（裁剪、滤镜等）
5. **压缩质量**：固定 85%，无法自定义
6. **URL 有效期**：
   - 上传后返回的 URL：12小时（Optimistic UI）
   - 前端查询返回的 URL：24小时（用户浏览）
   - LLM 处理时的 URL：30分钟（AI 分析）
7. **私有 OSS**：Bucket 必须设置为私有，通过预签名 URL 访问

## 后续优化建议

### 短期优化

1. **本地缓存**：已上传图片本地缓存，避免重复上传
2. **图片压缩**：更智能的压缩策略
3. **上传进度**：显示具体百分比
4. **批量上传**：支持一次选择多张图片

### 长期优化

1. **图片编辑**：集成裁剪、旋转、滤镜功能
2. **视频支持**：支持短视频上传
3. **文件支持**：支持 PDF、Word 等文件
4. **语音消息**：集成语音消息功能
5. **图片预览**：点击图片全屏预览

## 常见问题

### 常见问题

**Q: 选择图片后没有反应？**
A: 检查权限是否授予，查看控制台错误日志。

**Q: 上传失败显示 500 错误？**
A: 检查后端 OSS 配置是否正确，网络是否连通。

**Q: 图片显示不出来？**
A: 检查：
   1. 图片 URL 是否有效（是否过期）
   2. OSS bucket 权限是否正确（应该是私有+预签名URL访问）
   3. 预签名 URL 签名是否正确

**Q: 为什么要存 key 而不是 url？**
A: 因为：
   - ✅ `key` 是永久有效的文件标识
   - ❌ `url` 会过期（12/24/30小时），不适合长期存储
   - ✅ 后端可以根据 `key` 动态生成新的预签名 URL
   - ✅ 更安全（OSS Bucket 私有化）

**Q: URL 过期后怎么办？**
A: 重新调用对话历史接口，后端会自动生成新的24小时有效 URL。建议在前端监听图片的 `onError` 事件自动重试。

**Q: Android 编译失败？**
A: 运行 `flutter clean && flutter pub get`。

### 调试步骤

1. **检查权限配置**
   ```bash
   # Android
   cat android/app/src/main/AndroidManifest.xml | grep permission

   # iOS
   cat ios/Runner/Info.plist | grep Usage
   ```

2. **查看上传日志**
   - 打开 Chrome DevTools
   - 查看 Network 标签页
   - 过滤 `/api/upload/image` 请求

3. **测试图片上传服务**
   ```dart
   // 在 ChatPage 中添加调试代码
   print('上传开始: ${file.path}');
   final result = await _imageUploadService.uploadImage(file);
   print('上传成功: ${result.url}');
   ```

## 更新日志

### 2026-01-27 - v1.1

- 🔄 **API 规范更新**：
  - 上传接口返回 `key` 和 `url` 两个字段
  - 发送消息时使用 `key` 而不是 `url`
  - OSS Bucket 设置为私有，通过预签名 URL 访问
- 🔧 **代码重构**：
  - `ImageInfo` 添加 `key` 字段
  - `ImageAttachment` 添加 `key` 字段
  - `ChatPage` 发送消息时使用 `key`
  - 更新文档说明 key/url 的区别和使用场景

### 2026-01-27 - v1.0

- ✅ 创建 ImageUploadService 图片上传服务
- ✅ 创建 ImagePreviewWidget 图片预览组件
- ✅ 修改 ChatInputBar 集成图片预览
- ✅ 修改 ChatPage 添加图片选择和上传
- ✅ 配置 Android/iOS 权限
- ✅ 添加 image_picker 依赖

---

**文档版本：** v1.1
**创建日期：** 2026-01-27
**最后更新：** 2026-01-27
**维护者：** CE-Frontend Team
