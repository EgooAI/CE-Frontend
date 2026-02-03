import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../models/chat/conversation.dart';
import 'message_bubble.dart';
import 'welcome_guide.dart';

/// 聊天消息列表视图组件
///
/// 职责：
/// - 显示消息列表或欢迎引导
/// - 支持下拉刷新
/// - 管理加载状态
class MessageListView extends StatefulWidget {
  /// 当前对话
  final Conversation? currentConversation;

  /// 消息列表
  final List<Message> messages;

  /// 是否正在加载
  final bool isLoading;

  /// 是否显示完整引导（无对话列表时）
  final bool showFullGuide;

  /// 点击示例问题回调
  final Function(String text) onExampleTap;

  /// 滚动控制器
  final ScrollController scrollController;

  /// 下拉刷新回调
  final Future<void> Function()? onRefresh;

  const MessageListView({
    super.key,
    required this.currentConversation,
    required this.messages,
    required this.isLoading,
    required this.showFullGuide,
    required this.onExampleTap,
    required this.scrollController,
    this.onRefresh,
  });

  @override
  State<MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends State<MessageListView> {
  // 滑动收起键盘相关（已禁用 - 影响正常使用）
  // double _lastScrollPosition = 0;
  double _accumulatedDy = 0;
  DateTime? _lastScrollAt;
  @override
  Widget build(BuildContext context) {
    // 无对话或加载中显示欢迎引导
    if (widget.currentConversation == null) {
      return WelcomeGuide(
        showFullGuide: widget.showFullGuide,
        onExampleTap: widget.onExampleTap,
      );
    }

    // 加载中显示进度指示器
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 消息为空显示欢迎引导
    if (widget.messages.isEmpty) {
      return WelcomeGuide(
        showFullGuide: widget.showFullGuide,
        onExampleTap: widget.onExampleTap,
      );
    }

    // 显示消息列表
    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: ListView.builder(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          itemCount: widget.messages.length,
          itemBuilder: (context, index) {
            final message = widget.messages[index];
            final isUser = message.role == 'user';
            return MessageBubble(message: message, isUser: isUser);
          },
        ),
      ),
    );
  }

  /// 滚动消息列表时，累计向下滑动距离达到阈值后收起键盘
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      final now = DateTime.now();
      double velocity = 0;
      if (_lastScrollAt != null) {
        final dtMs = now.difference(_lastScrollAt!).inMilliseconds;
        if (dtMs > 0) {
          velocity = delta.abs() / dtMs;
        }
      }
      _lastScrollAt = now;
      if (delta < 0) {
        _accumulatedDy += delta.abs();
        final hasFocus = FocusScope.of(context).hasFocus;
        if (_accumulatedDy >= 300 && velocity >= 1.2 && hasFocus) {
          FocusScope.of(context).unfocus();
          _accumulatedDy = 0;
        }
      } else {
        _accumulatedDy = 0;
      }
    } else if (notification is ScrollEndNotification) {
      _accumulatedDy = 0;
      _lastScrollAt = null;
    }
    return false;
  }
}
