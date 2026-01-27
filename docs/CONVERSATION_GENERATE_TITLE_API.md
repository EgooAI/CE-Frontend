# 会话标题生成 API 文档

## 📌 概述

生成会话标题接口用于根据用户提供的内容，使用 AI 自动生成简短、准确的会话标题。适用于创建会话时快速生成有意义的标题，提升用户体验。

---

## 🚀 API 端点

### 生成会话标题
```
POST /api/conversations/generate-title
```

**功能说明**
- 根据传入的文本内容，调用 AI 模型生成简短标题（通常 5-15 字）
- 超时时间：30 秒
- 需要 Bearer Token 认证

---

## 📝 请求格式

**请求头**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**请求体**
```json
{
  "content": "我想了解如何使用 Go 语言开发 Web 应用，特别是 Gin 框架的最佳实践。"
}
```

**参数说明**
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| content | string | 是 | 用于生成标题的文本内容，建议 10-500 字符 |

---

## ✅ 响应格式

**成功响应（200 OK）**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "title": "Go Web 开发与 Gin 框架实践"
  },
  "trace_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**响应字段说明**
| 字段名 | 类型 | 说明 |
|--------|------|------|
| title | string | AI 生成的标题文本 |

---

## ❌ 错误响应

**请求参数无效（400 Bad Request）**
```json
{
  "code": 400,
  "message": "请求参数无效",
  "data": "content字段不能为空",
  "trace_id": "xxx",
  "error_code": "INVALID_INPUT"
}
```

**生成失败（500 Internal Server Error）**
```json
{
  "code": 500,
  "message": "生成标题失败",
  "data": "AI service timeout",
  "trace_id": "xxx",
  "error_code": "INTERNAL_SERVER_ERROR"
}
```

**未授权（401 Unauthorized）**
```json
{
  "code": 401,
  "message": "无效的访问令牌",
  "error_code": "INVALID_TOKEN"
}
```

---

## 💡 前端集成示例

### JavaScript / Fetch API
```javascript
async function generateConversationTitle(content, accessToken) {
  try {
    const response = await fetch('http://localhost:8080/api/conversations/generate-title', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ content })
    });

    const result = await response.json();

    if (response.ok) {
      console.log('生成的标题:', result.data.title);
      return result.data.title;
    } else {
      console.error('生成失败:', result.message);
      throw new Error(result.message);
    }
  } catch (error) {
    console.error('请求错误:', error);
    throw error;
  }
}

// 使用示例
const title = await generateConversationTitle(
  '我需要一个能够管理日常任务的应用',
  'your-access-token-here'
);
```

### Vue 3 Composition API
```vue
<script setup>
import { ref } from 'vue';

const content = ref('');
const generatedTitle = ref('');
const isGenerating = ref(false);
const error = ref('');

async function handleGenerateTitle() {
  if (!content.value.trim()) {
    error.value = '请输入内容';
    return;
  }

  isGenerating.value = true;
  error.value = '';

  try {
    const response = await fetch('/api/conversations/generate-title', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${localStorage.getItem('access_token')}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ content: content.value })
    });

    const result = await response.json();

    if (response.ok) {
      generatedTitle.value = result.data.title;
    } else {
      error.value = result.message || '生成失败';
    }
  } catch (err) {
    error.value = '网络错误或服务不可用';
  } finally {
    isGenerating.value = false;
  }
}
</script>

<template>
  <div class="title-generator">
    <textarea
      v-model="content"
      placeholder="输入会话的主要内容..."
      rows="4"
    />
    <button
      @click="handleGenerateTitle"
      :disabled="isGenerating"
    >
      {{ isGenerating ? '生成中...' : '生成标题' }}
    </button>

    <div v-if="generatedTitle" class="result">
      <strong>生成的标题：</strong>{{ generatedTitle }}
    </div>

    <div v-if="error" class="error">
      {{ error }}
    </div>
  </div>
</template>
```

