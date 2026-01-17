import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

/// 离线状态横幅
///
/// 显示当前网络连接状态，当离线时显示警告横幅。
/// 可选择显示待同步任务数量。
class OfflineBanner extends StatefulWidget {
  /// 是否显示待同步任务数量
  final bool showPendingCount;

  /// 待同步任务数量（可选）
  final int? pendingCount;

  const OfflineBanner({
    super.key,
    this.showPendingCount = true,
    this.pendingCount,
  });

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _listenToConnectivityChanges();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (mounted) {
        setState(() {
          _isOnline = _isConnected(results);
        });
      }
    } catch (e) {
      debugPrint('检查网络状态失败: $e');
    }
  }

  void _listenToConnectivityChanges() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() {
          _isOnline = _isConnected(results);
        });
      }
    });
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 在线时不显示横幅
    if (_isOnline) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: Colors.orange.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '离线模式',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (widget.showPendingCount &&
                    widget.pendingCount != null &&
                    widget.pendingCount! > 0)
                  Text(
                    '${widget.pendingCount} 个操作待同步',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
