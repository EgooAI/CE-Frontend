import 'package:flutter/material.dart';

import '../../models/chat/stream_session.dart';

class StreamProcessPanel extends StatelessWidget {
  const StreamProcessPanel({
    super.key,
    required this.session,
    required this.expanded,
    required this.onToggle,
    this.errorMessage,
    this.onRetry,
  });

  final StreamSession session;
  final bool expanded;
  final VoidCallback onToggle;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final headerText = _headerText(session);
    final stepCount = session.thoughtCount;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E9EE)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        headerText,
                        key: ValueKey(headerText),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2F3441),
                        ),
                      ),
                    ),
                  ),
                  if (session.phase == StreamPhase.answering)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$stepCount 步',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5F6368),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _ProcessStepList(steps: session.steps),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOutCubic,
          ),
          if (errorMessage != null && errorMessage!.isNotEmpty)
            _ErrorBar(message: errorMessage!, onRetry: onRetry),
        ],
      ),
    );
  }
}

String _headerText(StreamSession session) {
  switch (session.phase) {
    case StreamPhase.init:
      return '正在理解你的问题…';
    case StreamPhase.thinking:
      return '正在思考…';
    case StreamPhase.acting:
      return '正在执行操作…';
    case StreamPhase.answering:
      return '已思考 ${session.thoughtCount} 步';
    case StreamPhase.done:
      return '已完成  ✓';
    case StreamPhase.error:
      return '处理中断';
  }
}

class _ProcessStepList extends StatelessWidget {
  const _ProcessStepList({required this.steps});

  final List<ProcessStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '正在准备思考流程…',
            style: TextStyle(fontSize: 12, color: Color(0xFF8C9199)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        children: steps
            .map(
              (step) => _AnimatedProcessStepRow(
                key: ValueKey(step.stepId),
                step: step,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AnimatedProcessStepRow extends StatefulWidget {
  const _AnimatedProcessStepRow({super.key, required this.step});

  final ProcessStep step;

  @override
  State<_AnimatedProcessStepRow> createState() =>
      _AnimatedProcessStepRowState();
}

class _AnimatedProcessStepRowState extends State<_AnimatedProcessStepRow> {
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _entered = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _entered ? Offset.zero : const Offset(0, 0.3),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _entered ? 1 : 0,
        duration: const Duration(milliseconds: 280),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: _StepLeading(step: widget.step),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.step.text,
                  style: TextStyle(
                    color: _stepTextColor(widget.step),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepLeading extends StatelessWidget {
  const _StepLeading({required this.step});

  final ProcessStep step;

  @override
  Widget build(BuildContext context) {
    if (step.type == ProcessStepType.action &&
        step.status == ProcessStepStatus.pending) {
      return CircularProgressIndicator(
        strokeWidth: 2,
        color: Theme.of(context).colorScheme.primary,
      );
    }

    if (step.type == ProcessStepType.warning) {
      return const Icon(
        Icons.warning_amber_rounded,
        size: 16,
        color: Colors.orange,
      );
    }

    if (step.type == ProcessStepType.scheduleParsed) {
      return const Icon(
        Icons.event_note_outlined,
        size: 16,
        color: Color(0xFF2066D4),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: switch (step.status) {
        ProcessStepStatus.done => const Icon(
          Icons.check_circle_outline,
          key: ValueKey('done'),
          size: 16,
          color: Colors.green,
        ),
        ProcessStepStatus.failed => const Icon(
          Icons.error_outline,
          key: ValueKey('failed'),
          size: 16,
          color: Colors.orange,
        ),
        ProcessStepStatus.pending => const Icon(
          Icons.more_horiz,
          key: ValueKey('pending'),
          size: 16,
          color: Color(0xFF7D8491),
        ),
      },
    );
  }
}

Color _stepTextColor(ProcessStep step) {
  if (step.type == ProcessStepType.warning) return const Color(0xFFBB6B00);
  if (step.status == ProcessStepStatus.failed) return const Color(0xFFB24B4B);
  return const Color(0xFF4A505C);
}

class _ErrorBar extends StatefulWidget {
  const _ErrorBar({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  State<_ErrorBar> createState() => _ErrorBarState();
}

class _ErrorBarState extends State<_ErrorBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0.02, 0),
        ).chain(CurveTween(curve: Curves.elasticIn)).animate(_controller),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE7E7), Color(0xFFFFF3F3)],
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline,
                size: 16,
                color: Color(0xFFB24B4B),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF8E3131),
                  ),
                ),
              ),
              if (widget.onRetry != null)
                TextButton(
                  onPressed: widget.onRetry,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(10, 30),
                  ),
                  child: const Text('重试'),
                ),
            ],
          ),
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
