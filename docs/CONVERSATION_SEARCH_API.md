# 会话搜索 API 文档

## 📌 概述

会话搜索接口用于用户快速查找特定的会话。支持根据会话标题（title）进行模糊搜索，结果按更新时间倒序排列，便于用户快速定位需要的对话。

---

## 🚀 API 端点

### 搜索会话
```
GET /api/conversations/search?q=关键词
```

**功能说明**
- 根据会话标题进行模糊搜索（不区分大小写）
- 只搜索当前登录用户的会话
- 结果按更新时间从新到旧排列
- 包含完整的消息列表

---

## 📝 请求格式

**请求头**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**查询参数**
| 参数名 | 类型 | 必填 | 说明 | 示例 |
|--------|------|------|------|------|
| q | string | 是 | 搜索关键词（最少 1 个字符） | `任务管理` |

**请求示例**
```bash
GET /api/conversations/search?q=任务管理
Authorization: Bearer your-access-token
```

---

## ✅ 响应格式

**成功响应（200 OK）**
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "title": "项目任务管理讨论",
      "userId": "user123",
      "messages": [
        {
          "id": "msg-001",
          "conversationId": "550e8400-e29b-41d4-a716-446655440000",
          "content": "我们需要建立一个任务管理系统",
          "role": "user",
          "createdAt": "2025-12-15T10:30:00Z"
        },
        {
          "id": "msg-002",
          "conversationId": "550e8400-e29b-41d4-a716-446655440000",
          "content": "可以使用看板或甘特图来可视化任务",
          "role": "assistant",
          "createdAt": "2025-12-15T10:31:00Z"
        }
      ],
      "createdAt": "2025-12-15T10:00:00Z",
      "updatedAt": "2025-12-15T11:30:00Z"
    },
    {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "title": "日常任务计划",
      "userId": "user123",
      "messages": [...],
      "createdAt": "2025-12-15T09:00:00Z",
      "updatedAt": "2025-12-15T11:00:00Z"
    }
  ],
  "trace_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**响应字段说明**
| 字段名 | 类型 | 说明 |
|--------|------|------|
| code | int | HTTP 状态码 |
| message | string | 响应消息 |
| data | array | 搜索结果数组 |
| data[].id | string | 会话 ID |
| data[].title | string | 会话标题 |
| data[].userId | string | 所有者用户 ID |
| data[].messages | array | 会话消息列表 |
| data[].createdAt | string | 创建时间（ISO 8601） |
| data[].updatedAt | string | 最后更新时间（ISO 8601） |
| trace_id | string | 请求追踪 ID |

---

## ❌ 错误响应

**搜索关键词为空（400 Bad Request）**
```json
{
  "code": 400,
  "message": "搜索关键词不能为空",
  "error_code": "INVALID_INPUT",
  "trace_id": "xxx"
}
```

**数据库错误（500 Internal Server Error）**
```json
{
  "code": 500,
  "message": "搜索会话失败",
  "data": "database connection error",
  "error_code": "DATABASE_ERROR",
  "trace_id": "xxx"
}
```

**未授权（401 Unauthorized）**
```json
{
  "code": 401,
  "message": "无效的访问令牌",
  "error_code": "INVALID_TOKEN",
  "trace_id": "xxx"
}
```

**令牌过期（401 Unauthorized）**
```json
{
  "code": 401,
  "message": "访问令牌已过期",
  "error_code": "TOKEN_EXPIRED",
  "trace_id": "xxx"
}
```

---

## 💡 前端集成示例

### JavaScript / Fetch API
```javascript
async function searchConversations(keyword, accessToken) {
  try {
    const response = await fetch(
      `/api/conversations/search?q=${encodeURIComponent(keyword)}`,
      {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const result = await response.json();

    if (response.ok) {
      return result.data; // 返回搜索结果数组
    } else {
      throw new Error(result.message || '搜索失败');
    }
  } catch (error) {
    console.error('搜索会话失败:', error);
    throw error;
  }
}

// 使用示例
const results = await searchConversations('任务管理', accessToken);
console.log(`找到 ${results.length} 个会话`);
results.forEach(conv => {
  console.log(`${conv.title} (最后更新: ${conv.updatedAt})`);
});
```

