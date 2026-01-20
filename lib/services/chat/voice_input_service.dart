import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import './xfyun_asr_service.dart';
import './audio_recorder_service.dart';

/// 语音输入服务 - 统一管理跨平台语音识别
class VoiceInputService {
  // iOS 语音识别
  stt.SpeechToText? _speechToText;

  // Android/Web 语音识别
  XunfeiAsrService? _xunfeiAsr;
  AudioRecorderService? _audioRecorder;

  bool _isListening = false;
  String _recognizedText = ''; // 已确认文本
  String _tempRecognizedText = ''; // 临时文本

  /// 初始化语音服务
  Future<void> initialize({
    required Function(String text, bool isFinal) onResult,
    required Function(String error) onError,
  }) async {
    if (kIsWeb) {
      print('Web 平台语音识别功能暂未启用');
      return;
    }

    if (Platform.isAndroid) {
      // Android：使用科大讯飞
      _xunfeiAsr = XunfeiAsrService(
        onResult: (text, isFinal) {
          if (isFinal) {
            _recognizedText += text;
            _tempRecognizedText = '';
          } else {
            _tempRecognizedText = text;
          }
          onResult(_recognizedText + _tempRecognizedText, isFinal);
        },
        onError: onError,
        onConnectionChanged: (connected) {
          if (!connected && _isListening) {
            _isListening = false;
          }
        },
      );

      _audioRecorder = AudioRecorderService(
        onAudioData: (audioData) {
          _xunfeiAsr?.sendAudio(audioData);
        },
        onError: onError,
      );
    } else if (Platform.isIOS) {
      // iOS：使用 speech_to_text
      _speechToText = stt.SpeechToText();
      await _speechToText!.initialize(
        onError: (error) => onError(error.errorMsg),
        onStatus: (status) {
          if (status == 'notListening' && _isListening) {
            _isListening = false;
          }
        },
      );
    }
  }

  /// 开始监听
  Future<bool> startListening({
    required Function(String text, bool isFinal) onResult,
  }) async {
    if (_isListening) return false;

    _isListening = true;
    _recognizedText = '';
    _tempRecognizedText = '';

    if (Platform.isIOS && _speechToText != null) {
      // iOS
      await _speechToText!.listen(
        onResult: (result) {
          if (result.finalResult) {
            _recognizedText += result.recognizedWords;
            _tempRecognizedText = '';
          } else {
            _tempRecognizedText = result.recognizedWords;
          }
          onResult(_recognizedText + _tempRecognizedText, result.finalResult);
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'zh_CN',
      );
      return true;
    } else if ((kIsWeb || Platform.isAndroid) &&
        _xunfeiAsr != null &&
        _audioRecorder != null) {
      if (kIsWeb) {
        _isListening = false;
        return false;
      }

      // Android
      try {
        await _xunfeiAsr!.start();
        final success = await _audioRecorder!.startRecording();
        if (!success) {
          _isListening = false;
        }
        return success;
      } catch (e) {
        _isListening = false;
        return false;
      }
    }

    return false;
  }

  /// 停止监听
  Future<void> stopListening() async {
    if (!_isListening) return;

    if (Platform.isIOS && _speechToText != null) {
      await _speechToText!.stop();
    } else if ((kIsWeb || Platform.isAndroid) &&
        _xunfeiAsr != null &&
        _audioRecorder != null) {
      await _audioRecorder!.stopRecording();
      await _xunfeiAsr!.stop();
    }

    _isListening = false;
  }

  /// 切换监听状态
  Future<bool> toggleListening({
    required Function(String text, bool isFinal) onResult,
  }) async {
    if (_isListening) {
      await stopListening();
      return false;
    } else {
      return await startListening(onResult: onResult);
    }
  }

  /// 释放资源
  void dispose() {
    _speechToText?.stop();
    _xunfeiAsr?.dispose();
    _audioRecorder?.dispose();
  }

  /// 是否正在监听
  bool get isListening => _isListening;

  /// 是否支持语音识别
  bool get isSupported => !kIsWeb;
}
