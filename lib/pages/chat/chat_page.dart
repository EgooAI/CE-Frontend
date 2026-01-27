import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/chat/conversation.dart';
import '../../repositories/conversation_repository.dart';
import '../../services/chat/conversation_service.dart';
import '../../repositories/schedule_repository.dart';
import '../../services/sync/sync_queue_service.dart';
import '../../services/upload/image_upload_service.dart';
import '../../widgets/schedule/create_schedule_bottom_sheet.dart';
import '../../widgets/common/offline_banner.dart';
// import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/conversation_drawer.dart';
// import '../../widgets/chat/welcome_guide.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/image_preview_widget.dart';
import '../../widgets/chat/message_list_view.dart';
import '../../services/chat/voice_input_service.dart';
import '../../services/chat/stream_message_handler.dart';
import '../../utils/app_keys.dart';

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
  int _pendingCount = 0;

  // 语音识别相关
  final VoiceInputService _voiceInput = VoiceInputService();

  // 图片上传相关
  final ImagePicker _imagePicker = ImagePicker();
  final ImageUploadService _imageUploadService = ImageUploadService();
  final List<ImageAttachment> _images = [];

  // 搜索相关
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Conversation> _searchResults = [];
  String _searchError = '';

  @override
  void initState() {
    super.initState();
    _loadConversations(staleWhileRevalidate: true);
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
    await _voiceInput.initialize(
      onResult: (text, isFinal) {
        if (mounted) {
          setState(() {
            _controller.text = text;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('语音识别错误: $error')));
        }
      },
    );
  }

  /// 切换语音识别状态
  Future<void> _toggleListening() async {
    final success = await _voiceInput.toggleListening(
      onResult: (text, isFinal) {
        if (mounted) {
          setState(() {
            _controller.text = text;
          });
        }
      },
    );

    if (!success && !_voiceInput.isListening) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Web 平台语音识别功能开发中，请使用文字输入'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    setState(() {});
  }

  Future<void> _startListening() async {
    final success = await _voiceInput.startListening(
      onResult: (text, isFinal) {
        if (mounted) {
          setState(() {
            _controller.text = text;
          });
        }
      },
    );

    if (!success && !_voiceInput.isListening) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Web 平台语音识别功能开发中，请使用文字输入'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _stopListening() async {
    await _voiceInput.stopListening();
    if (mounted) {
      setState(() {});
    }
  }

  /// 从相册选择图片
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        await _handleImageSelected(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
      }
    }
  }

  /// 拍照
  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        await _handleImageSelected(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('拍照失败: $e')));
      }
    }
  }

  /// 处理选中的图片
  Future<void> _handleImageSelected(XFile xfile) async {
    // 添加到列表（显示上传中状态）
    final file = File(xfile.path);
    final fileName = xfile.path.split('/').last;

    print('[ImageUpload] 📸 开始处理图片');
    print('[ImageUpload] 📁 文件路径: ${xfile.path}');
    print('[ImageUpload] 📝 文件名: $fileName');
    print('[ImageUpload] 📊 文件大小: ${await file.length()} 字节');

    setState(() {
      _images.add(
        ImageAttachment(file: file, name: fileName, isUploading: true),
      );
    });

    final index = _images.length - 1;

    // 上传图片
    try {
      print('[ImageUpload] 🚀 开始上传到服务器...');
      final imageInfo = await _imageUploadService.uploadImage(file);

      print('[ImageUpload] ✅ 上传成功！');
      print('[ImageUpload] 🔑 Key: ${imageInfo.key}');
      print('[ImageUpload] 🔗 URL: ${imageInfo.url}');
      print('[ImageUpload] 📏 大小: ${imageInfo.size} 字节');

      // 更新为上传成功状态（同时保存 key 和 url）
      setState(() {
        _images[index] = _images[index].copyWith(
          key: imageInfo.key, // OSS对象Key（永久有效）
          url: imageInfo.url, // 预签名URL（12小时有效）
          isUploading: false,
        );
      });
    } catch (e, stackTrace) {
      // 详细的错误日志
      print('[ImageUpload] ❌ 上传失败！');
      print('[ImageUpload] 错误类型: ${e.runtimeType}');
      print('[ImageUpload] 错误信息: $e');
      print('[ImageUpload] 堆栈跟踪:\n$stackTrace');

      // 更新为上传失败状态
      setState(() {
        _images[index] = _images[index].copyWith(
          isUploading: false,
          error: e.toString(),
        );
      });

      if (mounted) {
        // 显示更详细的错误信息
        final errorMessage = e.toString().contains('Exception:')
            ? e.toString().replaceFirst('Exception: ', '')
            : e.toString();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('图片上传失败: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '查看日志',
              textColor: Colors.white,
              onPressed: () {
                print('[ImageUpload] 用户查看完整错误信息');
                print('[ImageUpload] 完整错误: $e');
              },
            ),
          ),
        );
      }
    }
  }

  /// 删除图片
  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _handlePastedImage(Uint8List bytes, {String? filename}) async {
    final name =
        filename ?? 'paste_${DateTime.now().millisecondsSinceEpoch}.png';

    setState(() {
      _images.add(ImageAttachment(bytes: bytes, name: name, isUploading: true));
    });

    final index = _images.length - 1;

    try {
      final imageInfo = await _imageUploadService.uploadImageBytes(
        bytes,
        filename: name,
      );

      setState(() {
        _images[index] = _images[index].copyWith(
          key: imageInfo.key,
          url: imageInfo.url,
          isUploading: false,
        );
      });
    } catch (e, stackTrace) {
      print('[ImageUpload] ❌ 粘贴图片上传失败！');
      print('[ImageUpload] 错误类型: ${e.runtimeType}');
      print('[ImageUpload] 错误信息: $e');
      print('[ImageUpload] 堆栈跟踪:\n$stackTrace');

      setState(() {
        _images[index] = _images[index].copyWith(
          isUploading: false,
          error: e.toString(),
        );
      });

      if (mounted) {
        final errorMessage = e.toString().contains('Exception:')
            ? e.toString().replaceFirst('Exception: ', '')
            : e.toString();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('图片上传失败: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// 刷新会话列表（Drawer 打开时调用）
  ///
  /// 先展示当前列表，再后台强刷：
  /// - 优先缓存秒开
  /// - 强刷后若有更新则动态更新
  Future<void> _refreshConversationList() async {
    print('[ChatPage] 🔄 Drawer 打开，后台强刷会话列表...');
    _refreshConversationsInBackground();
  }

  Future<void> _loadCurrentConversationDetail({
    bool forceRefresh = false,
  }) async {
    if (_currentConversation == null) return;

    try {
      final detail = await _conversationRepository.getConversationDetail(
        _currentConversation!.id,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(detail.messages ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载对话失败: $e')));
      }
    }
  }

  Future<void> _refreshConversationsInBackground() async {
    try {
      final conversations = await _conversationRepository.getConversations(
        forceRefresh: false,
      );

      if (!mounted) return;

      setState(() {
        _conversations = conversations;
        if (_conversations.isNotEmpty && _currentConversation == null) {
          _currentConversation = _conversations.first;
          _isLoading = true;
        }
      });

      await _loadCurrentConversationDetail(forceRefresh: false);
    } catch (_) {
      // 静默失败：保留缓存内容
    }
  }

  Future<void> _loadConversations({
    bool forceRefresh = false,
    bool staleWhileRevalidate = false,
  }) async {
    if (staleWhileRevalidate) {
      final cachedConversations = await _conversationRepository
          .getCachedConversations();

      if (cachedConversations != null) {
        setState(() {
          _conversations = cachedConversations;
          // 如果有对话，自动进入最近一次的对话（首个为最近）
          if (_conversations.isNotEmpty && _currentConversation == null) {
            _currentConversation = _conversations.first;
            _isLoading = true;
          }
        });

        await _loadCurrentConversationDetail();
      }

      // 后台强刷，获取最新数据并动态更新
      _refreshConversationsInBackground();
      return;
    }

    try {
      final conversations = await _conversationRepository.getConversations(
        forceRefresh: forceRefresh,
      );
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
        await _loadCurrentConversationDetail(forceRefresh: forceRefresh);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载对话列表失败: $e')));
      }
    }
  }

  /// 刷新当前会话（下拉刷新使用）
  Future<void> _refreshCurrentConversation() async {
    if (_currentConversation == null) return;

    try {
      print('[ChatPage] 🔄 开始刷新当前会话...');
      final detail = await _conversationRepository.getConversationDetail(
        _currentConversation!.id,
        forceRefresh: true, // 强制从服务器获取最新数据
      );

      if (mounted) {
        setState(() {
          _messages = detail.messages ?? [];
        });
        print('[ChatPage] ✅ 会话刷新成功，消息数: ${_messages.length}');
      }
    } catch (e) {
      print('[ChatPage] ❌ 会话刷新失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刷新失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
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
    if (_controller.text.trim().isEmpty && _images.isEmpty) return;

    final content = _controller.text;
    final messageImages = List<ImageAttachment>.from(_images);
    _controller.clear();

    // 清空图片列表
    setState(() {
      _images.clear();
    });

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
        setState(() {
          _images.addAll(messageImages);
        });
        return;
      }
    }

    // 检查是否是第一条消息（用于自动生成标题）
    final isFirstMessage = _messages.isEmpty;
    print(
      '[AutoTitle] 消息发送前检查 - 是否第一条消息: $isFirstMessage, 当前消息数: ${_messages.length}',
    );

    // 构建附件数据（使用 key 而不是 url）
    Map<String, dynamic>? attachments;
    if (messageImages.isNotEmpty) {
      attachments = {
        'images': messageImages
            .where((img) => img.key != null) // 确保 key 存在
            .map(
              (img) => {
                'key': img.key!, // 存储 key 到数据库
                'name': img.name,
              },
            )
            .toList(),
      };
    }

    // 添加临时用户消息
    final tempUserMessage = Message(
      id: 'temp_user_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: content,
      conversationId: _currentConversation!.id,
      createdAt: DateTime.now(),
      attachments: attachments != null ? jsonEncode(attachments) : null,
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

      // 创建流式消息处理器
      final handler = StreamMessageHandler(
        messages: _messages,
        tempAiMessageId: tempAiMessageId,
        conversationId: _currentConversation!.id,
        streamingThoughts: _streamingThoughts,
        streamingContent: _streamingContent,
        onUpdate: () => setState(() {}),
        onScrollToBottom: _scrollToBottom,
      );

      _streamSub = conversationService
          .sendMessageStream(
            _currentConversation!.id,
            content,
            attachments: attachments != null ? jsonEncode(attachments) : null,
          )
          .listen(
            (event) {
              if (!mounted) return;

              switch (event.type) {
                case 'user_message':
                  handler.handleUserMessage(
                    event.data as Message,
                    tempUserMessage.id,
                  );
                  break;

                case 'progress':
                  handler.handleProgress(event.data as Map<String, dynamic>);
                  break;

                case 'tool_call':
                  handler.handleToolCall(event.data as Map<String, dynamic>);
                  break;

                case 'tool_result':
                  handler.handleToolResult(event.data as Map<String, dynamic>);
                  break;

                case 'schedule_parsed':
                  _handleScheduleParsed(event.data as Map<String, dynamic>);
                  break;

                case 'content':
                  handler.handleContent(event.data as Map<String, dynamic>);
                  // 更新流式内容引用
                  _streamingContent = handler.streamingContent;
                  break;

                case 'done':
                  handler.handleDone(event.data as Message);
                  _streamSub?.cancel();
                  break;

                case 'error':
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
                  handler.handleError();
                  _streamSub?.cancel();
                  break;
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
              final mainState = mainPageKey.currentState;
              if (mainState != null && mainState.mounted) {
                Future.microtask(() {
                  try {
                    (mainState as dynamic).navigateToScheduleDate(
                      schedule.startTime,
                    );
                  } catch (e) {
                    debugPrint('切换到日历页面失败: $e');
                  }
                });
              }
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

  Future<void> _handleDeleteConversation(
    Conversation conversation,
    int index,
  ) async {
    try {
      await _conversationRepository.deleteConversation(conversation.id);
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

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _streamSub?.cancel();

    // 清理语音资源
    _voiceInput.dispose();

    super.dispose();
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
        ],
      ),
      onDrawerChanged: (isOpened) {
        // Drawer 打开时自动刷新会话列表
        if (isOpened) {
          print('[ChatPage] 📂 Drawer 已打开，刷新会话列表...');
          _refreshConversationList();
        }
      },
      drawer: ConversationDrawer(
        searchController: _searchController,
        isSearching: _isSearching,
        conversations: _conversations,
        searchResults: _searchResults,
        searchError: _searchError,
        currentConversation: _currentConversation,
        onCreateConversation: () => _createNewConversation(closeDrawer: true),
        onPerformSearch: _performSearch,
        onClearSearch: _clearSearch,
        onSelectConversation: _selectConversation,
        onEditConversationTitle: _editConversationTitle,
        onDeleteConversation: _handleDeleteConversation,
      ),
      body: Column(
        children: [
          // 离线状态横幅
          OfflineBanner(showPendingCount: true, pendingCount: _pendingCount),
          // 主体内容
          Expanded(
            child: MessageListView(
              currentConversation: _currentConversation,
              messages: _messages,
              isLoading: _isLoading,
              showFullGuide: _conversations.isEmpty,
              onExampleTap: (text) {
                setState(() {
                  _controller.text = text;
                });
              },
              scrollController: _scrollController,
              onRefresh: _refreshCurrentConversation,
            ),
          ),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),

          // 底部输入框
          ChatInputBar(
            controller: _controller,
            isListening: _voiceInput.isListening,
            isSending: _isSending,
            onSend: _sendMessage,
            onToggleListening: _toggleListening,
            onStartListening: _startListening,
            onStopListening: _stopListening,
            images: _images,
            onPickImage: _pickImage,
            onTakePhoto: _takePhoto,
            onRemoveImage: _removeImage,
            onPasteImage: _handlePastedImage,
          ),
        ],
      ),
    );
  }
}
