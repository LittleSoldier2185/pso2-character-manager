import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/character_provider.dart';
import '../models/character_data.dart';
import '../theme/app_theme.dart';
import 'add_character_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<String> _scannedFiles = [];
  bool _scanning = false;
  bool _hasScanned = false;

  Future<void> _scan(CharacterProvider provider) async {
    setState(() { _scanning = true; _scannedFiles = []; _hasScanned = false; });
    final files = await provider.scanGameFolderForUnregistered();
    if (mounted) {
      setState(() {
        _scanning = false;
        _scannedFiles = files;
        _hasScanned = true;
      });
    }
  }

  Future<void> _importAll(CharacterProvider provider) async {
    final files = List<String>.from(_scannedFiles);
    for (final path in files) {
      await provider.importLocalFile(
        name: _fileNameWithoutExt(path),
        localFilePath: path,
      );
      if (mounted) setState(() => _scannedFiles.remove(path));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported ${files.length} character${files.length == 1 ? '' : 's'}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _fileNameWithoutExt(String path) {
    final base = path.split(r'\').last.split('/').last;
    final dot = base.lastIndexOf('.');
    return dot == -1 ? base : base.substring(0, dot);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        final hasGameFolder = provider.gameFolderPath != null;

        return Column(
          children: [
            // ── Top bar ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: const BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(
                    bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  const Text('Scan game folder',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  if (_scannedFiles.isNotEmpty) ...[
                    OutlinedButton.icon(
                      onPressed: () => _importAll(provider),
                      icon: const Icon(Icons.download_rounded, size: 14),
                      label: Text('Import all (${_scannedFiles.length})',
                          style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        side: BorderSide(
                            color: AppTheme.accent.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    onPressed: !hasGameFolder || _scanning
                        ? null
                        : () => _scan(provider),
                    icon: _scanning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.bgDark))
                        : const Icon(Icons.radar_rounded, size: 15),
                    label: Text(_scanning ? 'Scanning…' : 'Scan now',
                        style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────
            Expanded(
              child: !hasGameFolder
                  ? _buildNoFolder()
                  : _scanning
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Scanning game folder…',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14)),
                            ],
                          ),
                        )
                      : !_hasScanned
                          ? _buildPrompt()
                          : _scannedFiles.isEmpty
                              ? _buildAllClear()
                              : _buildResults(provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoFolder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_off_outlined,
              size: 56, color: AppTheme.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('Game folder not set',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 8),
          const Text('Set your PSO2 game folder in Settings first.',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar_rounded,
              size: 56, color: AppTheme.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('Ready to scan',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 8),
          const Text(
              'Click "Scan now" to find character files not yet in your library.',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAllClear() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 56,
              color: Colors.green.withOpacity(0.6)),
          const SizedBox(height: 16),
          const Text('All clear!',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
          const SizedBox(height: 8),
          const Text('No unregistered character files found.',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildResults(CharacterProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _scannedFiles.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Found ${_scannedFiles.length} unregistered file${_scannedFiles.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          );
        }
        final path = _scannedFiles[i - 1];
        return _ScanResultRow(
          filePath: path,
          onImport: () async {
            await provider.importLocalFile(
              name: _fileNameWithoutExt(path),
              localFilePath: path,
            );
            if (mounted) {
              setState(() => _scannedFiles.remove(path));
            }
          },
          onDismiss: () => setState(() => _scannedFiles.remove(path)),
        );
      },
    );
  }
}

// ── Scan result row ────────────────────────────────────────────────

class _ScanResultRow extends StatelessWidget {
  final String filePath;
  final VoidCallback onImport;
  final VoidCallback onDismiss;

  const _ScanResultRow({
    required this.filePath,
    required this.onImport,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = filePath.split(r'\').last.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();
    final raceGender = CharacterData.detectRaceGender(filePath);
    final raceColor = AppTheme.raceColor(raceGender['race'] ?? 'Unknown');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: raceColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: raceColor.withOpacity(0.4)),
            ),
            child: Text(ext.toUpperCase(),
                style: TextStyle(
                    color: raceColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileName,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 12)),
                Text(
                    '${raceGender['race']} · ${raceGender['gender']}',
                    style: TextStyle(color: raceColor, fontSize: 10)),
              ],
            ),
          ),
          TextButton(
            onPressed: onDismiss,
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Skip', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: onImport,
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }
}
