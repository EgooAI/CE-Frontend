import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import '../core/api_client.dart';

class AppVersionInfo {
  final String latestVersion;
  final bool forceUpdate;
  final String minForcedVersion;

  const AppVersionInfo({
    required this.latestVersion,
    required this.forceUpdate,
    required this.minForcedVersion,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) => AppVersionInfo(
    latestVersion: json['latestVersion'] as String? ?? '0.0.0',
    forceUpdate: json['forceUpdate'] as bool? ?? false,
    minForcedVersion: json['minForcedVersion'] as String? ?? '0.0.0',
  );
}

class AppChangelog {
  final String version;
  final String releaseDate;
  final String content;

  const AppChangelog({
    required this.version,
    required this.releaseDate,
    required this.content,
  });

  factory AppChangelog.fromJson(Map<String, dynamic> json) => AppChangelog(
    version: json['version'] as String? ?? '',
    releaseDate: json['releaseDate'] as String? ?? '',
    content: json['content'] as String? ?? '',
  );
}

class AppReleaseService {
  String get _platform {
    if (kIsWeb) return 'android';
    return Platform.isIOS ? 'ios' : 'android';
  }

  Future<AppVersionInfo> getLatestVersion() async {
    try {
      final response = await ApiClient.instance.get(
        '/app/version',
        queryParameters: {'platform': _platform},
      );

      if (response.data is! Map<String, dynamic>) {
        throw Exception('版本信息格式错误');
      }
      return AppVersionInfo.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      rethrow;
    }
  }

  Future<List<AppChangelog>> getChangelogs({String? fromVersion}) async {
    try {
      final query = <String, dynamic>{'platform': _platform};
      if (fromVersion != null && fromVersion.trim().isNotEmpty) {
        query['fromVersion'] = fromVersion.trim();
      }

      final response = await ApiClient.instance.get(
        '/app/changelog',
        queryParameters: query,
      );

      if (response.data is! List) return const [];
      final list = response.data as List;
      return list
          .whereType<Map>()
          .map((e) => AppChangelog.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      rethrow;
    }
  }

  Future<String> getDownloadUrl() async {
    try {
      final response = await ApiClient.instance.get(
        '/app/download',
        queryParameters: {'platform': _platform},
      );

      if (response.data is! Map<String, dynamic>) {
        throw Exception('下载链接格式错误');
      }
      final map = response.data as Map<String, dynamic>;
      final url = map['downloadUrl'] as String?;
      if (url == null || url.isEmpty) {
        throw Exception('下载链接为空');
      }
      return url;
    } catch (_) {
      rethrow;
    }
  }
}
