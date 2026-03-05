import 'conversation.dart';

enum StreamPhase { init, thinking, acting, answering, done, error }

enum ProcessStepType { thinking, action, warning, scheduleParsed }

enum ProcessStepStatus { pending, done, failed }

class ProcessStep {
  ProcessStep({
    required this.stepId,
    required this.type,
    required this.text,
    required this.status,
  });

  final String stepId;
  final ProcessStepType type;
  String text;
  ProcessStepStatus status;
}

class StreamMetrics {
  const StreamMetrics({
    required this.ttftMs,
    required this.totalMs,
    required this.toolCalls,
    required this.toolErrors,
  });

  final int ttftMs;
  final int totalMs;
  final int toolCalls;
  final int toolErrors;
}

class StreamSession {
  StreamSession({this.traceId, this.messageId})
    : steps = <ProcessStep>[],
      answerBuffer = StringBuffer(),
      phase = StreamPhase.init;

  String? traceId;
  String? messageId;
  final List<ProcessStep> steps;
  final StringBuffer answerBuffer;
  StreamPhase phase;
  Message? finalMessage;
  Map<String, dynamic>? parsedSchedule;
  StreamMetrics? metrics;

  int get thoughtCount => steps
      .where(
        (step) =>
            step.type == ProcessStepType.thinking ||
            step.type == ProcessStepType.action,
      )
      .length;
}
