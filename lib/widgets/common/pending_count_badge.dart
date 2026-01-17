import 'package:flutter/material.dart';

/// 待同步任务计数徽章
///
/// 显示待同步任务的数量，可附加到任何 Widget 上。
class PendingCountBadge extends StatelessWidget {
  /// 待处理任务数量
  final int count;

  /// 子组件
  final Widget child;

  /// 徽章位置偏移
  final Offset? offset;

  /// 徽章颜色
  final Color? backgroundColor;

  const PendingCountBadge({
    super.key,
    required this.count,
    required this.child,
    this.offset,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: offset?.dx ?? -8,
          top: offset?.dy ?? -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.red,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            child: Center(
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 内联同步状态指示器
///
/// 在列表项中显示同步状态（同步中、失败、待上传）。
class InlineSyncStatus extends StatelessWidget {
  /// 同步状态文本
  final String status;

  /// 状态颜色
  final Color color;

  /// 状态图标
  final IconData icon;

  const InlineSyncStatus({
    super.key,
    required this.status,
    required this.color,
    required this.icon,
  });

  /// 创建"待上传"状态
  factory InlineSyncStatus.pending() {
    return const InlineSyncStatus(
      status: '待上传',
      color: Colors.orange,
      icon: Icons.cloud_upload,
    );
  }

  /// 创建"同步中"状态
  factory InlineSyncStatus.syncing() {
    return const InlineSyncStatus(
      status: '同步中',
      color: Colors.blue,
      icon: Icons.sync,
    );
  }

  /// 创建"同步失败"状态
  factory InlineSyncStatus.failed() {
    return const InlineSyncStatus(
      status: '同步失败',
      color: Colors.red,
      icon: Icons.error_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
