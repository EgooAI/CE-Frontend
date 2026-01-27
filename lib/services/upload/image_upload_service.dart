import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

/// 图片信息
class ImageInfo {
  final String key; // OSS对象Key（永久有效，存数据库）
  final String url; // 预签名URL（临时有效，用于立即展示）
  final String filename;
  final int size;

  ImageInfo({
    required this.key,
    required this.url,
    required this.filename,
    required this.size,
  });

  factory ImageInfo.fromJson(Map<String, dynamic> json) {
    return ImageInfo(
      key: json['key'] as String,
      url: json['url'] as String,
      filename: json['filename'] as String,
      size: json['size'] as int,
    );
  }
}

/// 图片上传服务
class ImageUploadService {
  /// 上传图片（字节数据）
  ///
  /// [bytes] - 图片字节
  /// [filename] - 文件名（用于服务端识别扩展名）
  Future<ImageInfo> uploadImageBytes(
    Uint8List bytes, {
    String filename = 'paste.png',
  }) async {
    print('[ImageUploadService] 📤 准备上传图片字节');
    print('[ImageUploadService] 📁 文件名: $filename');
    print('[ImageUploadService] 📊 文件大小: ${bytes.length} 字节');

    try {
      // 检查文件大小（5MB限制）
      if (bytes.length > 5 * 1024 * 1024) {
        print(
          '[ImageUploadService] ❌ 文件过大: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB',
        );
        throw Exception('文件大小超过5MB限制');
      }

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });

      final response = await ApiClient.instance.post(
        '/upload/image',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('key') && data.containsKey('url')) {
          return ImageInfo.fromJson(data);
        }
      }

      throw Exception('响应数据缺少必要字段');
    } on DioException catch (e) {
      if (e.response?.data is Map<String, dynamic>) {
        final data = e.response!.data as Map<String, dynamic>;
        final errorMsg = data['message'] ?? '上传失败';
        throw Exception(errorMsg);
      }

      String errorMsg;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          errorMsg = '连接超时，请检查网络';
          break;
        case DioExceptionType.sendTimeout:
          errorMsg = '上传超时，请重试';
          break;
        case DioExceptionType.receiveTimeout:
          errorMsg = '服务器响应超时';
          break;
        case DioExceptionType.connectionError:
          errorMsg = '网络连接失败，请检查网络设置';
          break;
        case DioExceptionType.badResponse:
          errorMsg = '服务器错误 (${e.response?.statusCode})';
          break;
        default:
          errorMsg = '网络错误: ${e.message}';
      }
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('上传失败: $e');
    }
  }

  /// 上传图片
  ///
  /// [file] - 图片文件
  /// 返回图片信息（包含URL）
  Future<ImageInfo> uploadImage(File file) async {
    print('[ImageUploadService] 📤 准备上传图片');
    print('[ImageUploadService] 📁 文件路径: ${file.path}');

    try {
      // 检查文件是否存在
      if (!await file.exists()) {
        print('[ImageUploadService] ❌ 文件不存在');
        throw Exception('文件不存在');
      }

      final fileSize = await file.length();
      print('[ImageUploadService] 📊 文件大小: $fileSize 字节');

      // 检查文件大小（5MB限制）
      if (fileSize > 5 * 1024 * 1024) {
        print(
          '[ImageUploadService] ❌ 文件过大: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
        );
        throw Exception('文件大小超过5MB限制');
      }

      // 创建 FormData
      print('[ImageUploadService] 📦 创建 FormData');
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      // 发送请求
      print('[ImageUploadService] 🌐 发送 POST 请求到 /upload/image');
      final response = await ApiClient.instance.post(
        '/upload/image',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      print('[ImageUploadService] 📥 收到响应');
      print('[ImageUploadService] HTTP 状态码: ${response.statusCode}');
      print('[ImageUploadService] 响应数据类型: ${response.data.runtimeType}');
      print('[ImageUploadService] 响应数据: ${response.data}');

      // 注意：ApiClient 拦截器已经自动提取了 data 字段
      // 所以这里收到的 response.data 已经是解包后的数据
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;

        if (data.containsKey('key') && data.containsKey('url')) {
          print('[ImageUploadService] ✅ 解析成功');
          final imageInfo = ImageInfo.fromJson(data);
          print('[ImageUploadService] Key: ${imageInfo.key}');
          print('[ImageUploadService] URL 长度: ${imageInfo.url.length}');
          return imageInfo;
        }
      }

      print('[ImageUploadService] ❌ 响应格式错误');
      print('[ImageUploadService] 期望格式: {key, url, filename, size}');
      print('[ImageUploadService] 实际收到: ${response.data}');
      throw Exception('响应数据缺少必要字段');
    } on DioException catch (e) {
      print('[ImageUploadService] ❌ Dio 异常');
      print('[ImageUploadService] 错误类型: ${e.type}');
      print('[ImageUploadService] 错误信息: ${e.message}');
      print('[ImageUploadService] HTTP 状态码: ${e.response?.statusCode}');
      print('[ImageUploadService] 响应数据: ${e.response?.data}');

      if (e.response?.data is Map<String, dynamic>) {
        final data = e.response!.data as Map<String, dynamic>;
        final errorMsg = data['message'] ?? '上传失败';
        print('[ImageUploadService] 服务器错误信息: $errorMsg');
        throw Exception(errorMsg);
      }

      // 根据不同的错误类型提供更友好的错误信息
      String errorMsg;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          errorMsg = '连接超时，请检查网络';
          break;
        case DioExceptionType.sendTimeout:
          errorMsg = '上传超时，请重试';
          break;
        case DioExceptionType.receiveTimeout:
          errorMsg = '服务器响应超时';
          break;
        case DioExceptionType.connectionError:
          errorMsg = '网络连接失败，请检查网络设置';
          break;
        case DioExceptionType.badResponse:
          errorMsg = '服务器错误 (${e.response?.statusCode})';
          break;
        default:
          errorMsg = '网络错误: ${e.message}';
      }

      print('[ImageUploadService] 最终错误信息: $errorMsg');
      throw Exception(errorMsg);
    } catch (e) {
      print('[ImageUploadService] ❌ 未知异常');
      print('[ImageUploadService] 错误类型: ${e.runtimeType}');
      print('[ImageUploadService] 错误信息: $e');
      throw Exception('上传失败: $e');
    }
  }
}
