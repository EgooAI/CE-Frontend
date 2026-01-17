import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get_it/get_it.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/conversation.dart';
import '../repositories/conversation_repository.dart';
import '../services/conversation_service.dart';
import '../repositories/schedule_repository.dart';
import '../services/xfyun_asr_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/sync_queue_service.dart';
import '../widgets/create_schedule_bottom_sheet.dart';
import '../widgets/offline_banner.dart';
import '../widgets/sync_indicator.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ConversationRepository _conversationRepository =
      ConversationRepository();
  final ConversationService _conversationService = ConversationService();
  final ScheduleRepository _scheduleRepository = ScheduleRepository();
  final _syncQueue = GetIt.instance<SyncQueueService>();

  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  List<Message> _messages = [];
  List<String> _streamingThoughts = []; // 流式思考过程
  String _streamingContent = ''; // 流式内容
  StreamSubscription? _streamSub;
  bool _isLoading = false;
  bool _isSending = false;
  bool _isSyncing = false;
  int _pendingCount = 0;

  // 语音识别相关
  stt.SpeechToText? _speechToText; // iOS 语音识别
  XunfeiAsrService? _xunfeiAsr; // 科大讯飞语音识别（Android + Web）
  AudioRecorderService? _audioRecorder; // 音频录制服务

  // 滑动收起键盘相关
  double _lastScrollPosition = 0;
  DateTime? _lastScrollTime;
  bool _isListening = false; // 是否正在监听
  String _recognizedText = ''; // 已识别的文本（最终累积结果）
  String _tempRecognizedText = ''; // 临时识别文本（中间结果）

  // 搜索相关
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Conversation> _searchResults = [];
  String _searchError = '';

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _initVoiceInput();
    _listenToPendingCount();
    _searchController.addListener(_onSearchChanged);
  }

  /// 监听待同步任务数量
  void _listenToPendingCount() {
    _syncQueue.pendingCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _pendingCount = count;
        });
      }
    });
  }

  /// 初始化语音输入（根据平台选择不同实现）
  Future<void> _initVoiceInput() async {
    if (kIsWeb) {
      // Web：暂时不支持语音识别（record 插件不完全支持 Web）
      print('Web 平台语音识别功能暂未启用');
      return;
    }

    if (Platform.isAndroid) {
      // Android：使用科大讯飞 WebSocket API
      _xunfeiAsr = XunfeiAsrService(
        onResult: (text, isFinal) {
          setState(() {
            if (isFinal) {
              // 最终结果：累积到已确认文本
              _recognizedText += text;
              _tempRecognizedText = ''; // 清空临时文本
            } else {
              // 中间结果：仅保存到临时文本（会被下一次中间结果覆盖）
              _tempRecognizedText = text;
            }
            // 显示 = 已确认文本 + 临时文本
            _controller.text = _recognizedText + _tempRecognizedText;
          });
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('语音识别错误: $error')));
          }
        },
        onConnectionChanged: (connected) {
          if (!connected && _isListening) {
            setState(() => _isListening = false);
          }
        },
      );

      _audioRecorder = AudioRecorderService(
        onAudioData: (audioData) {
          // 将音频数据发送到科大讯飞
          _xunfeiAsr?.sendAudio(audioData);
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('录音错误: $error')));
          }
        },
      );
    } else if (Platform.isIOS) {
      // iOS：使用 speech_to_text 插件
      _speechToText = stt.SpeechToText();
      await _speechToText!.initialize(
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('语音识别错误: ${error.errorMsg}')),
            );
          }
        },
        onStatus: (status) {
          print('语音识别状态: $status');
          if (status == 'notListening' && _isListening) {
            setState(() => _isListening = false);
          }
        },
      );
    }
  }

  /// 开始语音识别
  Future<void> _startListening() async {
    if (_isListening) return;

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _tempRecognizedText = ''; // 清空临时文本
    });

    if (Platform.isIOS && _speechToText != null) {
      // iOS: 使用 speech_to_text
      await _speechToText!.listen(
        onResult: (result) {
          setState(() {
            if (result.finalResult) {
              // 最终结果：累积到已确认文本
              _recognizedText += result.recognizedWords;
              _tempRecognizedText = ''; // 清空临时文本
            } else {
              // 中间结果：仅保存到临时文本
              _tempRecognizedText = result.recognizedWords;
            }
            // 显示 = 已确认文本 + 临时文本
            _controller.text = _recognizedText + _tempRecognizedText;
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'zh_CN',
      );
    } else if ((kIsWeb || Platform.isAndroid) &&
        _xunfeiAsr != null &&
        _audioRecorder != null) {
      // Web 平台暂不支持音频录制
      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Web 平台语音识别功能开发中，请使用文字输入'),
              duration: Duration(seconds: 2),
            ),
          );
          setState(() => _isListening = false);
        }
        return;
      }

      // Android: 使用科大讯飞
      try {
        // 启动科大讯飞 WebSocket 连接
        await _xunfeiAsr!.start();

        // 启动录音并发送音频流
        final success = await _audioRecorder!.startRecording();
        if (!success) {
          setState(() => _isListening = false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('启动语音识别失败: $e')));
          setState(() => _isListening = false);
        }
      }
    }
  }

  /// 停止语音识别
  Future<void> _stopListening() async {
    if (!_isListening) return;

    if (Platform.isIOS && _speechToText != null) {
      await _speechToText!.stop();
    } else if ((kIsWeb || Platform.isAndroid) &&
        _xunfeiAsr != null &&
        _audioRecorder != null) {
      await _audioRecorder!.stopRecording();
      await _xunfeiAsr!.stop();
    }

    setState(() {
      _isListening = false;
    });
  }

  /// 切换语音识别状态
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await _conversationRepository.getConversations();
      setState(() {
        _conversations = conversations;
        // 如果有对话，自动进入最近一次的对话（首个为最近）
        if (_conversations.isNotEmpty && _currentConversation == null) {
          _currentConversation = _conversations.first;
          _isLoading = true;
        }
      });

      // 如果有对话，加载消息
      if (_conversations.isNotEmpty && _currentConversation != null) {
        try {
          final detail = await _conversationRepository.getConversationDetail(
            _currentConversation!.id,
          );
          setState(() {
            _messages = detail.messages ?? [];
            _isLoading = false;
          });
        } catch (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('加载对话失败: $e')));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载对话列表失败: $e')));
      }
    }
  }

  /// 搜索框内容变化监听
  void _onSearchChanged() {
    // 如果清空了搜索框，恢复显示全部会话
    if (_searchController.text.isEmpty && _isSearching) {
      _clearSearch();
    }
  }

  /// 执行搜索
  Future<void> _performSearch() async {
    final keyword = _searchController.text.trim();

    if (keyword.isEmpty) {
      _clearSearch();
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = '';
    });

    try {
      final results = await _conversationService.searchConversations(keyword);
      setState(() {
        _searchResults = results;
        if (_searchResults.isEmpty) {
          _searchError = '未搜索到相关会话';
        }
      });
    } catch (e) {
      setState(() {
        _searchError = '搜索失败: $e';
      });
    }
  }

  /// 清除搜索状态
  void _clearSearch() {
    setState(() {
      _isSearching = false;
      _searchResults = [];
      _searchError = '';
    });
  }

  Future<void> _createNewConversation({bool closeDrawer = false}) async {
    try {
      final conversation = await _conversationRepository.createConversation(
        "新对话",
      );
      setState(() {
        _conversations.insert(0, conversation); // 插入到最前面
        _currentConversation = conversation;
        _messages = [];
      });
      if (closeDrawer) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('创建对话失败: $e')));
      }
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
      final detail = await _conversationRepository.getConversationDetail(
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

  /// 根据第一条消息内容生成对话标题
  ///
  /// 流程：
  /// 1. 检查是否是第一条消息
  /// 2. 调用 API 生成标题（异步，不阻塞消息发送）
  /// 3. 生成成功后用新标题覆盖原有标题
  /// 4. 发生失败则保持原有标题
  Future<void> _generateAndUpdateTitle(String messageContent) async {
    if (_currentConversation == null) {
      print('[AutoTitle] ❌ 对话为空，无法生成标题');
      return;
    }

    try {
      print('[AutoTitle] 🚀 开始生成标题');
      print(
        '[AutoTitle] 📝 消息内容: ${messageContent.substring(0, min(messageContent.length, 50))}...',
      );
      print('[AutoTitle] 🔗 对话 ID: ${_currentConversation!.id}');
      print('[AutoTitle] 📌 当前标题: ${_currentConversation!.title}');

      final conversationService = GetIt.instance<ConversationService>();

      print('[AutoTitle] 📡 调用 API: POST /api/conversations/generate-title');
      final generatedTitle = await conversationService.generateTitle(
        messageContent,
      );

      print('[AutoTitle] ✅ 标题生成成功: $generatedTitle');

      if (!mounted) {
        print('[AutoTitle] ⚠️  Widget 已卸载，跳过 UI 更新');
        return;
      }

      // 用新标题覆盖原有标题
      setState(() {
        _currentConversation = _currentConversation!.copyWith(
          title: generatedTitle,
        );

        print('[AutoTitle] 🎨 UI 已更新，新标题: $generatedTitle');

        // 同时更新对话列表中的标题
        final index = _conversations.indexWhere(
          (c) => c.id == _currentConversation!.id,
        );
        if (index != -1) {
          _conversations[index] = _currentConversation!;
          print('[AutoTitle] 📋 对话列表已更新，位置: $index');
        }
      });

      // 异步更新后端和缓存（不需要等待）
      _updateConversationTitleInBackground(
        _currentConversation!.id,
        generatedTitle,
      );
    } catch (e) {
      print('[AutoTitle] ❌ 生成标题失败: $e');
      print('[AutoTitle] 💭 保持使用原有标题: ${_currentConversation!.title}');
    }
  }

  /// 后台更新对话标题到后端
  ///
  /// 这个方法在后台异步执行，不阻塞 UI
  void _updateConversationTitleInBackground(
    String conversationId,
    String newTitle,
  ) {
    // 后台异步更新（使用 microtask 模式）
    Future.microtask(() async {
      try {
        print('[BackgroundUpdate] 🔄 后台更新开始: 对话 ID = $conversationId');
        print('[BackgroundUpdate] 📝 新标题 = $newTitle');

        final conversationService = GetIt.instance<ConversationService>();

        // 调用 PUT 接口更新对话标题到后端
        // 注意：此方法的端点是 /conversations/$id/title
        final updatedConversation = await conversationService
            .updateConversationTitle(conversationId, newTitle);

        print('[BackgroundUpdate] ✅ 后台更新完成');
        print('[BackgroundUpdate] 💾 服务端返回标题: ${updatedConversation.title}');
      } catch (e) {
        print('[BackgroundUpdate] ❌ 后台更新失败: $e');
        // 失败不影响前端 UI，用户已经看到新标题了
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final content = _controller.text;
    _controller.clear();

    if (_currentConversation == null) {
      // 如果没有当前对话，先创建一个默认对话
      try {
        final conversation = await _conversationRepository.createConversation(
          "新对话",
        );
        setState(() {
          _conversations.insert(0, conversation);
          _currentConversation = conversation;
          _messages = [];
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('创建对话失败: $e')));
        }
        // 恢复输入内容
        _controller.text = content;
        return;
      }
    }

    // 检查是否是第一条消息（用于自动生成标题）
    final isFirstMessage = _messages.isEmpty;
    print(
      '[AutoTitle] 消息发送前检查 - 是否第一条消息: $isFirstMessage, 当前消息数: ${_messages.length}',
    );

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

    // 如果是第一条消息，异步生成标题（不阻塞消息发送）
    if (isFirstMessage) {
      _generateAndUpdateTitle(content);
    }

    try {
      // 使用流式接口
      _streamSub?.cancel();
      final conversationService = GetIt.instance<ConversationService>();
      _streamSub = conversationService
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
              } else if (event.type == 'schedule_parsed') {
                // AI 解析出日程数据，弹出确认对话框
                final scheduleData = event.data as Map<String, dynamic>;
                _handleScheduleParsed(scheduleData);
              } else if (event.type == 'content') {
                // 流式接收LLM生成的内容块
                final contentData = event.data as Map<String, dynamic>;
                final chunk = contentData['chunk'] as String? ?? '';

                // 兼容“全量覆盖”与“增量追加”两种服务端推送模式
                // 如果本次 chunk 以当前已显示内容开头，说明服务端推送的是“全量文本”，直接覆盖
                if (chunk.isNotEmpty) {
                  if (chunk.startsWith(_streamingContent)) {
                    _streamingContent = chunk;
                  } else {
                    // 否则按增量追加处理
                    _streamingContent += chunk;
                  }
                }

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

                    // 如果流式内容不为空，优先使用流式内容
                    if (_streamingContent.isNotEmpty) {
                      finalContent = _streamingContent;
                    }

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
                  _streamingContent = ''; // 清空流式内容
                });
                _scrollToBottom();
                _streamSub?.cancel();
              } else if (event.type == 'error') {
                // 错误处理
                final errorData = event.data as Map<String, dynamic>;
                final errorMsg = errorData['message'] ?? '未知错误';
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('错误: $errorMsg'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('流式发送失败: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
              // 移除临时 AI 消息
              setState(() {
                _messages.removeWhere((m) => m.id == tempAiMessageId);
                _streamingThoughts = [];
                _isSending = false;
              });
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

  /// 处理 AI 解析出的日程数据
  Future<void> _handleScheduleParsed(Map<String, dynamic> data) async {
    if (!mounted) return;

    // 显示日程创建底部抽屉
    showCreateScheduleBottomSheet(
      context,
      initialData: data,
      onSave: (schedule) async {
        try {
          // 调用 API 创建日程
          await _scheduleRepository.createSchedule(schedule);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ 日程创建成功'),
                duration: Duration(seconds: 2),
              ),
            );

            // 询问用户是否跳转到日历页面
            final shouldNavigate = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('日程已创建'),
                content: const Text('是否前往日历查看？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('留在聊天'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('查看日历'),
                  ),
                ],
              ),
            );

            if (shouldNavigate == true && mounted) {
              // 通过遍历 Widget 树查找 MainPage 的 State 并切换到日历页面
              Navigator.of(context).popUntil((route) => route.isFirst);

              // 查找祖先 context 中的 MainPage state 并调用公共方法
              context.visitAncestorElements((element) {
                if (element.widget.runtimeType.toString() == 'MainPage') {
                  final state = (element as StatefulElement).state;
                  // 调用公共方法切换到日历页面（索引 1）
                  try {
                    (state as dynamic).switchToPage(1);
                  } catch (e) {
                    debugPrint('切换到日历页面失败: $e');
                  }
                  return false; // 停止遍历
                }
                return true; // 继续遍历
              });
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ 创建日程失败: $e'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      },
    );
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

  Widget _buildWelcomeGuide() {
    // 判断是否应该显示完整教程：只有在没有对话列表时才显示完整教程
    final showFullGuide = _conversations.isEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 仅当没有对话列表时显示完整教程
            if (showFullGuide) ...[
              // 主图标
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 50,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 24),

              // 欢迎标题
              const Text(
                '👋 欢迎使用 懒得记',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // 副标题
              Text(
                '我可以帮你完成以下任务',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              // 功能卡片
              _buildFeatureCard(
                icon: Icons.calendar_today,
                title: '📅 智能日程管理',
                description: '你可以直接将通知信息复制到这里，也可以告诉我"明天下午3点开会"，我会自动为您解析日程',
                color: Colors.blue,
              ),
              const SizedBox(height: 16),

              _buildFeatureCard(
                icon: Icons.mic,
                title: '🎤 语音输入',
                description: '点击麦克风图标，用语音快速输入消息',
                color: Colors.orange,
              ),
              const SizedBox(height: 16),

              _buildFeatureCard(
                icon: Icons.psychology,
                title: '🤖 智能对话',
                description: '我会记住对话上下文，提供更精准的回答',
                color: Colors.purple,
              ),
              const SizedBox(height: 32),
            ],
            // 所有情况下都显示'试试这些问题'
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 20,
                        color: Colors.amber[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '试试这些问题',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildExampleChip('帮我安排明天上午10点的会议'),
                  const SizedBox(height: 8),
                  _buildExampleChip('提醒我下周五交报告'),
                  const SizedBox(height: 8),
                  _buildExampleChip('今天有什么安排？'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 开始提示
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_downward, size: 20, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Text(
                  '在下方输入框开始对话',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleChip(String text) {
    return InkWell(
      onTap: () {
        setState(() {
          _controller.text = text;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.arrow_forward, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
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

  Future<void> _editConversationTitle(
    Conversation conversation,
    int index,
  ) async {
    final TextEditingController titleController = TextEditingController(
      text: conversation.title,
    );

    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑对话标题'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(hintText: '输入新标题'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, titleController.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (newTitle != null &&
        newTitle.isNotEmpty &&
        newTitle != conversation.title) {
      try {
        final updatedConversation = await _conversationRepository
            .updateConversationTitle(conversation.id, newTitle);
        setState(() {
          _conversations[index] = updatedConversation;
          if (_currentConversation?.id == conversation.id) {
            _currentConversation = updatedConversation;
          }
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('更新标题失败: $e')));
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _streamSub?.cancel();

    // 清理语音资源
    _speechToText?.stop();
    _xunfeiAsr?.dispose();
    _audioRecorder?.dispose();

    super.dispose();
  }

  /// 构建会话列表（根据搜索状态显示不同内容）
  Widget _buildConversationList() {
    // 如果正在搜索，显示搜索结果
    if (_isSearching) {
      if (_searchError.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              _searchError,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }

      if (_searchResults.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text('未搜索到相关会话', style: TextStyle(color: Colors.grey)),
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.hardEdge,
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final conversation = _searchResults[index];
          return _buildConversationItem(conversation, index);
        },
      );
    }

    // 正常显示全部会话
    return ListView.builder(
      padding: EdgeInsets.all(8.0),
      clipBehavior: Clip.hardEdge,
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        return _buildConversationItem(conversation, index);
      },
    );
  }

  /// 构建单个会话项
  Widget _buildConversationItem(Conversation conversation, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: ListTile(
        title: Text(conversation.title),
        subtitle: Text(conversation.updatedAt.toString().split('.')[0]),
        selected: _currentConversation?.id == conversation.id,
        selectedTileColor: Colors.grey[300],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        onTap: () => _selectConversation(conversation, closeDrawer: true),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 16),
              onPressed: () => _editConversationTitle(conversation, index),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 16),
              onPressed: () async {
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
                    await _conversationRepository.deleteConversation(
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
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentConversation?.title ?? 'AI 助手'),
        titleTextStyle: const TextStyle(fontSize: 20, color: Colors.black),
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
        actions: [
          // 新建对话按钮
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createNewConversation(),
            tooltip: '新建对话',
          ),
          // 同步状态指示器
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SyncIndicator(isSyncing: true, size: 20),
            ),
        ],
      ),
      drawer: Drawer(
        width: 340,
        backgroundColor: Colors.grey[100],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(0)),
        ),
        child: Column(
          children: [
            // Status bar 背景填充
            Container(
              height: MediaQuery.of(context).viewPadding.top,
              color: Colors.grey[100],
            ),
            SafeArea(
              bottom: false,
              top: false,
              child: Container(
                color: Colors.grey[100],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: '搜索会话标题...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    _clearSearch();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[400]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[400]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.blue,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('新建对话'),
                      onTap: () => _createNewConversation(closeDrawer: true),
                    ),
                    const Divider(height: 1),
                  ],
                ),
              ),
            ),
            Expanded(child: ClipRect(child: _buildConversationList())),
          ],
        ),
      ),
      body: Column(
        children: [
          // 离线状态横幅
          OfflineBanner(showPendingCount: true, pendingCount: _pendingCount),
          // 主体内容
          Expanded(
            child: _currentConversation == null
                ? _buildWelcomeGuide()
                : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? _buildWelcomeGuide()
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification) {
                        final currentPosition = notification.metrics.pixels;
                        final currentTime = DateTime.now();

                        if (_lastScrollTime != null) {
                          // 计算滑动速度（像素/毫秒）
                          final deltaPosition = currentPosition - _lastScrollPosition;
                          final deltaTime = currentTime.difference(_lastScrollTime!).inMilliseconds;
                          
                          if (deltaTime > 0) {
                            final velocity = deltaPosition.abs() / deltaTime;
                            
                            // 只在向下快速滑动时收起键盘（速度 > 2 px/ms，约等于 2000 px/s）
                            if (deltaPosition > 0 && velocity > 2 && FocusScope.of(context).hasFocus) {
                              FocusScope.of(context).unfocus();
                            }
                          }
                        }

                        _lastScrollPosition = currentPosition;
                        _lastScrollTime = currentTime;
                      }
                      return false;
                    },
                    child: ListView.builder(
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
                                ? SelectableText(
                                    message.content,
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : _buildMessageContent(message.content),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),

          // 底部输入框
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: _isListening ? '监听中...' : '输入消息...',
                      hintStyle: TextStyle(
                        fontSize: 16,
                        color: _isListening ? Colors.blue : Colors.black38,
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                        borderSide: BorderSide(width: 1, color: Colors.black26),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                        borderSide: BorderSide(width: 1, color: Colors.black),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      // 添加麦克风按钮（Web 平台暂不支持）
                      suffixIcon: kIsWeb
                          ? null
                          : IconButton(
                              icon: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: _isListening ? Colors.red : Colors.grey,
                              ),
                              onPressed: _isSending ? null : _toggleListening,
                              tooltip: '语音输入',
                            ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_isSending,
                  ),
                ),
                const SizedBox(width: 6),
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
