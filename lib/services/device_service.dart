import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 设备 ID 管理服务
/// 用于生成和存储唯一的设备标识，支持后端单设备令牌限制
class DeviceService {
  static const String _deviceIdKey = 'device_id';
  static const _uuid = Uuid();

  /// 获取或生成设备 ID
  /// 首次调用时生成 UUID 并持久化存储
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _generateDeviceId();
      await prefs.setString(_deviceIdKey, deviceId);
      print('DeviceService: 生成新设备 ID - $deviceId');
    }

    return deviceId;
  }

  /// 清除设备 ID（用于调试或重置）
  static Future<void> clearDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
    print('DeviceService: 已清除设备 ID');
  }

  /// 生成设备标识
  /// Web: uuid v4
  /// Android: uuid v4
  /// iOS: uuid v4
  static String _generateDeviceId() {
    // 为不同平台生成唯一标识
    String prefix;
    if (kIsWeb) {
      prefix = 'web';
    } else if (Platform.isAndroid) {
      prefix = 'android';
    } else if (Platform.isIOS) {
      prefix = 'ios';
    } else {
      prefix = 'unknown';
    }

    return '$prefix-${_uuid.v4()}';
  }
}
