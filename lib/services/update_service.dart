import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_app_file/open_app_file.dart';

class UpdateService {
  static const String _activationServerUrl = "https://web-production-d2ed7.up.railway.app";

  static Future<Map<String, dynamic>?> checkUpdate() async {
    try {
      final response = await http.get(Uri.parse("$_activationServerUrl/update/latest"));
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
      print("Yangilanishni tekshirishda xatolik: $e");
    }
    return null;
  }

  static bool _isNewer(String latest, String current) {
    List<int> latestParts = latest.split('.').map(int.parse).toList();
    List<int> currentParts = current.split('.').map(int.parse).toList();

    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  static Future<void> downloadAndInstall(String downloadUrl, Function(double) onProgress) async {
    final client = http.Client();
    try {
      final fullUrl = downloadUrl.startsWith('http') ? downloadUrl : "$_activationServerUrl$downloadUrl";
      final request = http.Request('GET', Uri.parse(fullUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception("Serverdan xato javob keldi: ${response.statusCode}");
      }

      final contentLength = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final fileName = downloadUrl.split('/').last;
      final file = File('${tempDir.path}/$fileName');
      
      // Agar eski fayl bo'lsa o'chirib tashlaymiz
      if (await file.exists()) {
        await file.delete();
      }

      final sink = file.openWrite();
      int downloadedLength = 0;

      await for (var chunk in response.stream) {
        sink.add(chunk);
        downloadedLength += chunk.length;
        if (contentLength > 0) {
          onProgress(downloadedLength / contentLength);
        }
      }

      await sink.flush();
      await sink.close();

      if (Platform.isWindows) {
        // Windows uchun avtomatik (silent) o'rnatish
        await Process.start(file.path, ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/SP-', '/NOCANCEL', '/NORESTART']);
        
        await Future.delayed(const Duration(seconds: 1));
        exit(0); 
      } else {
        await OpenAppFile.open(file.path);
      }
    } catch (e) {
      print("Yuklab olish yoki o'rnatishda xatolik: $e");
      rethrow;
    } finally {
      client.close();
    }
  }

  static Future<void> openDownloadPage(String url) async {
    final fullUrl = url.startsWith('http') ? url : "$_activationServerUrl$url";
    if (await canLaunchUrl(Uri.parse(fullUrl))) {
      await launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication);
    }
  }
}
