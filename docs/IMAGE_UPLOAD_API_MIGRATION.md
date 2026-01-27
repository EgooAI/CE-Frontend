# 图片上传 API 重构说明

## 概述

根据后端 API 文档更新（详见 [IMAGE_UPLOAD_API.md](./IMAGE_UPLOAD_API.md)），完成了图片上传功能的重构，核心变化是**存储 OSS Key 而不是预签名 URL**。

## 核心变化

### 🔑 存"钥匙"而不是"临时门票"

**旧架构：**
```
上传图片 → 返回 URL → 存储 URL 到数据库
```

**新架构：**
```
上传图片 → 返回 key + url → 存储 key 到数据库
                              ↓
查询历史 → 读取 key → 动态生成新 URL → 返回给前端
```

### 为什么要这样做？

| 对比项 | URL（旧方案） | Key（新方案） |
|-------|-------------|-------------|
| **有效期** | ❌ 会过期（12/24小时） | ✅ 永久有效 |
| **安全性** | ❌ 需要公开 Bucket | ✅ Bucket 私有化 |
| **灵活性** | ❌ 固定有效期 | ✅ 可动态调整 |
| **存储成本** | ❌ 长字符串 | ✅ 短路径 |

### URL 有效期策略

根据使用场景，后端动态生成不同有效期的预签名 URL：

| 场景 | 有效期 | 说明 |
|-----|-------|------|
| **上传成功返回** | 12小时 | 用于前端立即展示（Optimistic UI） |
| **前端查询历史** | 24小时 | 保证用户浏览体验 |
| **LLM 处理图片** | 30分钟 | 足够 AI 分析，避免长期暴露 |

## 代码修改详情

### 1. ImageInfo 数据模型（上传响应）

**文件：** `lib/services/upload/image_upload_service.dart`

**变化：**
```dart
// 旧版
class ImageInfo {
  final String url;      // ❌ 只有 URL
  final String filename;
  final int size;
}

// 新版
class ImageInfo {
  final String key;      // ✅ OSS对象Key（永久有效）
  final String url;      // ✅ 预签名URL（12小时有效）
  final String filename;
  final int size;
}
```

**响应示例：**
```json
{
  "code": 0,
  "data": {
    "key": "images/2026/01/27/uuid.jpg",  // 存数据库
    "url": "https://...?Expires=xxx",      // 立即展示
    "filename": "photo.jpg",
    "size": 102400
  }
}
```

### 2. ImageAttachment 数据模型（前端状态）

**文件：** `lib/widgets/chat/image_preview_widget.dart`

**变化：**
```dart
// 旧版
class ImageAttachment {
  final File? file;
  final String? url;     // ❌ 只有 URL
  final String name;
  final bool isUploading;
  final String? error;
}

// 新版
class ImageAttachment {
  final File? file;
  final String? key;     // ✅ OSS对象Key（存数据库）
  final String? url;     // ✅ 预签名URL（展示用）
  final String name;
  final bool isUploading;
  final String? error;
}
```

### 3. 上传图片后的处理

**文件：** `lib/pages/chat/chat_page.dart`

**变化：**
```dart
// 旧版
final imageInfo = await _imageUploadService.uploadImage(file);
setState(() {
  _images[index] = _images[index].copyWith(
    url: imageInfo.url,  // ❌ 只保存 URL
    isUploading: false,
  );
});

// 新版
final imageInfo = await _imageUploadService.uploadImage(file);
setState(() {
  _images[index] = _images[index].copyWith(
    key: imageInfo.key,  // ✅ 保存 Key（存数据库）
    url: imageInfo.url,  // ✅ 保存 URL（立即展示）
    isUploading: false,
  );
});
```

### 4. 发送消息时的附件数据

**文件：** `lib/pages/chat/chat_page.dart`

**变化：**
```dart
// 旧版 - 发送 URL
attachments = {
  'images': _images
      .where((img) => img.url != null)
      .map((img) => {
            'url': img.url!,  // ❌ 发送临时 URL
            'name': img.name,
          })
      .toList(),
};

// 新版 - 发送 Key
attachments = {
  'images': _images
      .where((img) => img.key != null)  // ✅ 确保 key 存在
      .map((img) => {
            'key': img.key!,             // ✅ 发送永久 Key
            'name': img.name,
          })
      .toList(),
};
```

**发送的 JSON：**
```json
{
  "role": "user",
  "content": "这是什么？",
  "attachments": {
    "images": [
      {
        "key": "images/2026/01/27/uuid.jpg",  // ✅ 发送 Key
        "name": "photo.jpg"
      }
    ]
  }
}
```

## 数据流程详解

### 上传流程

```
1. 用户选择图片
   ↓
2. 调用 POST /api/upload/image
   ↓
3. 后端上传到 OSS
   ↓
4. 后端返回 { key, url, filename, size }
   ↓
5. 前端同时保存 key 和 url
   - key: 用于发送消息
   - url: 用于立即展示（12小时）
```

### 发送流程

