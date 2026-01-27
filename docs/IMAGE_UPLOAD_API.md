# 图片上传与多模态对话 API 文档

## 概述

本文档介绍图片上传功能和支持图片附件的多模态对话功能。

## 环境配置

在 `.env` 文件中添加以下OSS配置：

```env
# 阿里云 OSS 配置
OSS_ENDPOINT=oss-cn-hangzhou.aliyuncs.com
OSS_ACCESS_KEY_ID=your_access_key_id
OSS_ACCESS_KEY_SECRET=your_access_key_secret
OSS_BUCKET_NAME=your_bucket_name
OSS_BASE_URL=https://your-custom-domain.com  # 可选，自定义域名

# OpenAI 多模态模型配置（确保模型支持vision功能）
OPENAI_MODEL=gpt-4o  # 或 gpt-4-vision-preview
```

### OSS 配置说明

1. **OSS_ENDPOINT**: 阿里云OSS的地域节点，如 `oss-cn-hangzhou.aliyuncs.com`
2. **OSS_ACCESS_KEY_ID**: 阿里云AccessKey ID
3. **OSS_ACCESS_KEY_SECRET**: 阿里云AccessKey Secret
4. **OSS_BUCKET_NAME**: OSS存储桶名称
5. **OSS_BASE_URL**: （可选）自定义域名，不配置则使用默认OSS域名

### OSS 权限配置

**重要：OSS Bucket 必须设置为私有（Private）**

- **读写权限**: 私有（Private）- 保证数据安全
- **访问方式**: 通过预签名URL临时授权访问
- **图片处理**: 可在OSS控制台开启图片自动压缩、缩略图等功能
- **生命周期规则**: 可选，自动清理过期文件

确保您的阿里云账号具有以下权限：
- `oss:PutObject` - 上传文件
- `oss:GetObject` - 读取文件（用于签名URL）
- `oss:DeleteObject` - 删除文件（如果需要）

## 架构设计

### 核心原则：存"钥匙"（Key），不存"临时门票"（预签名URL）

本系统采用了安全且高效的图片管理架构：

1. **数据库存储**：仅存储OSS对象的Key（路径），例如 `images/2026/01/27/uuid.jpg`
2. **临时访问**：每次查询时动态生成预签名URL
3. **分场景授权**：
   - **LLM处理**：生成30分钟有效期的URL（足够AI处理图片）
   - **前端展示**：生成24小时有效期的URL（保证用户浏览体验）
   - **立即上传**：上传成功后返回12小时URL（用于Optimistic UI）

### 数据流程

```
上传 → OSS存储 → 返回Key + 临时URL → 数据库存Key
查询 → 读取Key → 动态生成预签名URL → 返回给前端
LLM  → 读取Key → 生成短期预签名URL → 发送给AI
```

### 为什么不存URL？

- ✅ **安全性**：Bucket私有，无法通过URL直接访问
- ✅ **持久性**：预签名URL会过期，但Key永久有效
- ✅ **灵活性**：可以随时调整URL有效期
- ✅ **成本优化**：避免存储长字符串

## API 接口

### 1. 上传图片

**接口**: `POST /api/upload/image`

**认证**: 需要Bearer Token

**请求格式**: `multipart/form-data`

**请求参数**:
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| file   | File | 是   | 图片文件 |

**文件限制**:
- 支持格式: jpg, jpeg, png, gif, webp
- 最大文件大小: 5MB
- 会验证文件的MIME类型和扩展名

