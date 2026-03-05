import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/app_release/app_release_service.dart';
import '../../../widgets/common/app_snack_bar.dart';

class CheckUpdatePage extends StatefulWidget {
  const CheckUpdatePage({super.key});

  @override
  State<CheckUpdatePage> createState() => _CheckUpdatePageState();
}

class _CheckUpdatePageState extends State<CheckUpdatePage> {
  final AppReleaseService _releaseService = AppReleaseService();

  String? _currentVersion;
  AppVersionInfo? _versionInfo;
  List<AppChangelog> _changelogs = [];
  bool _isLoadingVersion = true;
  bool _isLoadingChangelogs = true;
  bool _isLoadingDownload = false;
  String? _versionError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    String currentVersion = _currentVersion ?? '0.0.0';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      currentVersion = packageInfo.version.split('+').first;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentVersion = currentVersion;
        _versionInfo = null;
        _changelogs = [];
        _isLoadingVersion = true;
        _isLoadingChangelogs = true;
        _versionError = null;
      });
    }

    final futureA = _releaseService
        .getLatestVersion()
        .then((version) {
          if (!mounted) return;
          setState(() {
            _versionInfo = version;
            _isLoadingVersion = false;
          });
        })
        .catchError((e) {
          if (!mounted) return;
          setState(() {
            _versionError = e.toString();
            _isLoadingVersion = false;
          });
        });

    final futureB = _releaseService
        .getChangelogs(fromVersion: currentVersion)
        .then((logs) {
          if (!mounted) return;
          setState(() {
            _changelogs = logs;
            _isLoadingChangelogs = false;
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() {
            _isLoadingChangelogs = false;
          });
        });

    await Future.wait([futureA, futureB]);
  }

  bool _hasNewVersion(String current, String latest) {
    final c = _parseVersion(current);
    final l = _parseVersion(latest);
    for (var i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  List<int> _parseVersion(String v) {
    final parts = v.split('.');
    return List.generate(
      3,
      (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0,
    );
  }

  Future<void> _onDownloadPressed() async {
    if (_isLoadingDownload) return;
    setState(() => _isLoadingDownload = true);
    try {
      final downloadUrl = await _releaseService.getDownloadUrl();
      final uri = Uri.parse(downloadUrl);
      final ok = await canLaunchUrl(uri);
      if (!ok) {
        if (!mounted) return;
        showAppSnackBar(context, const SnackBar(content: Text('无法打开下载链接')));
        return;
      }
      await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, SnackBar(content: Text('获取下载地址失败: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoadingDownload = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentVersion = _currentVersion ?? '加载中...';
    final latestVersion = _versionInfo?.latestVersion;
    final hasNewVersion =
        latestVersion != null && _hasNewVersion(currentVersion, latestVersion);

    return Scaffold(
      appBar: AppBar(title: const Text('检查更新')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildVersionCard(
              currentVersion: currentVersion,
              latestVersion: latestVersion,
              hasNewVersion: hasNewVersion,
            ),
            if (_versionInfo != null && hasNewVersion)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingDownload ? null : _onDownloadPressed,
                    icon: _isLoadingDownload
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text('下载最新版本 v${_versionInfo!.latestVersion}'),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              '更新日志',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (_isLoadingChangelogs)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_changelogs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    '暂无更新日志',
                    style: TextStyle(color: Color(0xFF8A8F98)),
                  ),
                ),
              )
            else
              ListView.builder(
                itemCount: _changelogs.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) =>
                    _buildChangelogItem(_changelogs[index]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionCard({
    required String currentVersion,
    required String? latestVersion,
    required bool hasNewVersion,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: Color(0xFF607D8B),
              ),
              const SizedBox(width: 8),
              const Text('当前版本'),
              const Spacer(),
              Text(
                currentVersion,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingVersion)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('正在获取最新版本...'),
              ],
            )
          else if (_versionError != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, size: 18, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '获取版本失败：$_versionError',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(onPressed: _initialize, child: const Text('重试')),
              ],
            )
          else
            Row(
              children: [
                const Icon(Icons.new_releases_outlined, size: 18),
                const SizedBox(width: 8),
                const Text('最新版本'),
                const Spacer(),
                Text(
                  latestVersion ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                _buildBadge(hasNewVersion),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(bool hasNewVersion) {
    final bg = hasNewVersion
        ? const Color(0xFFE8F0FF)
        : const Color(0xFFF1F3F5);
    final fg = hasNewVersion
        ? const Color(0xFF2C63D6)
        : const Color(0xFF7C838D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        hasNewVersion ? '有新版本' : '已是最新',
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildChangelogItem(AppChangelog item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF3FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.version,
                    style: const TextStyle(
                      color: Color(0xFF2C63D6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  item.releaseDate,
                  style: const TextStyle(
                    color: Color(0xFF8A8F98),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.content),
          ],
        ),
      ),
    );
  }
}
