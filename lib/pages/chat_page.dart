import 'dart:async';
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
  List<String> _streamingThoughts = []; // 流式思考过程
  String _streamingContent = ''; // 流式内容
  StreamSubscription? _streamSub;
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
        // 如果没有对话，自动创建一个默认对话
        if (_conversations.isEmpty && _currentConversation == null) {
          _createDefaultConversation();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载对话列表失败: $e')));
      }
    }
  }

  Future<void> _createDefaultConversation() async {
    try {
      final conversation = await _conversationService.createConversation(
        "默认对话",
      );
      setState(() {
        _conversations.add(conversation);
        _currentConversation = conversation;
        _messages = [];
      });
    } catch (e) {
      // 静默失败，不显示错误，因为这不是用户主动操作
    }
  }

  Future<void> _selectConversation(
    Conversation conversation, {
    bool closeDrawer = false,
  }) async {
    setState(() {
      _currentConversation = conversation;
      _messages = []; // 清空当前显示的消息
      _isLoading = true;
    });

    if (closeDrawer) {
      Navigator.pop(context);
    }

    try {
      // 获取对话详情（包含消息）
      final detail = await _conversationService.getConversation(
        conversation.id,
      );

      setState(() {
        _messages = detail.messages ?? [];
      });

      // 滚动到底部
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载对话详情失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createNewConversation({bool closeDrawer = false}) async {
    try {
      final conversation = await _conversationService.createConversation("新对话");
      setState(() {
        _conversations.insert(0, conversation);
        _currentConversation = conversation;
        _messages = [];
      });
      if (closeDrawer) {
        Navigator.pop(context); // 关闭侧边栏
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('创建对话失败: $e')));
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    if (_currentConversation == null) {
      // 如果没有当前对话，先创建一个默认对话
      await _createDefaultConversation();
      if (_currentConversation == null) return;
    }

    final content = _controller.text;
    _controller.clear();

    // 添加临时用户消息
    final tempUserMessage = Message(
      id: 'temp_user_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: content,
      conversationId: _currentConversation!.id,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(tempUserMessage);
      _isSending = true;
    });

    _scrollToBottom();

    // 添加临时 AI 消息占位符
    final tempAiMessageId = 'temp_ai_${DateTime.now().millisecondsSinceEpoch}';
    final tempAiMessage = Message(
      id: tempAiMessageId,
      role: 'assistant',
      content: '正在思考...',
      conversationId: _currentConversation!.id,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(tempAiMessage);
    });

    _scrollToBottom();

    // 清空思考过程和流式内容
    _streamingThoughts = [];
    _streamingContent = '';

    try {
      // 使用流式接口
      _streamSub?.cancel();
      _streamSub = _conversationService
          .sendMessageStream(_currentConversation!.id, content)
          .listen(
            (event) {
              if (!mounted) return;

              if (event.type == 'user_message') {
                // 用真实的用户消息替换临时消息
                final realUserMessage = event.data as Message;
                setState(() {
                  final index = _messages.indexWhere(
                    (m) => m.id == tempUserMessage.id,
                  );
                  if (index != -1) {
                    _messages[index] = realUserMessage;
                  }
                });
              } else if (event.type == 'progress') {
                // 添加进度到思考过程
                final progressData = event.data as Map<String, dynamic>;
                final progressMsg = progressData['message'] ?? '正在思考...';
                setState(() {
                  _streamingThoughts.add('💭 $progressMsg');
                  // 更新临时消息显示思考过程
                  final index = _messages.indexWhere(
                    (m) => m.id == tempAiMessageId,
                  );
                  if (index != -1) {
                    _messages[index] = Message(
                      id: tempAiMessageId,
                      role: 'assistant',
                      content: _streamingThoughts.join('\n'),
                      conversationId: _currentConversation!.id,
                      createdAt: DateTime.now(),
                    );
                  }
                });
                _scrollToBottom();
              } else if (event.type == 'tool_call') {
                // 添加工具调用信息到思考过程
                final toolData = event.data as Map<String, dynamic>;
                final toolName = toolData['tool'] ?? 'unknown';
                final toolArgs = toolData['args'] ?? '';
                setState(() {
                  _streamingThoughts.add('🔧 调用工具: $toolName');
                  if (toolArgs.toString().isNotEmpty &&
                      toolArgs.toString() != '{}') {
                    _streamingThoughts.add('   参数: $toolArgs');
                  }
                  // 更新临时消息
                  final index = _messages.indexWhere(
                    (m) => m.id == tempAiMessageId,
                  );
                  if (index != -1) {
                    _messages[index] = Message(
                      id: tempAiMessageId,
                      role: 'assistant',
                      content: _streamingThoughts.join('\n'),
                      conversationId: _currentConversation!.id,
                      createdAt: DateTime.now(),
                    );
                  }
                });
                _scrollToBottom();
              } else if (event.type == 'tool_result') {
                // 添加工具执行结果到思考过程
                final toolData = event.data as Map<String, dynamic>;
                final toolName = toolData['tool'] ?? 'unknown';
                final result = toolData['result'] ?? '';
                setState(() {
                  _streamingThoughts.add('✅ $toolName 执行完成');
                  if (result.toString().isNotEmpty) {
                    _streamingThoughts.add('   结果: $result');
                  }
                  // 更新临时消息
                  final index = _messages.indexWhere(
                    (m) => m.id == tempAiMessageId,
                  );
                  if (index != -1) {
                    _messages[index] = Message(
                      id: tempAiMessageId,
                      role: 'assistant',
                      content: _streamingThoughts.join('\n'),
                      conversationId: _currentConversation!.id,
                      createdAt: DateTime.now(),
                    );
                  }
                });
                _scrollToBottom();
              } else if (event.type == 'content') {
                // 流式接收LLM生成的内容块
                final contentData = event.data as Map<String, dynamic>;
                final chunk = contentData['chunk'] as String? ?? '';
                _streamingContent += chunk;

                setState(() {
                  final index = _messages.indexWhere(
                    (m) => m.id == tempAiMessageId,
                  );
                  if (index != -1) {
                    // 显示思考过程 + 当前流式内容
                    String displayContent = '';
                    if (_streamingThoughts.isNotEmpty) {
                      displayContent =
                          '**思考过程:**\n```\n${_streamingThoughts.join('\n')}\n```\n\n---\n\n';
                    }
                    displayContent += _streamingContent;

                    _messages[index] = Message(
                      id: tempAiMessageId,
                      role: 'assistant',
                      content: displayContent,
                      conversationId: _currentConversation!.id,
                      createdAt: DateTime.now(),
                    );
                  }
                });
                _scrollToBottom();
              } else if (event.type == 'done') {
                // AI 回复完成，保存最终消息
                final finalMessage = event.data as Message;
                setState(() {
                  final index = _messages.indexWhere(
                    (m) => m.id == tempAiMessageId,
                  );
                  if (index != -1) {
                    // 如果有思考过程，在最终消息前添加思考过程
                    String finalContent = finalMessage.content;
                    if (_streamingThoughts.isNotEmpty) {
                      finalContent =
                          '**思考过程:**\n```\n${_streamingThoughts.join('\n')}\n```\n\n---\n\n$finalContent';
                    }
                    _messages[index] = Message(
                      id: finalMessage.id,
                      role: finalMessage.role,
                      content: finalContent,
                      conversationId: finalMessage.conversationId,
                      createdAt: finalMessage.createdAt,
                      attachments: finalMessage.attachments,
                      metadata: finalMessage.metadata,
                    );
                  }
                  _streamingThoughts = [];
                });
                _scrollToBottom();
                _streamSub?.cancel();
              } else if (event.type == 'error') {
                // 错误处理
                final errorData = event.data as Map<String, dynamic>;
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('错误: ${errorData['message']}')),
                  );
                }
                // 移除临时 AI 消息
                setState(() {
                  _messages.removeWhere((m) => m.id == tempAiMessageId);
                  _streamingThoughts = [];
                });
                _streamSub?.cancel();
              }
            },
            onError: (e) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('流式发送失败: $e')));
              }
              setState(() => _isSending = false);
            },
            onDone: () {
              if (mounted) setState(() => _isSending = false);
            },
            cancelOnError: true,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发送消息失败: $e')));
        // 移除临时 AI 消息
        setState(() {
          _messages.removeWhere((m) => m.id == tempAiMessageId);
          _streamingThoughts = [];
        });
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

  Widget _buildMessageContent(String content) {
    // 检查是否包含思考过程
    if (content.contains('**思考过程:**')) {
      final parts = content.split('\n---\n');
      if (parts.length >= 2) {
        final thinkingPart = parts[0]
            .replaceAll('**思考过程:**', '')
            .replaceAll('```', '')
            .trim();
        final contentPart = parts.sublist(1).join('\n---\n').trim();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 思考过程区域 - 可折叠
            Theme(
              data: ThemeData(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(left: 8, top: 4),
                title: Row(
                  children: [
                    Icon(Icons.psychology, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      '思考过程',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                initiallyExpanded: false,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _buildThinkingProcess(thinkingPart),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 实际回复内容
            MarkdownBody(
              data: contentPart,
              styleSheet: _getMarkdownStyleSheet(),
              selectable: true,
            ),
          ],
        );
      }
    }

    // 没有思考过程，直接显示内容
    return MarkdownBody(
      data: content,
      styleSheet: _getMarkdownStyleSheet(),
      selectable: true,
    );
  }

  Widget _buildThinkingProcess(String thinkingText) {
    final lines = thinkingText
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmedLine = line.trim();

        // 进度消息
        if (trimmedLine.startsWith('💭')) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Text('💭', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    trimmedLine.substring(2).trim(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // 工具调用
        if (trimmedLine.startsWith('🔧')) {
          final toolInfo = trimmedLine.substring(2).trim();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.build, size: 14, color: Colors.blue[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      toolInfo,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 工具结果
        if (trimmedLine.startsWith('✅')) {
          final resultInfo = trimmedLine.substring(2).trim();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: Colors.green[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      resultInfo,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.green[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 参数或结果详情（缩进的行）
        if (trimmedLine.startsWith('参数:') || trimmedLine.startsWith('结果:')) {
          return Padding(
            padding: const EdgeInsets.only(left: 20, top: 2, bottom: 2),
            child: Text(
              trimmedLine,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
          );
        }

        // 其他文本
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            trimmedLine,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        );
      }).toList(),
    );
  }

  MarkdownStyleSheet _getMarkdownStyleSheet() {
    return MarkdownStyleSheet(
      p: const TextStyle(color: Colors.black, fontSize: 14),
      h1: const TextStyle(
        color: Colors.black,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      h2: const TextStyle(
        color: Colors.black,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      h3: const TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      h4: const TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      h5: const TextStyle(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      h6: const TextStyle(
        color: Colors.black,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      code: TextStyle(
        backgroundColor: Colors.grey[200],
        fontFamily: 'monospace',
        color: Colors.black87,
        fontSize: 13,
      ),
      codeblockDecoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      codeblockPadding: const EdgeInsets.all(8),
      blockquote: const TextStyle(
        color: Colors.black87,
        fontStyle: FontStyle.italic,
      ),
      listBullet: const TextStyle(color: Colors.black),
      tableBody: const TextStyle(color: Colors.black),
      a: const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),
    );
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
              onTap: () => _createNewConversation(closeDrawer: true),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final conversation = _conversations[index];
                  return ListTile(
                    title: Text(conversation.title),
                    subtitle: Text(
                      conversation.updatedAt.toString().split('.')[0],
                    ),
                    selected: _currentConversation?.id == conversation.id,
                    onTap: () =>
                        _selectConversation(conversation, closeDrawer: true),
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
                            await _conversationService.deleteConversation(
                              conversation.id,
                            );
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
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
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
                              : _buildMessageContent(message.content),
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