### Vue 3 Composition API
```vue
<script setup>
import { ref } from 'vue';

const searchKeyword = ref('');
const searchResults = ref([]);
const isSearching = ref(false);
const error = ref('');

async function handleSearch() {
  if (!searchKeyword.value.trim()) {
    error.value = '请输入搜索关键词';
    return;
  }

  isSearching.value = true;
  error.value = '';
  searchResults.value = [];

  try {
    const response = await fetch(
      `/api/conversations/search?q=${encodeURIComponent(searchKeyword.value)}`,
      {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('access_token')}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const result = await response.json();

    if (response.ok) {
      searchResults.value = result.data;
      if (result.data.length === 0) {
        error.value = '未找到匹配的会话';
      }
    } else {
      error.value = result.message || '搜索失败';
    }
  } catch (err) {
    error.value = '网络错误或服务不可用';
  } finally {
    isSearching.value = false;
  }
}

function handleSelectConversation(conversationId) {
  // 跳转到会话详情
  window.location.href = `/conversations/${conversationId}`;
}
</script>

<template>
  <div class="conversation-search">
    <div class="search-box">
      <input
        v-model="searchKeyword"
        type="text"
        placeholder="搜索会话标题..."
        @keyup.enter="handleSearch"
        :disabled="isSearching"
      />
      <button @click="handleSearch" :disabled="isSearching">
        {{ isSearching ? '搜索中...' : '搜索' }}
      </button>
    </div>

    <div v-if="error" class="error-message">{{ error }}</div>

    <div v-if="searchResults.length > 0" class="search-results">
      <div
        v-for="conversation in searchResults"
        :key="conversation.id"
        class="result-item"
        @click="handleSelectConversation(conversation.id)"
      >
        <h3>{{ conversation.title }}</h3>
        <p class="message-count">{{ conversation.messages?.length || 0 }} 条消息</p>
        <p class="updated-time">
          最后更新: {{ new Date(conversation.updatedAt).toLocaleString() }}
        </p>
      </div>
    </div>

    <div v-else-if="!isSearching && searchKeyword" class="no-results">
      未找到与"{{ searchKeyword }}"相关的会话
    </div>
  </div>
</template>

<style scoped>
.conversation-search {
  padding: 20px;
}

.search-box {
  display: flex;
  gap: 10px;
  margin-bottom: 20px;
}

.search-box input {
  flex: 1;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 14px;
}

.search-box button {
  padding: 10px 20px;
  background-color: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.search-box button:disabled {
  background-color: #ccc;
  cursor: not-allowed;
}

.error-message {
  color: #d32f2f;
  padding: 10px;
  margin-bottom: 10px;
  background-color: #ffebee;
  border-radius: 4px;
}

.search-results {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.result-item {
  padding: 15px;
  border: 1px solid #ddd;
  border-radius: 4px;
  cursor: pointer;
  transition: box-shadow 0.2s;
}

.result-item:hover {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.result-item h3 {
  margin: 0 0 8px 0;
  color: #333;
}

.message-count {
  margin: 4px 0;
  color: #666;
  font-size: 12px;
}

.updated-time {
  margin: 4px 0 0 0;
  color: #999;
  font-size: 12px;
}

.no-results {
  text-align: center;
  padding: 40px 20px;
  color: #999;
}
</style>
```

### React (Hooks)
```jsx
import { useState } from 'react';

function ConversationSearch() {
  const [keyword, setKeyword] = useState('');
  const [results, setResults] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSearch = async () => {
    if (!keyword.trim()) {
      setError('请输入搜索关键词');
      return;
    }

    setLoading(true);
    setError('');
    setResults([]);

    try {
      const response = await fetch(
        `/api/conversations/search?q=${encodeURIComponent(keyword)}`,
        {
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('access_token')}`,
            'Content-Type': 'application/json'
          }
        }
      );

      const result = await response.json();

      if (response.ok) {
        setResults(result.data);
        if (result.data.length === 0) {
          setError('未找到匹配的会话');
        }
      } else {
        setError(result.message || '搜索失败');
      }
    } catch (err) {
      setError('网络错误或服务不可用');
    } finally {
      setLoading(false);
    }
  };

  const handleSelectConversation = (conversationId) => {
    window.location.href = `/conversations/${conversationId}`;
  };

  return (
    <div className="conversation-search">
      <div className="search-box">
        <input
          type="text"
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
          onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
          placeholder="搜索会话标题..."
          disabled={loading}
        />
        <button onClick={handleSearch} disabled={loading}>
          {loading ? '搜索中...' : '搜索'}
        </button>
      </div>

      {error && <div className="error-message">{error}</div>}

      {results.length > 0 && (
        <div className="search-results">
          {results.map((conv) => (
            <div
              key={conv.id}
              className="result-item"
              onClick={() => handleSelectConversation(conv.id)}
            >
              <h3>{conv.title}</h3>
              <p className="message-count">
                {conv.messages?.length || 0} 条消息
              </p>
              <p className="updated-time">
                最后更新: {new Date(conv.updatedAt).toLocaleString()}
              </p>
            </div>
          ))}
        </div>
      )}

      {!loading && keyword && results.length === 0 && !error && (
        <div className="no-results">
          未找到与"{keyword}"相关的会话
        </div>
      )}
    </div>
  );
}

