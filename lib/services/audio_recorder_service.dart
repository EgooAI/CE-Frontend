import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

/// 音频录制服务（适配 Android/iOS/Web）
///
/// 封装 record 插件，提供统一的录音接口
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStream;

  /// 音频数据回调
  final void Function(Uint8List audioData)? onAudioData;

  /// 错误回调
  final void Function(String error)? onError;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  AudioRecorderService({this.onAudioData, this.onError});

  /// 开始录音
  ///
  /// 配置为 PCM 格式：16kHz, 16bit, 单声道
  /// 符合科大讯飞 API 要求
  Future<bool> startRecording() async {
    if (_isRecording) {
      print('AudioRecorder: 已经在录音中');
      return true;
    }

    try {
      // 检查权限
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        print('AudioRecorder: 没有麦克风权限');
        onError?.call('没有麦克风权限');
        return false;
      }

      // 配置录音参数（符合科大讯飞要求）
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits, // PCM 16bit
        sampleRate: 16000, // 16kHz
        numChannels: 1, // 单声道
        bitRate: 256000,
      );

      // 开始录音并获取音频流
      final stream = await _recorder.startStream(config);

      // 监听音频数据
      _audioStream = stream.listen(
        (audioData) {
          if (_isRecording) {
            onAudioData?.call(audioData);
          }
        },
        onError: (error) {
          print('AudioRecorder: 录音错误 - $error');
          onError?.call('录音错误: $error');
          stopRecording();
        },
        onDone: () {
          print('AudioRecorder: 录音流已关闭');
          stopRecording();
        },
      );

      _isRecording = true;
      print('AudioRecorder: 开始录音（PCM 16kHz 16bit 单声道）');
      return true;
    } catch (e) {
      print('AudioRecorder: 启动录音失败 - $e');
      onError?.call('启动录音失败: $e');
      return false;
    }
  }

  /// 停止录音
  Future<void> stopRecording() async {
    if (!_isRecording) {
      return;
    }

    try {
      await _audioStream?.cancel();
      _audioStream = null;

      await _recorder.stop();

      _isRecording = false;
      print('AudioRecorder: 录音已停止');
    } catch (e) {
      print('AudioRecorder: 停止录音失败 - $e');
      onError?.call('停止录音失败: $e');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await stopRecording();
    _recorder.dispose();
  }
}
