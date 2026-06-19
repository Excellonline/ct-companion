import 'dart:convert';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const cardTroveUpdateManifestUrl = 'https://cardtrove.help/updates.json';
const cardTroveAppcastUrl = 'https://cardtrove.help/appcast.xml';
const cardTroveDownloadsUrl = 'https://cardtrove.help/';

enum UpdateCheckStatus { unsupported, upToDate, available }

enum UpdateLaunchMode { nativeUpdater, downloadPage }

class UpdateCheckException implements Exception {
  final String message;
  const UpdateCheckException(this.message);

  @override
  String toString() => message;
}

class UpdateReleaseInfo {
  final String version;
  final String buildNumber;
  final String? releaseDate;
  final String? notes;
  final Uri? appcastUrl;
  final Uri? downloadUrl;
  final bool nativeAutoUpdate;

  const UpdateReleaseInfo({
    required this.version,
    required this.buildNumber,
    this.releaseDate,
    this.notes,
    this.appcastUrl,
    this.downloadUrl,
    this.nativeAutoUpdate = false,
  });

  String get displayVersion {
    if (buildNumber.isEmpty) {
      return version;
    }
    return '$version (build $buildNumber)';
  }
}

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final String currentVersion;
  final String currentBuildNumber;
  final UpdateReleaseInfo? release;

  const UpdateCheckResult({
    required this.status,
    required this.currentVersion,
    required this.currentBuildNumber,
    this.release,
  });

  String get currentDisplayVersion {
    if (currentBuildNumber.isEmpty) {
      return currentVersion;
    }
    return '$currentVersion (build $currentBuildNumber)';
  }
}

class UpdateService {
  const UpdateService({http.Client? client}) : _client = client;

  final http.Client? _client;

  static bool get isDesktopUpdateSupported {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  static String? get platformKey {
    if (kIsWeb) {
      return null;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      _ => null,
    };
  }

  Future<UpdateCheckResult> checkForUpdates() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final currentBuildNumber = packageInfo.buildNumber;
    final platform = platformKey;

    if (!isDesktopUpdateSupported || platform == null) {
      return UpdateCheckResult(
        status: UpdateCheckStatus.unsupported,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
      );
    }

    final release = await _fetchReleaseInfo(platform);
    final isNewer = isRemoteVersionNewer(
      currentVersion: currentVersion,
      currentBuildNumber: currentBuildNumber,
      remoteVersion: release.version,
      remoteBuildNumber: release.buildNumber,
    );

    return UpdateCheckResult(
      status: isNewer
          ? UpdateCheckStatus.available
          : UpdateCheckStatus.upToDate,
      currentVersion: currentVersion,
      currentBuildNumber: currentBuildNumber,
      release: release,
    );
  }

  Future<UpdateLaunchMode> downloadAndInstall(UpdateCheckResult result) async {
    if (result.status != UpdateCheckStatus.available) {
      return UpdateLaunchMode.downloadPage;
    }

    if (result.release?.nativeAutoUpdate != true) {
      await openDownloadPage(result);
      return UpdateLaunchMode.downloadPage;
    }

    final appcastUrl =
        result.release?.appcastUrl ??
        Uri.tryParse(cardTroveAppcastUrl) ??
        Uri.parse(cardTroveDownloadsUrl);

    try {
      await autoUpdater.setFeedURL(appcastUrl.toString());
      await autoUpdater.checkForUpdates();
      return UpdateLaunchMode.nativeUpdater;
    } catch (_) {
      await openDownloadPage(result);
      return UpdateLaunchMode.downloadPage;
    }
  }

  Future<void> openDownloadPage(UpdateCheckResult result) async {
    final url = result.release?.downloadUrl ?? Uri.parse(cardTroveDownloadsUrl);
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw const UpdateCheckException('Could not open the download page.');
    }
  }

  Future<UpdateReleaseInfo> _fetchReleaseInfo(String platform) async {
    final client = _client ?? http.Client();
    final shouldCloseClient = _client == null;
    try {
      final uri = Uri.parse(cardTroveUpdateManifestUrl);
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw UpdateCheckException(
          'The update server returned ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const UpdateCheckException('The update response was not valid.');
      }

      final platformDownload = _platformDownload(decoded, platform);
      final version = _stringValue(
        platformDownload?['version'] ?? decoded['version'],
      );
      final buildNumber = _stringValue(
        platformDownload?['buildNumber'] ?? decoded['buildNumber'],
      );
      if (version.isEmpty) {
        throw const UpdateCheckException(
          'The update response did not include a version.',
        );
      }

      if (platformDownload != null &&
          platformDownload.containsKey('available') &&
          platformDownload['available'] != true) {
        throw UpdateCheckException(
          'The ${_platformName(platform)} download is not available yet.',
        );
      }

      return UpdateReleaseInfo(
        version: version,
        buildNumber: buildNumber,
        releaseDate: _nullableStringValue(decoded['releaseDate']),
        notes: _nullableStringValue(decoded['notes']),
        appcastUrl: _uriValue(decoded['appcastUrl']),
        downloadUrl: _uriValue(platformDownload?['url']),
        nativeAutoUpdate: _boolValue(
          platformDownload?['nativeAutoUpdate'] ?? decoded['nativeAutoUpdate'],
        ),
      );
    } on UpdateCheckException {
      rethrow;
    } catch (error) {
      throw UpdateCheckException('Could not check for updates: $error');
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }

  static bool isRemoteVersionNewer({
    required String currentVersion,
    required String currentBuildNumber,
    required String remoteVersion,
    required String remoteBuildNumber,
  }) {
    final versionComparison = _compareVersions(remoteVersion, currentVersion);
    if (versionComparison != 0) {
      return versionComparison > 0;
    }

    final remoteBuild = int.tryParse(remoteBuildNumber);
    final currentBuild = int.tryParse(currentBuildNumber);
    if (remoteBuild != null && currentBuild != null) {
      return remoteBuild > currentBuild;
    }

    return remoteBuildNumber.compareTo(currentBuildNumber) > 0;
  }

  static int _compareVersions(String a, String b) {
    final aParts = _versionParts(a);
    final bParts = _versionParts(b);
    final maxLength = aParts.length > bParts.length
        ? aParts.length
        : bParts.length;

    for (var i = 0; i < maxLength; i++) {
      final aPart = i < aParts.length ? aParts[i] : 0;
      final bPart = i < bParts.length ? bParts[i] : 0;
      if (aPart != bPart) {
        return aPart.compareTo(bPart);
      }
    }
    return 0;
  }

  static List<int> _versionParts(String version) {
    return version
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
  }

  static Map<String, dynamic>? _platformDownload(
    Map<String, dynamic> decoded,
    String platform,
  ) {
    final downloads = decoded['downloads'];
    if (downloads is! Map) {
      return null;
    }

    final platformDownload = downloads[platform];
    if (platformDownload is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(platformDownload);
  }

  static String _stringValue(Object? value) => value?.toString().trim() ?? '';

  static String? _nullableStringValue(Object? value) {
    final string = _stringValue(value);
    return string.isEmpty ? null : string;
  }

  static Uri? _uriValue(Object? value) {
    final string = _nullableStringValue(value);
    return string == null ? null : Uri.tryParse(string);
  }

  static bool _boolValue(Object? value) => value == true;

  static String _platformName(String platform) {
    return switch (platform) {
      'macos' => 'macOS',
      'windows' => 'Windows',
      _ => platform,
    };
  }
}
