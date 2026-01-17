import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 科大讯飞实时语音转写服务（大模型版）
///
/// 使用 WebSocket 连接科大讯飞的实时语音转写大模型 API
/// 支持中英 + 202种方言混合识别
///
/// 使用 --dart-define 传递 API 凭证：
/// flutter run --dart-define=XFYUN_APP_ID=your_app_id \
///             --dart-define=XFYUN_ACCESS_KEY_ID=your_access_key_id \
///             --dart-define=XFYUN_ACCESS_KEY_SECRET=your_access_key_secret
class XunfeiAsrService {
  // 从环境变量读取科大讯飞 API 配置
  static const String _appId = String.fromEnvironment(
    'XFYUN_APP_ID',
    defaultValue: '',
  );
  static const String _accessKeyId = String.fromEnvironment(
    'XFYUN_ACCESS_KEY_ID',
    defaultValue: '',
  );
  static const String _accessKeySecret = String.fromEnvironment(
    'XFYUN_ACCESS_KEY_SECRET',
    defaultValue: '',
  );

  // WebSocket 连接地址（大模型版）
  static const String _baseUrl =
      'wss://office-api-ast-dx.iflyaisol.com/ast/communicate/v1';

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _sessionId; // 会话ID

  // 识别结果回调
  final void Function(String text, bool isFinal)? onResult;
  // 错误回调
  final void Function(String error)? onError;
  // 连接状态回调
  final void Function(bool connected)? onConnectionChanged;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  XunfeiAsrService({this.onResult, this.onError, this.onConnectionChanged});

