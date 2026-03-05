import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class StreamingMessageBubble extends StatelessWidget {
  const StreamingMessageBubble({
    super.key,
    required this.text,
    required this.finished,
  });

  final String text;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = MediaQuery.of(context).size.width - 32;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: StreamingTextView(text: text, finished: finished),
      ),
    );
  }
}

class StreamingTextView extends StatefulWidget {
  const StreamingTextView({
    super.key,
    required this.text,
    required this.finished,
  });

  final String text;
  final bool finished;

  @override
  State<StreamingTextView> createState() => _StreamingTextViewState();
}

class _StreamingTextViewState extends State<StreamingTextView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    );
    if (!widget.finished) {
      _cursorController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant StreamingTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.finished && _cursorController.isAnimating) {
      _cursorController.stop();
    } else if (!widget.finished && !_cursorController.isAnimating) {
      _cursorController.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final markdownStyle = MarkdownStyleSheet(
      p: const TextStyle(color: Color(0xFF111111), fontSize: 16, height: 1.5),
      h1: const TextStyle(
        color: Color(0xFF111111),
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      h2: const TextStyle(
        color: Color(0xFF111111),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      h3: const TextStyle(
        color: Color(0xFF111111),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      code: const TextStyle(
        backgroundColor: Color(0xFFF2F3F5),
        fontFamily: 'monospace',
        color: Color(0xFF111111),
        fontSize: 13,
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(6),
      ),
      codeblockPadding: const EdgeInsets.all(8),
      blockquote: const TextStyle(
        color: Color(0xFF5F6368),
        fontStyle: FontStyle.italic,
      ),
      a: const TextStyle(
        color: Color(0xFF111111),
        decoration: TextDecoration.underline,
      ),
    );

    return AnimatedBuilder(
      animation: _cursorController,
      builder: (context, _) {
        final showCursor = !widget.finished && _cursorController.value > 0.5;
        final renderText = showCursor ? '${widget.text}▍' : widget.text;
        return MarkdownBody(
          data: renderText,
          selectable: true,
          styleSheet: markdownStyle,
        );
      },
    );
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }
}

class ThinkingStatusText extends StatefulWidget {
  const ThinkingStatusText({super.key, required this.text});

  final String text;

  @override
  State<ThinkingStatusText> createState() => _ThinkingStatusTextState();
}

class _ThinkingStatusTextState extends State<ThinkingStatusText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const _sweepDuration = Duration(milliseconds: 2200);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _sweepDuration)
      ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      fontSize: 12.5,
      color: Color(0xFF9AA0A6),
      height: 1.35,
      fontWeight: FontWeight.w500,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            const sweepWindow = 0.68; // 前 68% 时间扫光，后 32% 停顿
            final progress = _controller.value;
            final activeSweep = progress <= sweepWindow;
            final normalized = activeSweep ? progress / sweepWindow : 0.0;
            final center = normalized.clamp(0.0, 1.0);
            final left = (center - 0.14).clamp(0.0, 1.0);
            final right = (center + 0.14).clamp(0.0, 1.0);
            return ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: activeSweep
                      ? const [
                          Color(0xFF9CA2A9),
                          Color(0xFF9CA2A9),
                          Color(0xFFF3F5F8),
                          Color(0xFF9CA2A9),
                          Color(0xFF9CA2A9),
                        ]
                      : const [
                          Color(0xFF9CA2A9),
                          Color(0xFF9CA2A9),
                          Color(0xFF9CA2A9),
                          Color(0xFF9CA2A9),
                          Color(0xFF9CA2A9),
                        ],
                  stops: activeSweep
                      ? [0.0, left, center, right, 1.0]
                      : const [0.0, 0.25, 0.5, 0.75, 1.0],
                ).createShader(bounds);
              },
              child: Text(
                widget.text,
                style: baseStyle.copyWith(color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
