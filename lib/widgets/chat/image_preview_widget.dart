import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// 图片附件数据模型
class ImageAttachment {
  final File? file; // 本地文件
  final Uint8List? bytes; // 内存图片数据（粘贴）
  final String? key; // OSS对象Key（存数据库）
  final String? url; // 预签名URL（临时展示）
  final String name; // 文件名
  final bool isUploading; // 是否正在上传
  final String? error; // 上传错误信息

  ImageAttachment({
    this.file,
    this.bytes,
    this.key,
    this.url,
    required this.name,
    this.isUploading = false,
    this.error,
  });

  ImageAttachment copyWith({
    File? file,
    Uint8List? bytes,
    String? key,
    String? url,
    String? name,
    bool? isUploading,
    String? error,
  }) {
    return ImageAttachment(
      file: file ?? this.file,
      bytes: bytes ?? this.bytes,
      key: key ?? this.key,
      url: url ?? this.url,
      name: name ?? this.name,
      isUploading: isUploading ?? this.isUploading,
      error: error ?? this.error,
    );
  }
}

/// 图片预览组件（模仿微信UI）
class ImagePreviewWidget extends StatelessWidget {
  final List<ImageAttachment> images;
  final VoidCallback onAddImage;
  final Function(int index) onRemoveImage;

  const ImagePreviewWidget({
    super.key,
    required this.images,
    required this.onAddImage,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length + 1, // +1 for add button
        itemBuilder: (context, index) {
          // 添加按钮
          if (index == images.length) {
            if (images.length >= 9) return const SizedBox.shrink(); // 最多9张
            return _buildAddButton();
          }

          // 图片项
          final image = images[index];
          return _buildImageItem(image, index);
        },
      ),
    );
  }

  /// 构建添加按钮
  Widget _buildAddButton() {
    return GestureDetector(
      onTap: onAddImage,
      child: Container(
        width: 84,
        height: 84,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: const Icon(Icons.add, size: 32, color: Color(0xFF999999)),
      ),
    );
  }

  /// 构建图片项
  Widget _buildImageItem(ImageAttachment image, int index) {
    return Container(
      width: 84,
      height: 84,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          // 图片预览
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image.bytes != null
                ? Image.memory(
                    image.bytes!,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                  )
                : image.file != null
                    ? Image.file(
                        image.file!,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 84,
                        height: 84,
                        color: const Color(0xFFF5F5F5),
                        child: const Icon(Icons.image, size: 32),
                      ),
          ),

          // 上传中遮罩
          if (image.isUploading)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),

          // 错误遮罩
          if (image.error != null)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.error_outline, color: Colors.white, size: 32),
              ),
            ),

          // 删除按钮
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => onRemoveImage(index),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFF333333),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
