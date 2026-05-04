import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/character_provider.dart';
import '../services/hive_service.dart';
import '../theme/app_theme.dart';
import 'add_character_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _migrating = false;
  int _migProgress = 0;
  int _migTotal = 0;
  List<String> _scannedFiles = [];
  bool _scanning = false;

  // ── Save location ──────────────────────────────────────────────

  Future<void> _changeSaveLocation(CharacterProvider provider) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose save folder for character files',
    );
    if (result == null || !mounted) return;

    final confirmed = await _showMigrateDialog(result);
    if (!mounted || confirmed == null) return;

    setState(() { _migrating = true; _migProgress = 0; _migTotal = 0; });
    final error = await provider.changeSaveLocation(
      result,
      migrateFiles: confirmed,
      onProgress: (done, total) =>
          setState(() { _migProgress = done; _migTotal = total; }),
    );
    if (mounted) {
      setState(() => _migrating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? 'Save location updated successfully'),
        backgroundColor: error != null ? Colors.red : Colors.green,
      ));
    }
  }

  Future<bool?> _showMigrateDialog(String newPath) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Change save location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New folder:\n$newPath',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            const Text(
              'Do you want to move your existing character files and '
              'thumbnails to the new location?',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Change path only'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move files too'),
          ),
        ],
      ),
    );
  }

  // ── Game folder ────────────────────────────────────────────────

  Future<void> _changeGameFolder(CharacterProvider provider) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose PSO2 character data folder',
    );
    if (result != null && mounted) {
      await provider.setGameFolderPath(result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Game folder saved'),
            backgroundColor: Colors.green),
      );
    }
  }

  // ── Scan game folder ───────────────────────────────────────────

  Future<void> _scanGameFolder(CharacterProvider provider) async {
    setState(() { _scanning = true; _scannedFiles = []; });
    final files = await provider.scanGameFolderForUnregistered();
    if (mounted) setState(() { _scanning = false; _scannedFiles = files; });
  }

  // ── Accent color ───────────────────────────────────────────────

  Future<void> _setAccent(Color color) async {
    AppTheme.setAccent(color);
    final hive = HiveService();
    await hive.saveAccentColor(color);
    // Notify the app root to rebuild with new theme
    PSO2App.themeNotifier.value = color;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [

              // ── Theme ────────────────────────────────────────
              _sectionHeader('Appearance'),
              const SizedBox(height: 6),
              const Text(
                'Choose an accent colour for the app.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppTheme.accentPresets.map((preset) {
                  final isActive = AppTheme.accent.toARGB32() ==
                      preset.color.toARGB32();
                  return GestureDetector(
                    onTap: () => _setAccent(preset.color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 80,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive
                            ? preset.color.withOpacity(0.12)
                            : AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive
                              ? preset.color
                              : AppTheme.borderColor,
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: preset.color,
                              shape: BoxShape.circle,
                            ),
                            child: isActive
                                ? const Icon(Icons.check_rounded,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(preset.name,
                              style: TextStyle(
                                color: isActive
                                    ? preset.color
                                    : AppTheme.textSecondary,
                                fontSize: 11,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // ── Save location ────────────────────────────────
              _sectionHeader('Character file storage'),
              const SizedBox(height: 10),
              _settingTile(
                icon: Icons.folder_special_outlined,
                title: 'Save location',
                subtitle: provider.saveLocation ??
                    'Default (Documents\\PSO2CharacterManager)',
                trailing: ElevatedButton(
                  onPressed:
                      _migrating ? null : () => _changeSaveLocation(provider),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Change'),
                ),
              ),
              if (_migrating) ...[
                const SizedBox(height: 8),
                _migTotal > 0
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Moving files: $_migProgress / $_migTotal',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: _migTotal > 0
                                ? _migProgress / _migTotal
                                : null,
                            backgroundColor: AppTheme.bgSurface,
                            valueColor: AlwaysStoppedAnimation(
                                AppTheme.accent),
                            minHeight: 4,
                          ),
                        ],
                      )
                    : const LinearProgressIndicator(),
              ],
              const SizedBox(height: 24),

              // ── Game folder ──────────────────────────────────
              _sectionHeader('PSO2 game folder'),
              const SizedBox(height: 10),
              _settingTile(
                icon: Icons.sports_esports_outlined,
                title: 'Game folder path',
                subtitle: provider.gameFolderPath ??
                    'Not set — apply feature disabled',
                subtitleColor: provider.gameFolderPath == null
                    ? AppTheme.accentGold
                    : null,
                trailing: ElevatedButton(
                  onPressed: () => _changeGameFolder(provider),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: Text(
                      provider.gameFolderPath == null ? 'Set' : 'Change'),
                ),
              ),
              const SizedBox(height: 24),

              // ── Scan game folder ─────────────────────────────
              _sectionHeader('Scan for unregistered files'),
              const SizedBox(height: 6),
              const Text(
                'Scan your game folder for character files that aren\'t '
                'in your library yet.',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        provider.gameFolderPath == null || _scanning
                            ? null
                            : () => _scanGameFolder(provider),
                    icon: _scanning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.search_rounded, size: 15),
                    label: Text(_scanning ? 'Scanning…' : 'Scan now'),
                  ),
                  if (provider.gameFolderPath == null) ...[
                    const SizedBox(width: 12),
                    const Text('Set game folder first',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ],
              ),
              if (_scannedFiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                    'Found ${_scannedFiles.length} unregistered file${_scannedFiles.length == 1 ? '' : 's'}:',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                ..._scannedFiles.map((path) => _ScannedFileRow(
                      filePath: path,
                      onImport: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddCharacterScreen(
                                prefilledFilePath: path),
                          ),
                        ).then((_) =>
                            setState(() => _scannedFiles.remove(path)));
                      },
                      onDismiss: () =>
                          setState(() => _scannedFiles.remove(path)),
                    )),
              ],
              if (_scannedFiles.isEmpty && !_scanning && _migTotal == 0) ...[
                const SizedBox(height: 8),
                const Text('No unregistered files found.',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String text) => Text(
        text,
        style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500),
      );

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? subtitleColor,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: subtitleColor ?? AppTheme.textSecondary,
                        fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing,
          ],
        ],
      ),
    );
  }
}

class _ScannedFileRow extends StatelessWidget {
  final String filePath;
  final VoidCallback onImport;
  final VoidCallback onDismiss;

  const _ScannedFileRow({
    required this.filePath,
    required this.onImport,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = filePath.split(r'\').last;
    final ext = fileName.split('.').last.toLowerCase();
    final raceGender = _raceGenderFromExt(ext);
    final raceColor = AppTheme.raceColor(raceGender['race'] ?? 'Unknown');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                Text('${raceGender['race']} · ${raceGender['gender']}',
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

  Map<String, String> _raceGenderFromExt(String ext) {
    const map = {
      'fhp': {'race': 'Human', 'gender': 'Female'},
      'mhp': {'race': 'Human', 'gender': 'Male'},
      'fnp': {'race': 'Newman', 'gender': 'Female'},
      'mnp': {'race': 'Newman', 'gender': 'Male'},
      'fdp': {'race': 'Deuman', 'gender': 'Female'},
      'mdp': {'race': 'Deuman', 'gender': 'Male'},
      'fcp': {'race': 'CAST', 'gender': 'Female'},
      'mcp': {'race': 'CAST', 'gender': 'Male'},
    };
    return map[ext] ?? {'race': 'Unknown', 'gender': 'Unknown'};
  }
}
