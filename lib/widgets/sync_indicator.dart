import 'package:flutter/material.dart';

/// 同步进度指示器
///
/// 在数据同步时显示加载动画，可自定义大小和颜色。
class SyncIndicator extends StatelessWidget {
  /// 是否正在同步
  final bool isSyncing;

  /// 指示器大小
  final double size;

  /// 指示器颜色
  final Color? color;

  /// 同步完成回调
  final VoidCallback? onSyncComplete;

  const SyncIndicator({
    super.key,
    required this.isSyncing,
    this.size = 20,
    this.color,
    this.onSyncComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSyncing) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}

/// 浮动同步按钮
///
/// 显示为 FAB，带有同步图标和待处理任务数量徽章。
class FloatingSyncButton extends StatelessWidget {
  /// 是否正在同步
  final bool isSyncing;

  /// 待处理任务数量
  final int pendingCount;

  /// 点击回调
  final VoidCallback onTap;

  const FloatingSyncButton({
    super.key,
    required this.isSyncing,
    required this.pendingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 如果没有待处理任务，不显示按钮
    if (pendingCount == 0 && !isSyncing) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      onPressed: isSyncing ? null : onTap,
      backgroundColor: isSyncing ? Colors.grey : Theme.of(context).primaryColor,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            isSyncing ? Icons.sync : Icons.cloud_upload,
            color: Colors.white,
          ),
          if (pendingCount > 0 && !isSyncing)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Center(
                  child: Text(
                    pendingCount > 99 ? '99+' : '$pendingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
