import 'package:flutter/material.dart';
import '../../models/chat/conversation.dart';
import 'message_bubble.dart';
import 'welcome_guide.dart';

/// 聊天消息列表视图组件
///
/// 职责：
/// - 显示消息列表或欢迎引导
/// - 处理滚动监听（快速下滑收起键盘）
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

  const MessageListView({
    super.key,
    required this.currentConversation,
    required this.messages,
    required this.isLoading,
    required this.showFullGuide,
    required this.onExampleTap,
    required this.scrollController,
  });

  @override
  State<MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends State<MessageListView> {
  // 滑动收起键盘相关
  double _lastScrollPosition = 0;
  DateTime? _lastScrollTime;

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
    return NotificationListener<ScrollNotification>(
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
    );
  }

  /// 处理滚动通知，实现快速下滑收起键盘
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final currentPosition = notification.metrics.pixels;
      final currentTime = DateTime.now();

      if (_lastScrollTime != null) {
        // 计算滑动速度（像素/毫秒）
        final deltaPosition = currentPosition - _lastScrollPosition;
        final deltaTime = currentTime
            .difference(_lastScrollTime!)
            .inMilliseconds;

        if (deltaTime > 0) {
          final velocity = deltaPosition.abs() / deltaTime;

          // 只在向下快速滑动时收起键盘（速度 > 2 px/ms，约等于 2000 px/s）
          if (deltaPosition > 0 &&
              velocity > 2 &&
              FocusScope.of(context).hasFocus) {
            FocusScope.of(context).unfocus();
          }
        }
      }

      _lastScrollPosition = currentPosition;
      _lastScrollTime = currentTime;
    }
    return false;
  }
}
