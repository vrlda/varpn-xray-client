import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/routing_settings.dart';
import 'app_log_service.dart';
import 'macos_tunnel_bridge.dart';

class GeodataService {
  static const _latestReleaseUrl =
      'https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases/latest';

  static Future<RoutingSettings> fetchLatestMetadata(
    RoutingSettings settings,
  ) async {
    final response = await http.get(
      Uri.parse(_latestReleaseUrl),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'VarPN',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('GitHub release request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Unexpected GitHub release response');
    }

    final publishedAt = DateTime.tryParse(
      decoded['published_at']?.toString() ?? '',
    );
    final assets = (decoded['assets'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (asset) => asset.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        )
        .toList();

    final geosite = _findAsset(assets, 'geosite.dat');
    final geoip = _findAsset(assets, 'geoip.dat');

    return settings.copyWith(
      geositeUrl: geosite?.browserDownloadUrl ?? settings.geositeUrl,
      geoipUrl: geoip?.browserDownloadUrl ?? settings.geoipUrl,
      geositeUpdatedAt: publishedAt ?? settings.geositeUpdatedAt,
      geoipUpdatedAt: publishedAt ?? settings.geoipUpdatedAt,
      geositeBytes: geosite?.size ?? settings.geositeBytes,
      geoipBytes: geoip?.size ?? settings.geoipBytes,
    );
  }

  static Future<RoutingSettings> refreshGeodata(
    RoutingSettings settings,
  ) async {
    AppLogService.instance.info(
      source: 'geodata',
      message: 'Refreshing geosite.dat and geoip.dat from GitHub.',
    );
    final updatedSettings = await fetchLatestMetadata(settings);
    final directory = await _assetDirectory();

    await _downloadFile(
      updatedSettings.geositeUrl,
      File('${directory.path}/geosite.dat'),
    );
    await _downloadFile(
      updatedSettings.geoipUrl,
      File('${directory.path}/geoip.dat'),
    );

    AppLogService.instance.info(
      source: 'geodata',
      message: 'Geodata refresh completed.',
    );

    return updatedSettings;
  }

  static Future<String> ensureAssetDirectory({
    required String bundledAssetDirectory,
  }) async {
    final directory = await _assetDirectory();
    await directory.create(recursive: true);

    await _ensureBundledFile(
      sourcePath: '$bundledAssetDirectory/geosite.dat',
      targetPath: '${directory.path}/geosite.dat',
    );
    await _ensureBundledFile(
      sourcePath: '$bundledAssetDirectory/geoip.dat',
      targetPath: '${directory.path}/geoip.dat',
    );

    return directory.path;
  }

  static Future<Directory> _assetDirectory() async {
    if (Platform.isMacOS || Platform.isIOS) {
      final sharedContainerPath = await MacosTunnelBridge.sharedContainerPath();
      if (sharedContainerPath != null && sharedContainerPath.isNotEmpty) {
        return Directory('$sharedContainerPath/geodata');
      }
    }

    final supportDirectory = await getApplicationSupportDirectory();
    return Directory('${supportDirectory.path}/geodata');
  }

  static Future<void> _ensureBundledFile({
    required String sourcePath,
    required String targetPath,
  }) async {
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      return;
    }

    final sourceFile = File(sourcePath);
    if (await sourceFile.exists()) {
      await sourceFile.copy(targetPath);
      return;
    }

    if (Platform.isIOS) {
      final assetPath = sourcePath
          .replaceAll('\\', '/')
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList();
      final assetName = assetPath.isNotEmpty ? assetPath.last : '';
      if (assetName.isEmpty) {
        return;
      }

      final bundledAssetPath = 'xray-core/$assetName';
      try {
        final data = await rootBundle.load(bundledAssetPath);
        await targetFile.parent.create(recursive: true);
        await targetFile.writeAsBytes(
          data.buffer.asUint8List(),
          flush: true,
        );
      } catch (_) {
        // Ignore missing bundled assets and leave the file absent.
      }
    }
  }

  static Future<void> _downloadFile(
    String sourceUrl,
    File targetFile,
  ) async {
    final response = await http.get(
      Uri.parse(sourceUrl),
      headers: const {
        'User-Agent': 'VarPN',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    await targetFile.parent.create(recursive: true);
    await targetFile.writeAsBytes(response.bodyBytes, flush: true);
  }

  static _ReleaseAsset? _findAsset(
    List<Map<String, dynamic>> assets,
    String name,
  ) {
    for (final asset in assets) {
      if (asset['name']?.toString() == name) {
        return _ReleaseAsset(
          name: name,
          browserDownloadUrl: asset['browser_download_url']?.toString() ?? '',
          size: _parseInt(asset['size']),
        );
      }
    }
    return null;
  }

  static int? _parseInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }
}

class _ReleaseAsset {
  final String name;
  final String browserDownloadUrl;
  final int? size;

  const _ReleaseAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.size,
  });
}
