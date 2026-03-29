import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_constants.dart';

class UpdateService {
  static const String _serverUrl = AppConstants.activationServerUrl;

  static Future<Map<String, dynamic>?> checkUpdate() async {
    try {
      final response = await http.get(Uri.parse("$_serverUrl/update/latest"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data['version'] as String;
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (_isNewer(latestVersion, currentVersion)) {
          return data;
        }
      }
    } catch (e) {
      print("[UpdateService] Yangilanishni tekshirishda xatolik: $e");
    }
    return null;
  }

  static bool _isNewer(String latest, String current) {
    try {
      // Remove build metadata (e.g., 1.22.37+37 -> 1.22.37)
      String latestClean = latest.contains('+') ? latest.split('+')[0] : latest;
      String currentClean = current.contains('+') ? current.split('+')[0] : current;

      List<int> latestParts = latestClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> currentParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static String getFinalUrl(String url) {
    String finalUrl = url.startsWith('http') ? url : "$_serverUrl$url";
    if (finalUrl.contains('drive.google.com/file/d/')) {
      final idMatch = RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(finalUrl);
      if (idMatch != null) {
        final fileId = idMatch.group(1);
        return 'https://drive.google.com/uc?export=download&id=$fileId&confirm=t';
      }
    }
    return finalUrl;
  }

  static Future<void> openDownloadPage(String url) async {
    final fullUrl = getFinalUrl(url);
    if (await canLaunchUrl(Uri.parse(fullUrl))) {
      await launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication);
    }
  }
}
