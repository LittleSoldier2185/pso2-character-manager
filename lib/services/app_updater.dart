import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'app_update_service.dart';

class AppUpdater {
  static Future<void> showUpdateOptions(BuildContext context, AppUpdateInfo info) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 360,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(Icons.system_update_alt_rounded, size: 18, color: AppTheme.accentGold),
                  const SizedBox(width: 8),
                  Text('v${info.version} available',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('Update automatically'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGold,
                    foregroundColor: AppTheme.bgDark,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, false);
                    launchUrl(Uri.parse(info.url), mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.open_in_browser_rounded, size: 14),
                  label: const Text('Download manually'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: AppTheme.borderColor),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                  child: const Text('Later'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (go == true && context.mounted) installWithProgress(context, info);
  }

  static Future<void> installWithProgress(BuildContext context, AppUpdateInfo info) async {
    if (info.downloadUrl == null) {
      launchUrl(Uri.parse(info.url), mode: LaunchMode.externalApplication);
      return;
    }

    final progress = ValueNotifier<double>(0);
    final status = ValueNotifier<String>('Downloading…');

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProgressDialog(progress: progress, status: status),
    );

    try {
      final temp = (await getTemporaryDirectory()).path;
      final zipPath = p.join(temp, 'pso2_update.zip');
      final extractDir = p.join(temp, 'pso2_update');

      // Download
      final client = http.Client();
      final req = await client.send(http.Request('GET', Uri.parse(info.downloadUrl!)));
      final total = req.contentLength ?? 0;
      var received = 0;
      final sink = File(zipPath).openWrite();
      await for (final chunk in req.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) progress.value = (received / total) * 0.8;
      }
      await sink.close();
      client.close();

      // Extract
      status.value = 'Extracting…';
      progress.value = 0.85;
      if (Directory(extractDir).existsSync()) Directory(extractDir).deleteSync(recursive: true);
      await extractFileToDisk(zipPath, extractDir);

      // Write updater script
      status.value = 'Installing…';
      progress.value = 0.95;
      final installDir = File(Platform.resolvedExecutable).parent.path;
      final exeName = p.basename(Platform.resolvedExecutable);
      // Locate the exe inside the extracted zip to find the actual source dir,
      // regardless of whether the zip has a subfolder or files at root.
      String sourceDir;
      try {
        final found = Directory(extractDir)
            .listSync(recursive: true)
            .whereType<File>()
            .firstWhere((f) => p.basename(f.path).toLowerCase() == exeName.toLowerCase());
        sourceDir = found.parent.path;
      } catch (_) {
        final sub = p.join(extractDir, 'PSO2CharacterManager');
        sourceDir = Directory(sub).existsSync() ? sub : extractDir;
      }
      final exePath = Platform.resolvedExecutable;
      final procName = p.basenameWithoutExtension(Platform.resolvedExecutable);

      final scriptPath = p.join(temp, 'pso2_updater.ps1');
      await File(scriptPath).writeAsString(
        'do { Start-Sleep 1 } until (-not (Get-Process -Name "$procName" -ErrorAction SilentlyContinue))\r\n'
        'try { Copy-Item -Path "$sourceDir\\*" -Destination "$installDir" -Recurse -Force -ErrorAction Stop } catch {}\r\n'
        'Start-Process "$exePath"\r\n'
        'Remove-Item \$PSCommandPath -Force\r\n',
      );

      await Process.start(
        'powershell',
        ['-ExecutionPolicy', 'Bypass', '-NonInteractive', '-File', scriptPath],
        mode: ProcessStartMode.detached,
      );

      status.value = 'Restarting…';
      progress.value = 1.0;
      await Future.delayed(const Duration(milliseconds: 600));
      exit(0);
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
}

class _ProgressDialog extends StatelessWidget {
  final ValueNotifier<double> progress;
  final ValueNotifier<String> status;

  const _ProgressDialog({required this.progress, required this.status});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update_alt_rounded, size: 36, color: AppTheme.accentGold),
              const SizedBox(height: 16),
              Text('Updating…',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),
              ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  backgroundColor: AppTheme.borderColor,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.accentGold),
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (_, s, __) => Text(s,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
