import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/chat/conversation.dart';
import '../../models/chat/stream_session.dart';
import '../../models/schedule/schedule.dart';
import '../../repositories/conversation_repository.dart';
import '../../services/chat/conversation_service.dart';
import '../../repositories/schedule_repository.dart';
import '../../services/sync/sync_queue_service.dart';
import '../../services/upload/image_upload_service.dart';
import '../../utils/crud_force_refresh.dart';
import '../../widgets/common/offline_banner.dart';
// import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/conversation_drawer.dart';
// import '../../widgets/chat/welcome_guide.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/image_preview_widget.dart';
import '../../widgets/chat/message_list_view.dart';
import '../../widgets/chat/schedule_confirm_card.dart';
import '../../services/chat/voice_input_service.dart';
import '../../utils/app_keys.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
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
  StreamSession? _streamSession;
  String? _activeStreamingMessageId;
  String? _transientThinkingText;
  bool _bubbleReady = false;
  int _suppressedBubbleChunks = 0;
  bool _streamInterruptedByUser = false;
  Map<String, dynamic>? _pendingScheduleParsed;
  bool _isCreatingSchedule = false;
  StreamSubscription? _streamSub;
  bool _isLoading = false;
  bool _isSending = false;
  int _pendingCount = 0;
  bool _showScrollToBottom = false;
  bool _todaySummaryInsertedThisForeground = false;
  bool _todaySummaryInserting = false;

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
    WidgetsBinding.instance.addObserver(this);
    _loadConversations(staleWhileRevalidate: true);
    _initVoiceInput();
    _listenToPendingCount();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atBottom = position.maxScrollExtent - position.pixels <= 20.0;
    final shouldShow = !atBottom;
    if (shouldShow != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = shouldShow;
      });
    }
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
      final localEntries = _extractLocalSummaryMessages(_messages);
      final detail = await _conversationRepository.getConversationDetail(
        _currentConversation!.id,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(detail.messages ?? [])
            ..addAll(localEntries);
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
      _insertTodaySummaryEntryIfNeeded();
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
      if (cachedConversations != null) {
        _insertTodaySummaryEntryIfNeeded();
      }
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
      _insertTodaySummaryEntryIfNeeded();
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
      final localEntries = _extractLocalSummaryMessages(_messages);
      final detail = await _conversationRepository.getConversationDetail(
        _currentConversation!.id,
        forceRefresh: true, // 强制从服务器获取最新数据
      );

      if (mounted) {
        setState(() {
          _messages = [...(detail.messages ?? []), ...localEntries];
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
      _insertTodaySummaryEntryIfNeeded();
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
    final isFirstMessage = !_messages.any(
      (m) => m.role == 'user' || m.role == 'assistant',
    );
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
      _streamSession = StreamSession();
      _activeStreamingMessageId = tempAiMessageId;
      _transientThinkingText = '正在理解你的问题…';
      _bubbleReady = false;
      _suppressedBubbleChunks = 0;
      _streamInterruptedByUser = false;
      _pendingScheduleParsed = null;
    });

    _scrollToBottom();

    // 如果是第一条消息，异步生成标题（不阻塞消息发送）
    if (isFirstMessage) {
      _generateAndUpdateTitle(content);
    }

    try {
      // 使用流式接口
      _streamSub?.cancel();
      final conversationService = GetIt.instance<ConversationService>();
      final legacyToolStepByName = <String, String>{};

      _streamSub = conversationService
          .sendMessageStream(
            _currentConversation!.id,
            content,
            attachments: attachments != null ? jsonEncode(attachments) : null,
          )
          .listen(
            (event) {
              if (!mounted) return;

              _handleStreamEvent(
                event,
                tempAiMessageId: tempAiMessageId,
                tempUserMessageId: tempUserMessage.id,
                legacyToolStepByName: legacyToolStepByName,
              );
            },
            onError: (e) {
              _onStreamError('流式发送失败: $e');
            },
            onDone: () {
              if (!mounted) return;
              if (_streamInterruptedByUser) {
                _streamInterruptedByUser = false;
                return;
              }
              if (_streamSession?.phase != StreamPhase.done) {
                _onStreamError('连接已断开');
                return;
              }
              setState(() => _isSending = false);
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
          _activeStreamingMessageId = null;
          _streamSession = null;
          _transientThinkingText = null;
          _isSending = false;
          _streamInterruptedByUser = false;
        });
      }
    }
  }

  void _handleStreamEvent(
    StreamEvent event, {
    required String tempAiMessageId,
    required String tempUserMessageId,
    required Map<String, String> legacyToolStepByName,
  }) {
    final map = _toMap(event.data);
    switch (event.type) {
      case 'user_message':
        final data = event.data;
        if (data is Message) {
          final index = _messages.indexWhere((m) => m.id == tempUserMessageId);
          if (index != -1) {
            setState(() => _messages[index] = data);
          }
        }
        break;
      case 'session_start':
        _onSessionStart(map);
        break;
      case 'thinking_step':
        _onThinkingStep(map);
        break;
      case 'action_start':
        _onActionStart(map);
        break;
      case 'action_result':
        _onActionResult(map);
        break;
      case 'schedule_parsed':
        _onScheduleParsed(map);
        break;
      case 'answer_delta':
        _onAnswerDelta(map);
        break;
      case 'warning':
        _onWarning(map);
        break;
      case 'final':
      case 'done':
        _onFinal(event.data, tempAiMessageId: tempAiMessageId);
        _streamSub?.cancel();
        break;
      case 'error':
        _onStreamError(map['message']?.toString() ?? '出现错误，请重试');
        break;

      // 旧协议兼容
      case 'progress':
        _onThinkingStep({
          'stepId': _genStepId(),
          'text': map['message']?.toString() ?? '正在思考…',
        });
        break;
      case 'tool_call':
        final tool = map['tool']?.toString() ?? 'tool';
        final stepId = _genStepId();
        legacyToolStepByName[tool] = stepId;
        _onActionStart({'stepId': stepId, 'display': '调用工具：$tool'});
        break;
      case 'tool_result':
        final tool = map['tool']?.toString();
        String? stepId = tool == null ? null : legacyToolStepByName[tool];
        stepId ??= _findLastPendingActionStepId();
        _onActionResult({
          'stepId': stepId ?? _genStepId(),
          'summary': map['result']?.toString() ?? '执行完成',
        });
        break;
      case 'content':
        _onAnswerDelta({'delta': map['chunk']?.toString() ?? ''});
        break;
    }
  }

  StreamSession _ensureStreamSession() {
    return _streamSession ??= StreamSession();
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _genStepId() => 'step_${DateTime.now().microsecondsSinceEpoch}';

  String? _findLastPendingActionStepId() {
    final session = _streamSession;
    if (session == null) return null;
    for (var i = session.steps.length - 1; i >= 0; i--) {
      final step = session.steps[i];
      if (step.type == ProcessStepType.action &&
          step.status == ProcessStepStatus.pending) {
        return step.stepId;
      }
    }
    return null;
  }

  bool _hasPendingActionStep() {
    final session = _streamSession;
    if (session == null) return false;
    return session.steps.any(
      (step) =>
          step.type == ProcessStepType.action &&
          step.status == ProcessStepStatus.pending,
    );
  }

  bool _looksLikeToolPayload(String chunk) {
    final text = chunk.trim();
    if (text.isEmpty) return false;
    if (text.startsWith('{') && text.endsWith('}')) return true;
    if (text.startsWith('```json') || text.contains('```json')) return true;
    if (text.contains('"tool"') ||
        text.contains('"arguments"') ||
        text.contains('"result"')) {
      return true;
    }
    if (text.contains('tool_call') || text.contains('tool_result')) return true;
    return false;
  }

  String _thinkingTextFromDelta(String chunk) {
    final text = chunk.trim();
    if (text.isEmpty) return '正在执行操作…';
    if (text.length <= 40) return text;
    return '${text.substring(0, 40)}…';
  }

  void _onSessionStart(Map<String, dynamic> data) {
    setState(() {
      final session = _ensureStreamSession();
      session
        ..traceId = data['traceId']?.toString()
        ..messageId = data['messageId']?.toString()
        ..phase = StreamPhase.init;
      _transientThinkingText = '正在理解你的问题…';
    });
  }

  void _onThinkingStep(Map<String, dynamic> data) {
    final text =
        data['text']?.toString() ?? data['message']?.toString() ?? '正在思考…';
    setState(() {
      final session = _ensureStreamSession();
      session.steps.add(
        ProcessStep(
          stepId: data['stepId']?.toString() ?? _genStepId(),
          type: ProcessStepType.thinking,
          text: text,
          status: ProcessStepStatus.done,
        ),
      );
      session.phase = StreamPhase.thinking;
      _transientThinkingText = text;
    });
    _scrollToBottom();
  }

  void _onActionStart(Map<String, dynamic> data) {
    final text =
        data['display']?.toString() ??
        data['text']?.toString() ??
        data['tool']?.toString() ??
        '执行工具中…';
    setState(() {
      final session = _ensureStreamSession();
      session.steps.add(
        ProcessStep(
          stepId: data['stepId']?.toString() ?? _genStepId(),
          type: ProcessStepType.action,
          text: text,
          status: ProcessStepStatus.pending,
        ),
      );
      session.phase = StreamPhase.acting;
      _transientThinkingText = text;
    });
    _scrollToBottom();
  }

  void _onActionResult(Map<String, dynamic> data) {
    final summary = data['summary']?.toString() ?? '';

    // 找到对应 step（不修改状态，只读）
    final session = _ensureStreamSession();
    final stepId = data['stepId']?.toString();
    ProcessStep? target;
    if (stepId != null) {
      for (final step in session.steps) {
        if (step.stepId == stepId) {
          target = step;
          break;
        }
      }
    }
    target ??= session.steps.lastWhere(
      (step) =>
          step.type == ProcessStepType.action &&
          step.status == ProcessStepStatus.pending,
      orElse: () => ProcessStep(
        stepId: stepId ?? _genStepId(),
        type: ProcessStepType.action,
        text: '执行工具',
        status: ProcessStepStatus.pending,
      ),
    );
    if (!session.steps.contains(target)) {
      session.steps.add(target);
    }

    // 保证 action 步骤最少显示 500ms
    const minDwell = Duration(milliseconds: 500);
    final elapsed = DateTime.now().difference(target.startedAt);
    final delay = elapsed < minDwell ? minDwell - elapsed : Duration.zero;

    void applyResult() {
      if (!mounted) return;
      setState(() {
        target!.status = ProcessStepStatus.done;
        if (summary.isNotEmpty) {
          target.text = '${target.text}  -  $summary';
        }
        final s = _ensureStreamSession();
        s.phase = StreamPhase.acting;
        _transientThinkingText = target.text;
      });
    }

    if (delay == Duration.zero) {
      applyResult();
    } else {
      Future.delayed(delay, applyResult);
    }
  }

  void _onScheduleParsed(Map<String, dynamic> data) {
    final parsed = data['parsed'];
    final parsedData = parsed is Map
        ? Map<String, dynamic>.from(parsed)
        : Map<String, dynamic>.from(data);

    setState(() {
      final session = _ensureStreamSession();
      session.parsedSchedule = parsedData;
      session.steps.add(
        ProcessStep(
          stepId: data['stepId']?.toString() ?? _genStepId(),
          type: ProcessStepType.scheduleParsed,
          text: '已解析出日程信息，等待确认创建',
          status: ProcessStepStatus.done,
        ),
      );
      session.phase = StreamPhase.acting;
      _pendingScheduleParsed = parsedData;
      _transientThinkingText = '已识别到日程信息，等待确认创建';
    });
    _scrollToBottom();
  }

  void _onAnswerDelta(Map<String, dynamic> data) {
    final delta = data['delta']?.toString() ?? '';
    if (delta.isEmpty) return;

    if (!_bubbleReady) {
      final shouldKeepThinking =
          _hasPendingActionStep() || _looksLikeToolPayload(delta);
      if (shouldKeepThinking) {
        setState(() {
          final session = _ensureStreamSession();
          session.phase = StreamPhase.acting;
          _transientThinkingText = _thinkingTextFromDelta(delta);
          _suppressedBubbleChunks += 1;
        });
        if (_suppressedBubbleChunks < 3) return;
      } else {
        _suppressedBubbleChunks = 0;
      }
    }

    setState(() {
      final session = _ensureStreamSession();
      session.answerBuffer.write(delta);
      session.phase = StreamPhase.answering;
      _transientThinkingText = null;
      _bubbleReady = true;
      _suppressedBubbleChunks = 0;
    });
    _scrollToBottom();
  }

  void _onWarning(Map<String, dynamic> data) {
    final text = data['message']?.toString() ?? '收到警告';
    setState(() {
      final session = _ensureStreamSession();
      session.steps.add(
        ProcessStep(
          stepId: data['stepId']?.toString() ?? _genStepId(),
          type: ProcessStepType.warning,
          text: text,
          status: ProcessStepStatus.failed,
        ),
      );
    });
  }

  bool get _strictMessageIdAssertionEnabled {
    if (!kReleaseMode) return true;
    const apiUrl = String.fromEnvironment('API_URL', defaultValue: '');
    final lowerUrl = apiUrl.toLowerCase();
    return lowerUrl.contains('staging') || lowerUrl.contains('dev');
  }

  void _onFinal(dynamic payload, {required String tempAiMessageId}) {
    Message? aiMessage;
    Map<String, dynamic>? metricsMap;

    if (payload is Message) {
      aiMessage = payload;
    } else if (payload is Map) {
      final data = Map<String, dynamic>.from(payload);
      if (data['aiMessage'] is Map) {
        aiMessage = Message.fromJson(
          Map<String, dynamic>.from(data['aiMessage'] as Map),
        );
      } else if (data['id'] != null && data['role'] != null) {
        aiMessage = Message.fromJson(data);
      }
      if (data['metrics'] is Map) {
        metricsMap = Map<String, dynamic>.from(data['metrics'] as Map);
      }
    }

    if (aiMessage == null) {
      _onStreamError('final 事件缺少 aiMessage');
      return;
    }

    final session = _ensureStreamSession();
    final expectedMessageId = session.messageId;
    if (expectedMessageId != null &&
        expectedMessageId.isNotEmpty &&
        aiMessage.id != expectedMessageId) {
      final errorMessage =
          '消息一致性校验失败：session_start.messageId=$expectedMessageId, final.aiMessage.id=${aiMessage.id}';
      if (_strictMessageIdAssertionEnabled) {
        throw StateError(errorMessage);
      }
      _onStreamError(errorMessage);
      return;
    }

    setState(() {
      final index = _messages.indexWhere((m) => m.id == tempAiMessageId);
      if (index != -1) {
        _messages[index] = aiMessage!;
      } else {
        _messages.add(aiMessage!);
      }

      session
        ..finalMessage = aiMessage
        ..metrics = metricsMap == null
            ? null
            : StreamMetrics(
                ttftMs: (metricsMap['ttftMs'] as num?)?.toInt() ?? 0,
                totalMs: (metricsMap['totalMs'] as num?)?.toInt() ?? 0,
                toolCalls: (metricsMap['toolCalls'] as num?)?.toInt() ?? 0,
                toolErrors: (metricsMap['toolErrors'] as num?)?.toInt() ?? 0,
              )
        ..phase = StreamPhase.done;
      session.answerBuffer
        ..clear()
        ..write(aiMessage.content);

      _activeStreamingMessageId = null;
      _isSending = false;
      _transientThinkingText = null;
      _bubbleReady = false;
      _suppressedBubbleChunks = 0;
      _streamInterruptedByUser = false;
    });
    _scrollToBottom();
  }

  void _onStreamError(String message) {
    if (!mounted) return;

    setState(() {
      final session = _ensureStreamSession();
      final tempAiId = _activeStreamingMessageId;
      if (tempAiId != null) {
        _messages.removeWhere((m) => m.id == tempAiId);
      }
      session.phase = StreamPhase.error;
      _isSending = false;
      _activeStreamingMessageId = null;
      _transientThinkingText = null;
      _bubbleReady = false;
      _suppressedBubbleChunks = 0;
      _streamInterruptedByUser = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _interruptCurrentStream() {
    if (!_isSending) return;
    _streamInterruptedByUser = true;
    _streamSub?.cancel();

    setState(() {
      final tempAiId = _activeStreamingMessageId;
      final partialAnswer = _streamSession?.answerBuffer.toString() ?? '';
      if (tempAiId != null) {
        final index = _messages.indexWhere((m) => m.id == tempAiId);
        if (index != -1) {
          if (partialAnswer.trim().isEmpty) {
            _messages.removeAt(index);
          } else {
            final old = _messages[index];
            _messages[index] = Message(
              id: old.id,
              role: old.role,
              content: partialAnswer,
              conversationId: old.conversationId,
              createdAt: old.createdAt,
              attachments: old.attachments,
              metadata: old.metadata,
            );
          }
        }
      }

      _isSending = false;
      _activeStreamingMessageId = null;
      _transientThinkingText = null;
      _bubbleReady = false;
      _suppressedBubbleChunks = 0;
      if (_streamSession != null) {
        _streamSession!.phase = StreamPhase.error;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('会话已中断'), duration: Duration(seconds: 2)),
    );
  }

  String get _streamPhaseHintText {
    switch (_streamSession?.phase) {
      case StreamPhase.init:
        return '正在理解你的问题…';
      case StreamPhase.thinking:
        return '正在思考…';
      case StreamPhase.acting:
        return '正在执行操作…';
      case StreamPhase.answering:
        return '正在组织回答…';
      case StreamPhase.done:
      case StreamPhase.error:
      case null:
        return '正在理解你的问题…';
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

  List<Message> _extractLocalSummaryMessages(List<Message> source) {
    return source.where(_isLocalSummaryMessage).toList();
  }

  bool _isLocalSummaryMessage(Message message) {
    final metadata = _parseMessageMetadata(message.metadata);
    final localType = metadata?['localType']?.toString();
    return localType == 'session_divider' ||
        localType == 'today_schedule_summary';
  }

  Map<String, dynamic>? _parseMessageMetadata(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Future<void> _insertTodaySummaryEntryIfNeeded() async {
    if (!mounted ||
        _todaySummaryInsertedThisForeground ||
        _todaySummaryInserting) {
      return;
    }
    _todaySummaryInserting = true;

    try {
      final conversation = _currentConversation;
      if (conversation == null) return;
      if (_currentConversation?.id != conversation.id) return;

      final now = DateTime.now();
      final dividerMessage = Message(
        id: 'local_divider_${now.microsecondsSinceEpoch}',
        role: 'system',
        content: '',
        conversationId: conversation.id,
        createdAt: now,
        metadata: jsonEncode({
          'localType': 'session_divider',
          'label': _formatSessionDividerLabel(now),
        }),
      );
      final summaryPayload = await _buildTodaySummaryPayload();
      final Message? cardMessage = summaryPayload == null
          ? null
          : Message(
              id: 'local_today_summary_${now.microsecondsSinceEpoch}',
              role: 'system',
              content: '',
              conversationId: conversation.id,
              createdAt: now,
              metadata: jsonEncode(summaryPayload),
            );

      setState(() {
        _messages.add(dividerMessage);
        if (cardMessage != null) {
          _messages.add(cardMessage);
        }
        _todaySummaryInsertedThisForeground = true;
      });
      _scrollToBottom();
    } finally {
      _todaySummaryInserting = false;
    }
  }

  Future<Map<String, dynamic>?> _buildTodaySummaryPayload() async {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    bool offline = false;
    List<Schedule> monthSchedules;

    try {
      monthSchedules = await _scheduleRepository.refreshSchedules(
        year: year,
        month: month,
      );
    } catch (_) {
      offline = true;
      final cached = await _scheduleRepository.getCachedSchedules(
        year: year,
        month: month,
      );
      if (cached == null) return null;
      monthSchedules = cached;
    }

    final todaySchedules = monthSchedules
        .where((s) => _isSameDay(_baseDateOf(s), now))
        .toList();
    final active = todaySchedules.where((s) {
      final effective = _effectiveStatus(s, now);
      return effective == 'pending' || effective == 'in_progress';
    }).toList();

    active.sort((a, b) {
      final aAllDay = _isAllDaySchedule(a);
      final bAllDay = _isAllDaySchedule(b);
      if (aAllDay != bAllDay) return aAllDay ? -1 : 1;
      return a.startTime.compareTo(b.startTime);
    });

    final displayItems = active.take(5).map((s) {
      final status = _effectiveStatus(s, now);
      return {
        'title': s.title,
        'timeText': _formatScheduleTime(s),
        'status': status,
      };
    }).toList();

    if (active.isEmpty) {
      return null;
    }

    final allItems = active.map((s) {
      final status = _effectiveStatus(s, now);
      return {
        'title': s.title,
        'timeText': _formatScheduleTime(s),
        'status': status,
      };
    }).toList();

    return {
      'localType': 'today_schedule_summary',
      'state': 'active',
      'offline': offline,
      'dateLabel': _formatDateLabel(now),
      'totalToday': todaySchedules.length,
      'overflow': active.length > 5 ? active.length - 5 : 0,
      'items': displayItems,
      'allItems': allItems,
    };
  }

  DateTime _baseDateOf(Schedule schedule) {
    if (schedule.startDate != null) {
      return schedule.startDate!;
    }
    return schedule.startTime;
  }

  bool _isAllDaySchedule(Schedule schedule) {
    return schedule.allDay || !schedule.hasStartTime;
  }

  String _effectiveStatus(Schedule schedule, DateTime now) {
    if (schedule.status == 'completed' || schedule.status == 'cancelled') {
      return schedule.status;
    }

    if (_isNowInSchedule(schedule, now)) {
      return 'in_progress';
    }
    return schedule.status == 'in_progress' ? 'in_progress' : 'pending';
  }

  bool _isNowInSchedule(Schedule schedule, DateTime now) {
    if (_isAllDaySchedule(schedule)) return false;
    final start = schedule.startTime;
    final end = schedule.endTime;
    if (end != null) {
      return !now.isBefore(start) && !now.isAfter(end);
    }
    return now.year == start.year &&
        now.month == start.month &&
        now.day == start.day &&
        now.hour == start.hour;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateLabel(DateTime date) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday ${date.month}月${date.day}日';
  }

  String _formatSessionDividerLabel(DateTime date) {
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '${date.month}月${date.day}日 $hh:$mm · 重新进入';
  }

  String _formatScheduleTime(Schedule schedule) {
    if (_isAllDaySchedule(schedule)) return '全天';

    final start = schedule.startTime;
    final startText =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

    if (!schedule.hasEndTime || schedule.endTime == null) {
      return startText;
    }

    final end = schedule.endTime!;
    final endText =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$startText - $endText';
  }

  void _handleTodaySummaryViewAll() {
    final mainState = mainPageKey.currentState;
    if (mainState != null && mainState.mounted) {
      Future.microtask(() {
        try {
          (mainState as dynamic).navigateToScheduleDate(DateTime.now());
        } catch (e) {
          debugPrint('跳转日历失败: $e');
        }
      });
    }
  }

  Future<void> _handleTodaySummaryAskAi(Map<String, dynamic> payload) async {
    if (_isSending) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前会话尚未结束，请稍候再试')));
      return;
    }

    final sourceItems = payload['allItems'] is List
        ? (payload['allItems'] as List)
        : (payload['items'] as List? ?? const []);

    final items = sourceItems
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('今日暂无可规划的日程')));
      return;
    }

    final lines = items
        .map((item) {
          final timeText = item['timeText']?.toString() ?? '';
          final title = item['title']?.toString() ?? '未命名日程';
          final status = item['status']?.toString() == 'in_progress'
              ? '（进行中）'
              : '';
          return '- $timeText $title$status';
        })
        .join('\n');

    _controller.text = '今天我有以下日程安排：\n$lines\n请帮我分析一下今天的时间安排，给出优化建议。';
    await _sendMessage();
  }

  Future<void> _forceRefreshSchedulesCache() async {
    await _scheduleRepository.getAllSchedules(forceRefresh: true);
  }

  Future<void> _confirmCreateParsedSchedule() async {
    final parsed = _pendingScheduleParsed;
    if (parsed == null || _isCreatingSchedule) return;

    setState(() => _isCreatingSchedule = true);
    try {
      final schedule = _buildScheduleFromParsed(parsed);
      await runCrudWithForceRefresh(
        action: () => _scheduleRepository.createSchedule(schedule),
        forceRefresh: _forceRefreshSchedulesCache,
      );

      if (!mounted) return;
      setState(() => _pendingScheduleParsed = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 日程创建成功'),
          duration: Duration(seconds: 2),
        ),
      );

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
              (mainState as dynamic).navigateToScheduleDate(schedule.startTime);
            } catch (e) {
              debugPrint('切换到日历页面失败: $e');
            }
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 创建日程失败: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingSchedule = false);
      }
    }
  }

  void _dismissParsedSchedule() {
    setState(() => _pendingScheduleParsed = null);
  }

  Schedule _buildScheduleFromParsed(Map<String, dynamic> parsed) {
    DateTime? parseDateOnly(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      if (text.isEmpty) return null;
      final parsedDate = DateTime.tryParse(text);
      if (parsedDate == null) return null;
      return DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    }

    DateTime? parseDateTime(dynamic value, {DateTime? fallbackDate}) {
      if (value == null) return null;
      final text = value.toString().trim();
      if (text.isEmpty) return null;

      final parsedFull = DateTime.tryParse(text);
      if (parsedFull != null) return parsedFull.toLocal();

      final hhmm = RegExp(r'^(\d{1,2}):(\d{2})$');
      final match = hhmm.firstMatch(text);
      if (match == null || fallbackDate == null) return null;

      final hour = int.tryParse(match.group(1)!);
      final minute = int.tryParse(match.group(2)!);
      if (hour == null || minute == null) return null;
      return DateTime(
        fallbackDate.year,
        fallbackDate.month,
        fallbackDate.day,
        hour,
        minute,
      );
    }

    final now = DateTime.now();
    final startDate = parseDateOnly(parsed['startDate']);
    final endDate = parseDateOnly(parsed['endDate']);
    final parsedStartTime = parseDateTime(
      parsed['startTime'],
      fallbackDate: startDate,
    );
    final parsedEndTime = parseDateTime(
      parsed['endTime'],
      fallbackDate: endDate ?? startDate,
    );

    final hasStartTime = parsedStartTime != null;
    final hasEndTime = parsedEndTime != null;
    final resolvedStartTime =
        parsedStartTime ??
        DateTime(
          (startDate ?? now).year,
          (startDate ?? now).month,
          (startDate ?? now).day,
          9,
        );
    final resolvedEndTime = parsedEndTime;

    final title = (parsed['title']?.toString().trim().isNotEmpty ?? false)
        ? parsed['title'].toString().trim()
        : '未命名日程';

    return Schedule(
      id: '',
      userId: '',
      title: title,
      description: parsed['description']?.toString(),
      startTime: resolvedStartTime,
      endTime: resolvedEndTime,
      allDay: !hasStartTime && !hasEndTime,
      location: parsed['location']?.toString(),
      status: 'pending',
      type: parsed['type']?.toString(),
      priority: parsed['priority']?.toString(),
      remindBefore: (parsed['remindBefore'] as num?)?.toInt(),
      startDate: startDate,
      endDate: endDate,
      hasStartTime: hasStartTime,
      hasEndTime: hasEndTime,
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
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _streamSub?.cancel();

    // 清理语音资源
    _voiceInput.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _todaySummaryInsertedThisForeground = false;
      _insertTodaySummaryEntryIfNeeded();
    }
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
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Column(
              children: [
                // 离线状态横幅
                OfflineBanner(
                  showPendingCount: true,
                  pendingCount: _pendingCount,
                ),
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
                    activeStreamingMessageId: _activeStreamingMessageId,
                    activeStreamingText:
                        _streamSession?.answerBuffer.toString().isNotEmpty ==
                            true
                        ? _streamSession!.answerBuffer.toString()
                        : '',
                    showStreamingBubble:
                        _activeStreamingMessageId != null &&
                        _bubbleReady &&
                        (_streamSession?.answerBuffer.toString().isNotEmpty ==
                            true),
                    showThinkingText:
                        _activeStreamingMessageId != null &&
                        !_bubbleReady &&
                        !(_streamSession?.answerBuffer.toString().isNotEmpty ==
                            true) &&
                        _streamSession?.phase != StreamPhase.done,
                    thinkingText:
                        _transientThinkingText ?? _streamPhaseHintText,
                    onTodaySummaryViewAll: _handleTodaySummaryViewAll,
                    onTodaySummaryAskAi: _handleTodaySummaryAskAi,
                  ),
                ),
                AnimatedSlide(
                  offset: _pendingScheduleParsed == null
                      ? const Offset(0, 1)
                      : Offset.zero,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _pendingScheduleParsed == null ? 0 : 1,
                    child: _pendingScheduleParsed == null
                        ? const SizedBox.shrink()
                        : ScheduleConfirmCard(
                            parsed: _pendingScheduleParsed!,
                            creating: _isCreatingSchedule,
                            onConfirm: _confirmCreateParsedSchedule,
                            onCancel: _dismissParsedSchedule,
                          ),
                  ),
                ),

                // 底部输入框
                ChatInputBar(
                  controller: _controller,
                  isListening: _voiceInput.isListening,
                  isSending: _isSending,
                  onSend: _sendMessage,
                  onInterrupt: _interruptCurrentStream,
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 96,
              child: AnimatedOpacity(
                opacity: _showScrollToBottom ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_showScrollToBottom,
                  child: Align(
                    alignment: Alignment.center,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: _scrollToBottom,
                      child: const Icon(Icons.arrow_downward),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
