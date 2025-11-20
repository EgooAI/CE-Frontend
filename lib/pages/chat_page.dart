import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/conversation.dart';
import '../services/conversation_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ConversationService _conversationService = ConversationService();
  
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await _conversationService.getConversations();
      setState(() {
        _conversations = conversations;
        // 如果没有选中对话且有对话列表，默认选中第一个（或者保持null等待用户选择）
        // 这里我们保持null，显示欢迎页或空状态
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载对话列表失败: $e')),
        );
      }
    }
  }

  Future<void> _selectConversation(Conversation conversation) async {
    setState(() {
      _currentConversation = conversation;
      _messages = []; // 清空当前显示的消息
      _isLoading = true;
    });
    
    // 关闭侧边栏
    Navigator.pop(context);

    try {
      // 获取对话详情（包含消息）
      final detail = await _conversationService.getConversation(conversation.id);
      
      setState(() {
        _messages = detail.messages ?? [];
      });
      
      // 滚动到底部
      _scrollToBottom();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载对话详情失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createNewConversation() async {
    try {
      final conversation = await _conversationService.createConversation("新对话");
      setState(() {
        _conversations.insert(0, conversation);
        _currentConversation = conversation;
        _messages = [];
      });
      Navigator.pop(context); // 关闭侧边栏
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建对话失败: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    if (_currentConversation == null) {
      // 如果没有当前对话，先创建一个
      await _createNewConversation();
      if (_currentConversation == null) return;
    }

    final content = _controller.text;
    _controller.clear();
    
    setState(() {
      _messages.add(Message(
        id: 'temp_user_${DateTime.now().millisecondsSinceEpoch}',
        role: 'user',
        content: content,
        conversationId: _currentConversation!.id,
        createdAt: DateTime.now(),
      ));
      _isSending = true;
    });
    
    _scrollToBottom();

    try {
      // 发送消息并获取AI回复
      // 注意：后端AddMessage接口返回的是AI的回复消息（根据之前的重构）
      // 或者是用户的消息？让我们回顾一下后端代码。
      // 后端AddMessage返回的是 `c.JSON(http.StatusCreated, aiMessage)`
      // 所以我们直接把返回的消息加进去就是AI的回复。
      // 但是用户的消息也需要保存到本地列表（虽然我们已经临时加了，但最好是用后端返回的确认）。
      // 
      // 实际上，后端逻辑是：
      // 1. 保存用户消息
      // 2. 调用LLM
      // 3. 保存AI消息
      // 4. 返回AI消息
      // 
      // 所以我们前端显示的"用户消息"是乐观更新的。
      // 返回的"AI消息"是确定的。
      
      final aiMessage = await _conversationService.sendMessage(_currentConversation!.id, content);
      
      if (mounted) {
        setState(() {
          _messages.add(aiMessage);
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送消息失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentConversation?.title ?? 'AI 助手'),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("我的对话"),
              accountEmail: null,
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.chat),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('新建对话'),
              onTap: _createNewConversation,
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final conversation = _conversations[index];
                  return ListTile(
                    title: Text(conversation.title),
                    subtitle: Text(conversation.updatedAt.toString().split('.')[0]),
                    selected: _currentConversation?.id == conversation.id,
                    onTap: () => _selectConversation(conversation),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, size: 16),
                      onPressed: () async {
                        // 确认删除
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('删除对话'),
                            content: const Text('确定要删除这个对话吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirm == true) {
                          try {
                            await _conversationService.deleteConversation(conversation.id);
                            setState(() {
                              _conversations.removeAt(index);
                              if (_currentConversation?.id == conversation.id) {
                                _currentConversation = null;
                                _messages = [];
                              }
                            });
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('删除失败: $e')),
                              );
                            }
                          }
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _currentConversation == null
                ? const Center(child: Text('请选择或创建一个对话'))
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isUser = message.role == 'user';
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isUser ? Colors.blue : Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: isUser
                                  ? Text(
                                      message.content,
                                      style: const TextStyle(color: Colors.white),
                                    )
                                  : MarkdownBody(
                                      data: message.content,
                                      styleSheet: MarkdownStyleSheet(
                                        p: const TextStyle(color: Colors.black),
                                        h1: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
                                        h2: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
                                        h3: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
                                        h4: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                                        h5: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                                        h6: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
                                        code: TextStyle(
                                          backgroundColor: Colors.grey[200],
                                          fontFamily: 'monospace',
                                          color: Colors.black87,
                                        ),
                                        codeblockDecoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        blockquote: const TextStyle(color: Colors.black87, fontStyle: FontStyle.italic),
                                        listBullet: const TextStyle(color: Colors.black),
                                        tableBody: const TextStyle(color: Colors.black),
                                        a: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                                      ),
                                      selectable: true,
                                    ),
                            ),
                          );
                        },
                      ),
          ),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_isSending,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
