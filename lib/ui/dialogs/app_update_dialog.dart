import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_app_file/open_app_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:ui'; // For BackdropFilter

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
    showGeneralDialog(
      context: context,
      barrierDismissible: !isMandatory,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => AppUpdateDialog(
        version: version,
        url: url,
        isMandatory: isMandatory,
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool isDownloading = false;
  bool isInstalling = false;
  double downloadProgress = 0.0;
  String? errorMessage;
  String? downloadedBytesStr;
  String? totalBytesStr;
  
  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.toString().length - 1) ~/ 3;
    var res = (bytes / (1024 * i)).toStringAsFixed(decimals);
    // Simple manual index for suffixes
    if (bytes < 1024) return "${bytes} B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(decimals)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(decimals)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(decimals)} GB";
  }

  String _getDownloadUrl() {
    const activationServerUrl = "https://web-production-d2ed7.up.railway.app";
    String url = widget.url.startsWith('http') ? widget.url : "$activationServerUrl${widget.url}";
    
    // Google Drive URL transformation
    if (url.contains('drive.google.com/file/d/')) {
      final idMatch = RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(url);
      if (idMatch != null) {
        final fileId = idMatch.group(1);
        return 'https://drive.google.com/uc?export=download&id=$fileId&confirm=t';
      }
    }
    return url;
  }

  Future<void> _startUpdate() async {
    if (Platform.isAndroid) {
      await _downloadAndHandleUpdate();
    } else if (Platform.isWindows) {
      await _downloadAndHandleUpdate();
    } else if (Platform.isMacOS) {
      await _downloadAndHandleUpdate();
    } else {
      // For Linux or others, just open link
      Navigator.pop(context);
    }
  }

  Future<void> _downloadAndHandleUpdate() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted && !await Permission.manageExternalStorage.request().isGranted) {
         setState(() { errorMessage = 'Fayllarni saqlash uchun ruxsat kerak.'; });
         return;
      }
    }

    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
      errorMessage = null;
      isInstalling = false;
    });

    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final downloadUrl = _getDownloadUrl();
      final uri = Uri.parse(downloadUrl);
      
      String fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'update_file';
      if (Platform.isWindows && !fileName.toLowerCase().endsWith('.exe') && !fileName.toLowerCase().endsWith('.msi')) {
        fileName = 'SimpleSale_Update_${widget.version}.exe';
      } else if (Platform.isAndroid && !fileName.toLowerCase().endsWith('.apk')) {
        fileName = 'SimpleSale_${widget.version}.apk';
      }
      
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      if (await file.exists()) await file.delete();

      await dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (mounted) {
            setState(() {
              if (total != -1) {
                downloadProgress = received / total;
                totalBytesStr = _formatBytes(total, 1);
              } else {
                downloadProgress = 0.01; // Undefined total
              }
              downloadedBytesStr = _formatBytes(received, 1);
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        isDownloading = false;
        isInstalling = true;
      });

      // Give a tiny moment for UI to reflect "Installing"
      await Future.delayed(const Duration(milliseconds: 800));

      if (Platform.isWindows) {
        // Detached launch
        if (filePath.toLowerCase().endsWith('.msi')) {
          await Process.start('msiexec.exe', ['/i', filePath, '/qn', '/norestart'], mode: ProcessStartMode.detached);
        } else {
          await Process.start(filePath, ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/SP-', '/NOCANCEL', '/NORESTART'], mode: ProcessStartMode.detached);
        }
        await Future.delayed(const Duration(seconds: 1));
        exit(0);
      } else {
        // Android / macOS / others
        final result = await OpenAppFile.open(filePath);
        if (result.type != ResultType.done) {
          throw Exception('O\'rnatishni boshlab bo\'lmadi: ${result.message}');
        }
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isDownloading = false;
        isInstalling = false;
        errorMessage = 'Yuklab olishda xatolik: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 400,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Image/Icon
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withOpacity(0.8), primaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Decorative patterns
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yangilanish mavjud!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Simple Sale v${widget.version} endi tayyor.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    if (!isDownloading && !isInstalling) ...[
                      const Text(
                        'Ushbu yangilanishda xavfsizlik kuchaytirilgan va tizim barqarorligi oshirilgan. Yangilash tavsiya etiladi.',
                        style: TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          if (!widget.isMandatory)
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text('Keyinroq', style: TextStyle(color: theme.hintColor)),
                              ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _startUpdate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Yangilash', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ] else if (isDownloading) ...[
                      _buildProgressSection(primaryColor, 'Yuklab olinmoqda...'),
                    ] else if (isInstalling) ...[
                      _buildProgressSection(Colors.green, 'O\'rnatishga tayyorlanmoqda...', undefined: true),
                    ],
                    
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(Color color, String status, {bool undefined = false}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              status,
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
            if (!undefined && totalBytesStr != null)
              Text(
                '${downloadedBytesStr ?? "0"} / $totalBytesStr',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              )
            else if (!undefined)
              Text(
                '${(downloadProgress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: undefined ? null : downloadProgress,
            minHeight: 12,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          undefined ? 'Iltimos kuting...' : 'Dastur fayllari yuklanmoqda',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }
}