export default ConversationSearch;
```

---

## 📌 最佳实践

### 1. 搜索关键词输入
- 建议至少输入 1 个字符，最多无限制
- 支持中英文混搜
- 不区分大小写

```javascript
// 有效的搜索关键词
"任务"          // 中文
"task"         // 英文
"Project Plan" // 多词
"2025-12"      // 日期
```

### 2. 防抖处理
避免频繁发送搜索请求，使用防抖延迟搜索：

```javascript
import { debounce } from 'lodash';

const debouncedSearch = debounce(async (keyword) => {
  const results = await searchConversations(keyword, accessToken);
  setSearchResults(results);
}, 300); // 延迟 300ms

// 在输入框 onChange 事件中调用
<input onChange={(e) => debouncedSearch(e.target.value)} />
```

### 3. 缓存搜索结果
避免重复搜索相同关键词：

```javascript
const searchCache = new Map();

async function getCachedSearchResults(keyword, accessToken) {
  if (searchCache.has(keyword)) {
    return searchCache.get(keyword);
  }

  const results = await searchConversations(keyword, accessToken);
  searchCache.set(keyword, results);

  return results;
}
```

### 4. 结果展示优化
- 默认显示前 10 条结果（可分页）
- 突出显示匹配的关键词
- 显示会话最后更新时间和消息数

```javascript
function highlightKeyword(text, keyword) {
  const regex = new RegExp(`(${keyword})`, 'gi');
  return text.replace(regex, '<mark>$1</mark>');
}
```

---

## 🔧 测试示例

### cURL 命令
```bash
# 搜索包含"任务"的会话
curl -X GET \
  -H "Authorization: Bearer your-access-token" \
  -H "Content-Type: application/json" \
  "http://localhost:8080/api/conversations/search?q=任务"

# 搜索包含"Go"的会话
curl -X GET \
  -H "Authorization: Bearer your-access-token" \
  "http://localhost:8080/api/conversations/search?q=Go"
```

### Postman 配置
1. **Method**: GET
2. **URL**: `http://localhost:8080/api/conversations/search`
3. **Params**:
   - Key: `q`
   - Value: `任务管理`
4. **Headers**:
   - `Authorization`: `Bearer your-access-token`
   - `Content-Type`: `application/json`

---

## ⚠️ 注意事项

1. **认证必需**：所有请求必须携带有效的 Bearer Token
2. **关键词必需**：`q` 参数不能为空或仅包含空格
3. **大小写不敏感**：搜索不区分大小写（即"Task"和"task"搜索结果相同）
4. **部分匹配**：支持标题中的任意部分匹配（如"任务"会匹配"项目任务管理"）
5. **结果排序**：结果按会话最后更新时间从新到旧排列
6. **性能考虑**：
   - 搜索大量会话时可能有延迟，建议前端添加超时处理
   - 建议实现防抖以减少请求频率
   - 可考虑服务端实现结果分页

---

## 🔄 与其他接口的配合使用

### 完整的会话流程
```javascript
async function completeConversationFlow(accessToken) {
  // 1. 创建新会话
  const createRes = await fetch('/api/conversations', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ title: '新项目讨论' })
  });
  const newConv = await createRes.json();
  
  // 2. 添加消息
  await fetch(`/api/conversations/${newConv.data.id}/messages`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      content: '我们需要讨论新项目计划',
      role: 'user'
    })
  });
  
  // 3. 更新会话标题（可选）
  await fetch(`/api/conversations/${newConv.data.id}/title`, {
    method: 'PUT',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ title: '2025 年新项目计划' })
  });
  
  // 4. 搜索相关会话
  const results = await searchConversations('项目计划', accessToken);
  console.log('找到相关会话:', results);
  
  return results;
}
```

---

## 📚 相关文档
- [会话管理 API](./CONVERSATION_API.md)（如果存在）
- [会话标题生成 API](./CONVERSATION_GENERATE_TITLE_API.md)
- [认证与授权文档](./AUTH_API.md)（如果存在）