**响应示例**:
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "key": "images/2026/01/27/a1b2c3d4-uuid.jpg",
    "url": "https://your-bucket.oss-cn-hangzhou.aliyuncs.com/images/2026/01/27/a1b2c3d4-uuid.jpg?Expires=xxx&Signature=xxx",
    "filename": "screenshot.jpg",
    "size": 102400
  }
}
```

**字段说明**:
- `key`: OSS对象Key，**前端需要将此值存入数据库**的attachments字段
- `url`: 预签名URL（12小时有效），用于前端立即展示
- `filename`: 原始文件名
- `size`: 文件大小（字节）

**错误响应**:
```json
{
  "code": 400,
  "message": "文件大小超过限制，最大允许5MB，当前文件大小: 6.5MB"
}
```

### 2. 发送带图片的对话消息

**接口**: `POST /api/conversations/{id}/messages`

**认证**: 需要Bearer Token

**请求格式**: `application/json`

**请求参数**:
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| role   | string | 是 | 消息角色，通常为 "user" |
| content | string | 是 | 消息文本内容 |
| attachments | object | 否 | 附件信息（图片） |
| metadata | object | 否 | 元数据 |

**附件格式（attachments）**:
```json
{
  "images": [
    {
      "key": "images/2026/01/27/uuid.jpg",
      "name": "screenshot.jpg"
    }
  ]
}
```

**重要**：前端发送消息时，attachments中应该存储上传接口返回的`key`字段，而不是`url`字段。

**完整请求示例**:
```json
{
  "role": "user",
  "content": "这张图片里有什么内容？",
  "attachments": {
    "images": [
      {
        "key": "images/2026/01/27/uuid.jpg",
        "name": "screenshot.jpg"
      }
    ]
  }
}
```

**响应示例**:
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": "msg-123",
    "role": "assistant",
    "content": "这张图片显示的是...",
    "conversationId": "conv-456",
    "createdAt": "2026-01-27T10:00:00Z"
  }
}
```

### 查询历史消息时的URL处理

当前端调用 `GET /api/conversations/{id}` 或 `GET /api/conversations` 获取对话历史时：

1. 后端会自动为消息中的附件生成新的预签名URL
2. 返回的attachments中会同时包含`key`和`url`字段：

```json
{
  "images": [
    {
      "key": "images/2026/01/27/uuid.jpg",
      "name": "screenshot.jpg",
      "url": "https://...presigned-url...?Expires=xxx"
    }
  ]
}
```

3. 前端使用`url`字段展示图片（24小时有效）
4. 如果URL过期，前端可以监听`onError`事件重新请求对话历史获取新URL

### 3. 流式发送带图片的对话消息

**接口**: `POST /api/conversations/{id}/messages/stream`

**认证**: 需要Bearer Token

**请求格式**: 与非流式接口相同

**响应格式**: Server-Sent Events (SSE)

**SSE 事件类型**:
- `user_message`: 用户消息已保存
- `progress`: 处理进度
- `content`: AI响应内容（流式）
- `tool_call`: 工具调用信息
- `tool_result`: 工具执行结果
- `done`: 完成标志
- `error`: 错误信息

## 使用示例

### 示例1: 上传图片并发送给AI

```javascript
// 1. 上传图片
const formData = new FormData();
formData.append('file', imageFile);

const uploadResponse = await fetch('/api/upload/image', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`
  },
  body: formData
});

const { data: { key, url } } = await uploadResponse.json();

// 2. 发送带图片的消息（使用key，而不是url）
const messageResponse = await fetch(`/api/conversations/${conversationId}/messages`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    role: 'user',
    content: '请分析这张图片',
    attachments: {
      images: [{
        key: key,  // 存储key到数据库
        name: imageFile.name
      }]
    }
  })
});

// 3. 前端可以使用url立即展示图片（Optimistic UI）
// <img src={url} alt="uploaded" />
```

### 示例2: 获取历史对话并展示图片

```javascript
// 1. 获取对话历史
const response = await fetch(`/api/conversations/${conversationId}`, {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});

const { data: conversation } = await response.json();