  /// 开始识别
  Future<void> start() async {
    if (_isConnected) {
      print('XunfeiASR: 已经在识别中');
      return;
    }

    // 验证 API 凭证是否已配置
    if (_appId.isEmpty || _accessKeyId.isEmpty || _accessKeySecret.isEmpty) {
      final errorMsg = '科大讯飞 API 凭证未配置！请设置 --dart-define 参数或创建 .env 文件';
      print('XunfeiASR: $errorMsg');
      onError?.call(errorMsg);
      return;
    }

    try {
      // 生成鉴权 URL
      final authUrl = _generateAuthUrl();

      // 建立 WebSocket 连接
      _channel = WebSocketChannel.connect(Uri.parse(authUrl));

      // 监听消息
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onWebSocketError,
        onDone: _onWebSocketDone,
      );

      _isConnected = true;
      onConnectionChanged?.call(true);

      print('XunfeiASR: WebSocket 连接成功');
    } catch (e) {
      print('XunfeiASR: 连接失败 - $e');
      onError?.call('连接失败: $e');
      _isConnected = false;
      onConnectionChanged?.call(false);
    }
  }

  /// 发送音频数据（二进制格式）
  ///
  /// [audioData] PCM 格式音频数据（16kHz, 16bit, 单声道）
  /// 建议每 40ms 发送 1280 字节
  void sendAudio(Uint8List audioData) {
    if (!_isConnected || _channel == null) {
      print('XunfeiASR: 未连接，无法发送音频');
      return;
    }

    try {
      // 大模型版直接发送二进制音频数据
      _channel!.sink.add(audioData);
    } catch (e) {
      print('XunfeiASR: 发送音频失败 - $e');
      onError?.call('发送音频失败: $e');
    }
  }

  /// 停止识别
  Future<void> stop() async {
    if (!_isConnected || _channel == null) {
      return;
    }

    try {
      // 生成唯一的 sessionId
      _sessionId = _generateSessionId();

      // 发送结束标识（JSON 格式）
      final endFrame = {'end': true, 'sessionId': _sessionId};

      _channel!.sink.add(jsonEncode(endFrame));

      // 等待服务器处理最后的数据
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('XunfeiASR: 发送结束帧失败 - $e');
    }

    await _cleanup();
  }

  /// 清理资源
  Future<void> _cleanup() async {
    await _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    _isConnected = false;
    _sessionId = null;
    onConnectionChanged?.call(false);

    print('XunfeiASR: 资源已清理');
  }

  /// 处理 WebSocket 消息
  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;

      // 检查消息类型
      final msgType = data['msg_type'] as String?;

      if (msgType == 'result') {
        final resType = data['res_type'] as String?;

        if (resType == 'asr') {
          // 正常的识别结果
          _handleAsrResult(data);
        } else if (resType == 'frc') {
          // 功能异常
          final resultData = data['data'] as Map<String, dynamic>?;
          final desc = resultData?['desc'] ?? '未知错误';
          print('XunfeiASR: 功能异常 - $desc');
          onError?.call('识别异常: $desc');
        }
      } else if (data['action'] == 'error') {
        // 错误响应
        final code = data['code'];
        final desc = data['desc'] ?? '未知错误';
        print('XunfeiASR: 服务器错误 [$code] - $desc');
        onError?.call('服务器错误 [$code]: $desc');
      }
    } catch (e) {
      print('XunfeiASR: 解析消息失败 - $e');
      onError?.call('解析结果失败: $e');
    }
  }

  /// 处理 ASR 识别结果
  void _handleAsrResult(Map<String, dynamic> data) {
    try {
      final resultData = data['data'] as Map<String, dynamic>?;
      if (resultData == null) return;

      final cnData = resultData['cn'] as Map<String, dynamic>?;
      if (cnData == null) return;

      final stData = cnData['st'] as Map<String, dynamic>?;
      if (stData == null) return;

      final rtList = stData['rt'] as List<dynamic>?;
      if (rtList == null || rtList.isEmpty) return;

      // 拼接识别结果
      final buffer = StringBuffer();
      for (final rt in rtList) {
        final wsList = (rt as Map<String, dynamic>)['ws'] as List<dynamic>?;
        if (wsList != null) {
          for (final ws in wsList) {
            final cwList = (ws as Map<String, dynamic>)['cw'] as List<dynamic>?;
            if (cwList != null && cwList.isNotEmpty) {
              final word = (cwList[0] as Map<String, dynamic>)['w'] as String?;
              if (word != null) {
                buffer.write(word);
              }
            }
          }
        }
      }

      final text = buffer.toString();
      final isLast = resultData['ls'] == true; // 是否为最后一帧
      final type = stData['type'] as String?;
      final isFinal = type == '0'; // 0-确定性结果；1-中间结果

      if (text.isNotEmpty) {
        onResult?.call(text, isFinal || isLast);
      }
    } catch (e) {
      print('XunfeiASR: 处理识别结果失败 - $e');
    }
  }

  /// WebSocket 错误处理
  void _onWebSocketError(dynamic error) {
    print('XunfeiASR: WebSocket 错误 - $error');
    onError?.call('连接错误: $error');
    _cleanup();
  }

  /// WebSocket 连接关闭
  void _onWebSocketDone() {
    print('XunfeiASR: WebSocket 连接已关闭');
    _cleanup();
  }

  /// 生成鉴权 URL
  String _generateAuthUrl() {
    // 生成 UUID
    final uuid = _generateUuid();

    // 生成当前时间（ISO 8601 格式 + 时区）
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final offsetHours = offset.inHours;
    final offsetMinutes = offset.inMinutes.remainder(60);
    final utc =
        '${_formatDateTime(now)}${offsetHours >= 0 ? '+' : ''}${offsetHours.toString().padLeft(2, '0')}${offsetMinutes.abs().toString().padLeft(2, '0')}';

    // 构建请求参数（按字母顺序排序）
    final params = <String, String>{
      'accessKeyId': _accessKeyId,
      'appId': _appId,
      'audio_encode': 'pcm_s16le', // PCM 16kHz 16bit
      'lang': 'autodialect', // 中英 + 202种方言混合识别
      'samplerate': '16000',
      'utc': utc,
      'uuid': uuid,
    };

    // 生成 signature
    final signature = _generateSignature(params);
    params['signature'] = signature;

    // 构建完整 URL
    final queryString = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    return '$_baseUrl?$queryString';
  }

  /// 生成签名
  ///
  /// 1. 将所有参数（不包含 signature）按键名升序排序
  /// 2. 按照 "编码后的键=编码后的值&" 的格式拼接
  /// 3. 使用 accessKeySecret 进行 HMAC-SHA1 加密
  /// 4. 对结果进行 Base64 编码
  String _generateSignature(Map<String, String> params) {
    // 按键名升序排序
    final sortedKeys = params.keys.toList()..sort();

    // 拼接 baseString
    final baseString = sortedKeys
        .map(
          (key) =>
              '${Uri.encodeComponent(key)}=${Uri.encodeComponent(params[key]!)}',
        )
        .join('&');

    // HMAC-SHA1 加密
    final hmac = Hmac(sha1, utf8.encode(_accessKeySecret));
    final digest = hmac.convert(utf8.encode(baseString));

    // Base64 编码
    return base64Encode(digest.bytes);
  }

  /// 生成 UUID（简化版）
  String _generateUuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = (now % 1000000).toString().padLeft(6, '0');
    return '$now-$random';
  }

  /// 生成 Session ID（简化版）
  String _generateSessionId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'session_$now';
  }

  /// 格式化日期时间（ISO 8601 格式）
  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}'
        'T${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  /// 释放资源
  void dispose() {
    _cleanup();
  }
}
