import 'package:flutter/material.dart';
import '../../models/chat/conversation.dart';

/// 流式消息事件处理器
///
/// 职责：
/// - 处理流式消息的各种事件类型（progress、tool_call、content、done 等）
/// - 更新消息列表和思考过程
/// - 格式化最终消息内容
class StreamMessageHandler {
  /// 消息列表引用
  final List<Message> messages;

  /// 临时 AI 消息 ID
  final String tempAiMessageId;

  /// 对话 ID
  final String conversationId;

  /// 思考过程列表
  final List<String> streamingThoughts;

  /// 流式内容
  String streamingContent;

  /// 状态更新回调
  final VoidCallback onUpdate;

  /// 滚动到底部回调
  final VoidCallback onScrollToBottom;

  StreamMessageHandler({
    required this.messages,
    required this.tempAiMessageId,
    required this.conversationId,
    required this.streamingThoughts,
    required this.streamingContent,
    required this.onUpdate,
    required this.onScrollToBottom,
  });

  /// 处理用户消息事件
  void handleUserMessage(Message realUserMessage, String tempUserId) {
    final index = messages.indexWhere((m) => m.id == tempUserId);
    if (index != -1) {
      messages[index] = realUserMessage;
    }
    onUpdate();
  }

  /// 处理进度事件
  void handleProgress(Map<String, dynamic> progressData) {
    final progressMsg = progressData['message'] ?? '正在思考...';
    streamingThoughts.add('💭 $progressMsg');
    _updateTempMessage(_streamingThoughts);
    onScrollToBottom();
  }

  /// 处理工具调用事件
  void handleToolCall(Map<String, dynamic> toolData) {
    final toolName = toolData['tool'] ?? 'unknown';
    final toolArgs = toolData['args'] ?? '';

    streamingThoughts.add('🔧 调用工具: $toolName');
    if (toolArgs.toString().isNotEmpty && toolArgs.toString() != '{}') {
      streamingThoughts.add('   参数: $toolArgs');
    }

    _updateTempMessage(_streamingThoughts);
    onScrollToBottom();
  }

  /// 处理工具结果事件
  void handleToolResult(Map<String, dynamic> toolData) {
    final toolName = toolData['tool'] ?? 'unknown';
    final result = toolData['result'] ?? '';

    streamingThoughts.add('✅ $toolName 执行完成');
    if (result.toString().isNotEmpty) {
      streamingThoughts.add('   结果: $result');
    }

    _updateTempMessage(_streamingThoughts);
    onScrollToBottom();
  }

  /// 处理内容块事件（流式接收）
  void handleContent(Map<String, dynamic> contentData) {
    final chunk = contentData['chunk'] as String? ?? '';

    // 兼容"全量覆盖"与"增量追加"两种服务端推送模式
    if (chunk.isNotEmpty) {
      if (chunk.startsWith(streamingContent)) {
        streamingContent = chunk;
      } else {
        streamingContent += chunk;
      }
    }

    // 显示思考过程 + 当前流式内容
    String displayContent = '';
    if (streamingThoughts.isNotEmpty) {
      displayContent =
          '**思考过程:**\n```\n${streamingThoughts.join('\n')}\n```\n\n---\n\n';
    }
    displayContent += streamingContent;

    _updateTempMessage(displayContent);
    onScrollToBottom();
  }

  /// 处理完成事件
  void handleDone(Message finalMessage) {
    final index = messages.indexWhere((m) => m.id == tempAiMessageId);
    if (index == -1) return;

    // 如果有思考过程，在最终消息前添加思考过程
    String finalContent = finalMessage.content;

    // 如果流式内容不为空，优先使用流式内容
    if (streamingContent.isNotEmpty) {
      finalContent = streamingContent;
    }

    if (streamingThoughts.isNotEmpty) {
      finalContent =
          '**思考过程:**\n```\n${streamingThoughts.join('\n')}\n```\n\n---\n\n$finalContent';
    }

    messages[index] = Message(
      id: finalMessage.id,
      role: finalMessage.role,
      content: finalContent,
      conversationId: finalMessage.conversationId,
      createdAt: finalMessage.createdAt,
      attachments: finalMessage.attachments,
      metadata: finalMessage.metadata,
    );

    // 清空流式数据
    streamingThoughts.clear();
    streamingContent = '';

    onUpdate();
    onScrollToBottom();
  }

  /// 处理错误事件
  void handleError() {
    messages.removeWhere((m) => m.id == tempAiMessageId);
    streamingThoughts.clear();
    onUpdate();
  }

  /// 更新临时消息
  void _updateTempMessage(String content) {
    final index = messages.indexWhere((m) => m.id == tempAiMessageId);
    if (index != -1) {
      messages[index] = Message(
        id: tempAiMessageId,
        role: 'assistant',
        content: content,
        conversationId: conversationId,
        createdAt: DateTime.now(),
      );
    }
    onUpdate();
  }

  String get _streamingThoughts => streamingThoughts.join('\n');
}