// 2. 渲染消息（后端已经为每个附件生成了新的预签名URL）
conversation.messages.forEach(message => {
  if (message.attachments) {
    const attachments = JSON.parse(message.attachments);
    attachments.images?.forEach(image => {
      // 使用后端动态生成的url字段（24小时有效）
      console.log('Image URL:', image.url);
      console.log('Image Key:', image.key);
    });
  }
});
```

### 示例3: 处理图片加载失败（URL过期）

```javascript
function ImageWithFallback({ imageData, conversationId }) {
  const [imageUrl, setImageUrl] = useState(imageData.url);

  const handleError = async () => {
    // URL过期，重新获取对话历史以获得新的预签名URL
    const response = await fetch(`/api/conversations/${conversationId}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    const { data } = await response.json();
    const message = data.messages.find(m => {
      const attachments = JSON.parse(m.attachments || '{}');
      return attachments.images?.some(img => img.key === imageData.key);
    });

    if (message) {
      const attachments = JSON.parse(message.attachments);
      const refreshedImage = attachments.images.find(img => img.key === imageData.key);
      setImageUrl(refreshedImage.url);
    }
  };

  return <img src={imageUrl} onError={handleError} alt={imageData.name} />;
}
```

### 示例2: 发送多张图片

```javascript
const response = await fetch(`/api/conversations/${conversationId}/messages`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    role: 'user',
    content: '比较这两张图片的区别',
    attachments: {
      images: [
        { key: 'images/2026/01/27/uuid-1.jpg', name: 'before.jpg' },
        { key: 'images/2026/01/27/uuid-2.jpg', name: 'after.jpg' }
      ]
    }
  })
});
```

## 安全注意事项

1. **OSS私有化**：Bucket必须设置为私有（Private），禁止公共访问
2. **预签名URL**：所有访问通过临时的预签名URL，自动过期
3. **文件验证**：后端会验证文件类型、大小、MIME类型和Key格式
4. **Key验证**：附件中的Key必须符合`images/`开头的格式
5. **不信任前端**：所有验证都在后端执行，不依赖前端传入的数据
6. **访问控制**：上传接口需要用户认证
7. **数据隔离**：数据库只存储Key，不存储完整URL

## 错误处理

| 错误码 | 说明 | 解决方案 |
|--------|------|----------|
| 400 | 文件大小超限 | 压缩图片或选择更小的文件 |
| 400 | 不支持的文件类型 | 使用支持的格式（jpg, png等） |
| 400 | 附件格式无效 | 检查JSON格式是否正确 |
| 400 | 无效的图片Key | 确保Key格式正确（images/开头） |
| 500 | OSS上传失败 | 检查OSS配置和网络连接 |
| 500 | 生成预签名URL失败 | 检查OSS配置和权限 |

## 技术实现细节

### 文件存储路径

上传的图片按日期组织，路径格式为：
```
images/{YYYY}/{MM}/{DD}/{UUID}.{ext}
```

例如：`images/2026/01/24/a1b2c3d4-5678-9012-3456-uuid.jpg`

### 多模态消息处理

当消息包含图片附件时，后端会：
1. 验证附件JSON格式和Key有效性
2. 从数据库读取消息的Key
3. 为每个Key动态生成预签名URL（30分钟用于LLM，24小时用于前端）
4. 构建包含文本和图片的多模态消息发送给LLM

**URL有效期策略**：
- **LLM处理时**：30分钟（足够AI分析图片）
- **前端查询时**：24小时（保证用户浏览体验）
- **上传成功后**：12小时（用于立即展示）

### 模型兼容性

确保环境变量中配置的模型支持vision功能：
- ✅ gpt-4o
- ✅ gpt-4-vision-preview
- ✅ gpt-4-turbo（部分版本）
- ❌ gpt-3.5-turbo（不支持图片）

如果模型不支持图片，系统会优雅降级，只处理文本内容。

## 常见问题

**Q: OSS Bucket必须设置为私有吗？**
A: 是的，强烈建议设置为私有（Private）。我们通过预签名URL提供临时访问权限，这样既安全又灵活。

**Q: 上传的图片会被压缩吗？**
A: 后端不做压缩，但可以在阿里云OSS控制台配置自动图片处理功能（如自动压缩、缩略图等）。

**Q: 预签名URL过期了怎么办？**
A: 前端重新调用对话历史接口，后端会自动生成新的预签名URL。建议在前端监听图片的`onError`事件自动重试。

**Q: 为什么要存Key而不是URL？**
A:
- Key是永久有效的文件标识
- URL会过期，不适合长期存储
- 动态生成URL可以灵活调整有效期
- 节省数据库存储空间

**Q: 可以上传其他类型的附件吗？**
A: 当前版本只支持图片，但架构已经支持扩展。未来可以轻松添加PDF、文档等类型。

**Q: 如何删除已上传的图片？**
A: 建议在OSS控制台配置生命周期规则自动清理，或调用OSSService的DeleteImage方法。

**Q: 不同场景的URL有效期为什么不同？**
A:
- LLM处理：30分钟足够，避免长期暴露
- 前端浏览：24小时保证用户体验
- 立即展示：12小时平衡安全和体验

**Q: 前端应该使用key还是url展示图片？**
A: 前端应该使用后端返回的`url`字段展示图片。`key`字段仅在发送新消息时使用，用于存储到数据库。