```
1. 用户点击发送
   ↓
2. 前端构建消息：attachments.images[].key = "images/..."
   ↓
3. 调用 POST /api/conversations/{id}/messages
   ↓
4. 后端保存消息到数据库（存储 key）
   ↓
5. 后端读取 key，生成30分钟 URL 发送给 LLM
   ↓
6. AI 分析图片并返回结果
```

### 查询流程

```
1. 前端调用 GET /api/conversations/{id}
   ↓
2. 后端从数据库读取消息（包含 key）
   ↓
3. 后端为每个 key 动态生成24小时 URL
   ↓
4. 后端返回 { key, url, name }
   ↓
5. 前端使用 url 展示图片
```

### URL 过期处理

```
用户打开聊天页面
   ↓
图片显示失败（onError）
   ↓
前端重新调用 GET /api/conversations/{id}
   ↓
后端生成新的24小时 URL
   ↓
前端更新图片 URL
   ↓
图片正常显示 ✅
```

## 安全优势

### OSS Bucket 私有化

**旧方案（公共 Bucket）：**
- ❌ 任何人都可以通过 URL 访问
- ❌ 无法撤销访问权限
- ❌ 容易被爬虫抓取

**新方案（私有 Bucket + 预签名 URL）：**
- ✅ 必须通过预签名 URL 访问
- ✅ URL 自动过期，无需手动撤销
- ✅ 可以限制访问次数（如果需要）
- ✅ 可以限制访问来源（Referer、IP等）

### 临时授权

```
用户上传图片
   ↓
后端生成12小时 URL（仅用于立即展示）
   ↓
12小时后 URL 失效 ❌
   ↓
恶意用户无法再访问 ✅

但是...
   ↓
正常用户打开聊天页面
   ↓
后端动态生成新的24小时 URL
   ↓
图片正常显示 ✅
```

## 性能优化

### 1. 减少数据库存储

```
旧方案存储（URL）：
"https://bucket.oss-cn-hangzhou.aliyuncs.com/images/2026/01/27/uuid.jpg?Expires=1738051200&OSSAccessKeyId=xxx&Signature=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
长度：~150 字符

新方案存储（Key）：
"images/2026/01/27/uuid.jpg"
长度：~35 字符

节省：~115 字符 × 每张图片
```

### 2. 查询时动态生成 URL

- **缓存友好**：Key 不变，可以缓存
- **按需生成**：只在需要时生成 URL
- **灵活调整**：可以根据客户端类型调整有效期

## 向后兼容性

### 对前端的影响

**✅ 无破坏性变更**：
- 旧的消息如果存储了 URL，后端可以兼容处理
- 新的消息使用 Key，更安全、更持久

**⚠️ 需要注意**：
- 上传图片后，必须保存 `key` 字段
- 发送消息时，必须使用 `key` 而不是 `url`
- 展示图片时，使用后端返回的 `url` 字段

### 对后端的影响

**需要实现**：
1. 上传接口返回 `key` 和 `url`
2. 查询接口动态生成 `url`
3. OSS Bucket 设置为私有
4. 实现预签名 URL 生成逻辑

## 测试清单

### 功能测试

- [x] 上传图片返回 `key` 和 `url`
- [x] 发送消息时使用 `key` 字段
- [x] 查询历史消息返回新的 `url`
- [ ] URL 过期后重新获取
- [ ] 私有 Bucket 无法直接访问
- [ ] 预签名 URL 可以正常访问
- [ ] 预签名 URL 过期后失效

### 安全测试

- [ ] 私有 Bucket 禁止公共访问
- [ ] 预签名 URL 包含有效期参数
- [ ] 过期的 URL 返回 403
- [ ] 无法通过 Key 直接访问图片
- [ ] 签名错误的 URL 返回 403

## 回滚方案

如果新方案出现问题，可以快速回滚到旧方案：

```dart
// 临时回滚：在发送消息时使用 url 而不是 key
attachments = {
  'images': _images
      .where((img) => img.url != null)  // 使用 url
      .map((img) => {
            'url': img.url!,            // 发送 url
            'name': img.name,
          })
      .toList(),
};
```

**注意：** 这只是临时方案，应该尽快修复并重新使用 Key 方案。

## 文档更新

- ✅ [IMAGE_UPLOAD_API.md](./IMAGE_UPLOAD_API.md) - 后端 API 文档（已更新）
- ✅ [IMAGE_UPLOAD_INTEGRATION.md](./IMAGE_UPLOAD_INTEGRATION.md) - 前端集成文档（已更新）
- ✅ 本文档 - API 重构说明

## 后续优化

1. **前端缓存**：缓存 URL（带过期时间），避免频繁重新获取
2. **懒加载**：滚动到可见区域再加载图片 URL
3. **预加载**：提前为下一页消息生成 URL
4. **错误重试**：图片加载失败时自动重新获取 URL
5. **离线支持**：缓存 Key 和最后的 URL，离线时显示缓存

---

**文档版本：** v1.0  
**创建日期：** 2026-01-27  
**作者：** CE-Frontend Team
