import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_app_file/open_app_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/update_service.dart';

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.version,
    required this.url,
    this.isMandatory = false,
  });

  final String version;
  final String url;
  final bool isMandatory;

  static void show(BuildContext context, String version, String url, {bool isMandatory = false}) {
    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (context) => AppUpdateDialog(
        version: version,
        url: url,
        isMandatory: isMandatory,
      ),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool isDownloading = false;
  double downloadProgress = 0.0;
  String? errorMessage;

  String _getDownloadUrl() {
    const activationServerUrl = "https://web-production-d2ed7.up.railway.app";
    return widget.url.startsWith('http') ? widget.url : "$activationServerUrl${widget.url}";
  }

  Future<void> _startUpdate(BuildContext context) async {
    if (Platform.isAndroid) {
      await _downloadAndInstallApk(context);
    } else if (Platform.isWindows) {
      await _downloadAndInstallExe(context);
    } else if (Platform.isMacOS) {
      await _downloadAndInstallMacOS(context);
    } else {
      await UpdateService.openDownloadPage(widget.url);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _downloadAndInstallApk(BuildContext context) async {
    // Request permissions for Android
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        setState(() {
          errorMessage = 'Xotiraga ruxsat berilmadi. Iltimos, sozlamalardan ruxsat bering.';
        });
        return;
      }
    }

    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
      errorMessage = null;
    });

    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.url.split('/').last;
      final filePath = '${tempDir.path}/$fileName';

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      await dio.download(
        _getDownloadUrl(),
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              downloadProgress = received / total;
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        isDownloading = false;
      });

      // Install using open_app_file
      final result = await OpenAppFile.open(filePath);
      if (result.type != ResultType.done) {
        setState(() {
          errorMessage = 'O\'rnatishni boshlab bo\'lmadi: ${result.message}';
        });
      } else {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isDownloading = false;
        errorMessage = 'Yuklab olishda xatolik: ${e.toString()}';
      });
    }
  }

  Future<void> _downloadAndInstallExe(BuildContext context) async {
    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
      errorMessage = null;
    });

    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.url.split('/').last;
      final filePath = '${tempDir.path}/$fileName';

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      await dio.download(
        _getDownloadUrl(),
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              downloadProgress = received / total;
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        isDownloading = false;
      });

      // Windows uchun avtomatik (silent) o'rnatish
      await Process.start(filePath, ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/SP-', '/NOCANCEL', '/NORESTART']);
      
      await Future.delayed(const Duration(seconds: 1));
      exit(0); 
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isDownloading = false;
        errorMessage = 'Yuklab olishda xatolik: ${e.toString()}';
      });
    }
  }

  Future<void> _downloadAndInstallMacOS(BuildContext context) async {
    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
      errorMessage = null;
    });

    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.url.split('/').last;
      final filePath = '${tempDir.path}/$fileName';

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      await dio.download(
        _getDownloadUrl(),
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              downloadProgress = received / total;
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        isDownloading = false;
      });

      // macOS da .dmg yoki .pkg faylni ochish
      final result = await OpenAppFile.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Faylni ochib bo\'lmadi: ${result.message}');
      }
      
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isDownloading = false;
        errorMessage = 'Yuklab olishda xatolik: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isMandatory && !isDownloading,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Yangi versiya'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Simple Sale v${widget.version} mavjud.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Dasturni yangilash tavsiya etiladi. Bu yangi funksiyalar va xatoliklar tuzatilishini ta\'minlaydi.'),
            if (isDownloading) ...[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: downloadProgress,
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 8),
              Center(child: Text('${(downloadProgress * 100).toStringAsFixed(0)}%')),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          if (!widget.isMandatory && !isDownloading)
            TextButton(
              child: const Text('Keyinroq'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          if (!isDownloading)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Hozir yangilash'),
              onPressed: () => _startUpdate(context),
            ),
        ],
      ),
    );
  }
}
