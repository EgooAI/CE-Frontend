import 'package:hive/hive.dart';

part 'sync_task.g.dart';

/// 同步任务状态
@HiveType(typeId: 11)
enum SyncStatus {
  @HiveField(0)
  pending, // 等待同步
  @HiveField(1)
  syncing, // 同步中
  @HiveField(2)
  completed, // 已完成
  @HiveField(3)
  failed, // 失败
  @HiveField(4)
  conflict, // 冲突
}

/// 同步操作类型
@HiveType(typeId: 12)
enum SyncOperation {
  @HiveField(0)
  create, // 创建
  @HiveField(1)
  update, // 更新
  @HiveField(2)
  delete, // 删除
}

/// 资源类型
@HiveType(typeId: 13)
enum ResourceType {
  @HiveField(0)
  schedule, // 日程
  @HiveField(1)
  dailyTask, // 日常任务
  @HiveField(2)
  conversation, // 对话
}

/// 同步任务模型
/// 用于离线编辑队列，支持后台同步
@HiveType(typeId: 10)
class SyncTask {
  /// 任务唯一 ID（UUID）
  @HiveField(0)
  final String id;

  /// 资源类型
  @HiveField(1)
  final ResourceType resourceType;

  /// 操作类型
  @HiveField(2)
  final SyncOperation operation;

  /// 资源 ID（对于 create 操作是临时 ID）
  @HiveField(3)
  final String resourceId;

  /// 数据负载（JSON 格式）
  @HiveField(4)
  final Map<String, dynamic> payload;

  /// 任务状态
  @HiveField(5)
  final SyncStatus status;

  /// 优先级（0=最低，9=最高）
  @HiveField(6)
  final int priority;

  /// 重试次数
  @HiveField(7)
  final int retryCount;

  /// 最大重试次数
  @HiveField(8)
  final int maxRetries;

  /// 创建时间
  @HiveField(9)
  final DateTime createdAt;

  /// 最后尝试时间
  @HiveField(10)
  final DateTime? lastAttemptAt;

  /// 错误信息
  @HiveField(11)
  final String? error;

  /// 冲突数据（服务器版本）
  @HiveField(12)
  final Map<String, dynamic>? conflictData;

  SyncTask({
    required this.id,
    required this.resourceType,
    required this.operation,
    required this.resourceId,
    required this.payload,
    this.status = SyncStatus.pending,
    this.priority = 5,
    this.retryCount = 0,
    this.maxRetries = 3,
    required this.createdAt,
    this.lastAttemptAt,
    this.error,
    this.conflictData,
  });

  /// 创建新任务
  factory SyncTask.create({
    required String id,
    required ResourceType resourceType,
    required SyncOperation operation,
    required String resourceId,
    required Map<String, dynamic> payload,
    int priority = 5,
  }) {
    return SyncTask(
      id: id,
      resourceType: resourceType,
      operation: operation,
      resourceId: resourceId,
      payload: payload,
      priority: priority,
      createdAt: DateTime.now(),
    );
  }

  /// 复制并更新字段
  SyncTask copyWith({
    String? id,
    ResourceType? resourceType,
    SyncOperation? operation,
    String? resourceId,
    Map<String, dynamic>? payload,
    SyncStatus? status,
    int? priority,
    int? retryCount,
    int? maxRetries,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    String? error,
    Map<String, dynamic>? conflictData,
  }) {
    return SyncTask(
      id: id ?? this.id,
      resourceType: resourceType ?? this.resourceType,
      operation: operation ?? this.operation,
      resourceId: resourceId ?? this.resourceId,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      error: error ?? this.error,
      conflictData: conflictData ?? this.conflictData,
    );
  }

  /// 标记为同步中
  SyncTask markAsSyncing() {
    return copyWith(status: SyncStatus.syncing, lastAttemptAt: DateTime.now());
  }

  /// 标记为成功
  SyncTask markAsCompleted() {
    return copyWith(status: SyncStatus.completed);
  }

  /// 标记为失败（并增加重试次数）
  SyncTask markAsFailed(String errorMessage) {
    return copyWith(
      status: SyncStatus.failed,
      retryCount: retryCount + 1,
      error: errorMessage,
    );
  }

  /// 标记为冲突
  SyncTask markAsConflict(Map<String, dynamic> serverData) {
    return copyWith(status: SyncStatus.conflict, conflictData: serverData);
  }

  /// 是否可以重试
  bool get canRetry => retryCount < maxRetries;

  /// 是否为高优先级任务
  bool get isHighPriority => priority >= 7;

  /// 任务年龄（秒）
  int get ageInSeconds => DateTime.now().difference(createdAt).inSeconds;

  /// 转换为 JSON（用于日志）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'resourceType': resourceType.name,
      'operation': operation.name,
      'resourceId': resourceId,
      'payload': payload,
      'status': status.name,
      'priority': priority,
      'retryCount': retryCount,
      'maxRetries': maxRetries,
      'createdAt': createdAt.toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'error': error,
      'conflictData': conflictData,
    };
  }

  @override
  String toString() {
    return 'SyncTask{${operation.name} ${resourceType.name} $resourceId, status=${status.name}, priority=$priority}';
  }
}