### React (Hooks)
```jsx
import { useState } from 'react';

function TitleGenerator() {
  const [content, setContent] = useState('');
  const [title, setTitle] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const generateTitle = async () => {
    if (!content.trim()) {
      setError('请输入内容');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const response = await fetch('/api/conversations/generate-title', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('access_token')}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ content })
      });

      const result = await response.json();

      if (response.ok) {
        setTitle(result.data.title);
      } else {
        setError(result.message || '生成失败');
      }
    } catch (err) {
      setError('网络错误');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <textarea
        value={content}
        onChange={(e) => setContent(e.target.value)}
        placeholder="输入会话内容..."
        rows={4}
      />
      <button onClick={generateTitle} disabled={loading}>
        {loading ? '生成中...' : '生成标题'}
      </button>
      {title && <div>生成的标题：{title}</div>}
      {error && <div className="error">{error}</div>}
    </div>
  );
}
```

---

## 📌 最佳实践

### 1. 内容选择
- 建议使用会话的首条消息或前 1-2 条消息内容
- 避免传入过长文本（超过 500 字符可能影响效果）
- 确保内容有明确的主题或意图

### 2. 错误处理
```javascript
async function safeGenerateTitle(content, accessToken) {
  try {
    const response = await fetch('/api/conversations/generate-title', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ content })
    });

    const result = await response.json();

    if (response.ok) {
      return result.data.title;
    }

    // 根据错误类型返回默认标题
    if (result.error_code === 'INVALID_TOKEN') {
      // 跳转到登录页
      window.location.href = '/login';
      return null;
    }

    // 生成失败时使用截取内容作为标题
    return content.slice(0, 20) + '...';

  } catch (error) {
    console.error('生成标题异常:', error);
    // 返回默认标题
    return '新会话';
  }
}
```

### 3. 性能优化
```javascript
// 使用防抖避免频繁调用
import { debounce } from 'lodash';

const debouncedGenerate = debounce(async (content, accessToken) => {
  return await generateConversationTitle(content, accessToken);
}, 500);

// 缓存结果避免重复生成
const titleCache = new Map();

async function getCachedTitle(content, accessToken) {
  const cacheKey = content.trim();

  if (titleCache.has(cacheKey)) {
    return titleCache.get(cacheKey);
  }

  const title = await generateConversationTitle(content, accessToken);
  titleCache.set(cacheKey, title);

  return title;
}
```

### 4. 用户体验建议
- 在生成过程中显示加载状态（如 Loading 动画）
- 生成失败时提供手动输入标题的选项
- 允许用户编辑生成的标题
- 自动生成可作为默认值，但不强制使用

---

## 🔧 测试示例

### cURL 命令
```bash
curl -X POST http://localhost:8080/api/conversations/generate-title \
  -H "Authorization: Bearer your-access-token" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "我想了解如何优化 Go 应用的性能，特别是数据库查询方面"
  }'
```

### Postman 配置
1. **Method**: POST
2. **URL**: `http://localhost:8080/api/conversations/generate-title`
3. **Headers**:
   - `Authorization`: `Bearer your-access-token`
   - `Content-Type`: `application/json`
4. **Body** (raw JSON):
```json
{
  "content": "我想了解如何优化 Go 应用的性能"
}
```

---

## ⚠️ 注意事项

1. **认证要求**：所有请求必须携带有效的 Bearer Token
2. **超时限制**：请求超时时间为 30 秒，超时会返回错误
3. **内容长度**：建议 content 长度在 10-500 字符之间
4. **频率限制**：建议前端实现防抖，避免短时间内频繁调用
5. **幂等性**：相同内容可能生成不同标题（AI 模型的随机性）
6. **依赖服务**：依赖外部 LLM 服务，确保配置正确且服务可用

---

## 🔄 与其他接口的配合使用

### 创建会话时自动生成标题
```javascript
async function createConversationWithAutoTitle(firstMessage, accessToken) {
  // 1. 先生成标题
  const title = await generateConversationTitle(firstMessage, accessToken);

  // 2. 创建会话
  const response = await fetch('/api/conversations', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ title })
  });

  const conversation = await response.json();

  // 3. 添加首条消息
  await fetch(`/api/conversations/${conversation.data.id}/messages`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      content: firstMessage,
      role: 'user'
    })
  });

  return conversation.data;
}
```

---

## 📚 相关文档
- [会话管理 API](./CONVERSATION_API.md)（如果存在）
- [认证与授权文档](./AUTH_API.md)（如果存在）
