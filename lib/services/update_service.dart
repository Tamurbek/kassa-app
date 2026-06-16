import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class UpdateService {
  static Future<Map<String, dynamic>?> checkUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString('serverBaseUrl') ?? AppConstants.activationServerUrl;

      // Professional: Add timestamp to bypass any server or CDN caching
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse("$serverUrl/update/latest?t=$timestamp"),
        headers: {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data['version'] as String;
        
        final packageInfo = await PackageInfo.fromPlatform();
        // current will be something like "1.22.71+71"
        final currentVersion = "${packageInfo.version}+${packageInfo.buildNumber}";

        if (_isNewer(latestVersion, currentVersion)) {
          return data;
        }
      }
    } catch (e) {
      print("[UpdateService] Professional check failed: $e");
    }
    return null;
  }

  static bool _isNewer(String latest, String current) {
    try {
      // 1. Separate version from build number
      // latest: 1.22.73+73
      // current: 1.22.71+71
      final latestPart = latest.toLowerCase().replaceFirst('v', '').split('+')[0];
      final latestBuild = latest.contains('+') ? int.tryParse(latest.split('+')[1]) ?? 0 : 0;
      
      final currentPart = current.toLowerCase().replaceFirst('v', '').split('+')[0];
      final currentBuild = current.contains('+') ? int.tryParse(current.split('+')[1]) ?? 0 : 0;

      // 2. Compare main version parts (1.22.73)
      List<int> latestParts = latestPart.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> currentParts = currentPart.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      
      // 3. If main version is identical, compare build numbers
      if (latestBuild > currentBuild) return true;

      return false;
    } catch (e) {
      return false;
    }
  }

  static String getFinalUrl(String url, {String? customServerUrl}) {
    final serverUrl = customServerUrl ?? AppConstants.activationServerUrl;
    String finalUrl = url.startsWith('http') ? url : "$serverUrl$url";
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
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('serverBaseUrl') ?? AppConstants.activationServerUrl;
    final fullUrl = getFinalUrl(url, customServerUrl: serverUrl);
    if (await canLaunchUrl(Uri.parse(fullUrl))) {
      await launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication);
    }
  }
}
