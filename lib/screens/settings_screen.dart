import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../patch_notes.dart';
import '../providers/character_provider.dart';
import '../services/app_update_service.dart';
import '../services/app_updater.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_title_bar.dart';
import '../widgets/tag_chip.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _migrating = false;
  int _migProgress = 0;
  int _migTotal = 0;

  bool _checkingUpdate = false;
  AppUpdateInfo? _updateResult;

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

  // ── Release notes dialog ───────────────────────────────────────

  void _showReleaseNotes(AppUpdateInfo info) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 480,
          height: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    Icon(Icons.new_releases_outlined,
                        size: 16, color: AppTheme.accentGold),
                    const SizedBox(width: 8),
                    Text(
                      'What\'s new in v${info.version}',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          size: 16, color: AppTheme.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.borderColor),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    info.body?.trim().isNotEmpty == true
                        ? info.body!
                        : 'No release notes provided.',
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.6),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppTheme.borderColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        AppUpdater.installWithProgress(context, info);
                      },
                      icon: const Icon(Icons.download_rounded, size: 14),
                      label: Text('Update to v${info.version}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGold,
                        foregroundColor: AppTheme.bgDark,
                        textStyle: const TextStyle(fontSize: 12),
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

  // ── App update ────────────────────────────────────────────────

  Future<void> _checkUpdate() async {
    setState(() { _checkingUpdate = true; _updateResult = null; });
    final info = await AppUpdateService.check();
    if (!mounted) return;
    PSO2App.updateNotifier.value = info;
    setState(() { _checkingUpdate = false; _updateResult = info; });
    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(  // ignore: use_build_context_synchronously
        const SnackBar(
          content: Text('You\'re up to date!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ── Accent color ───────────────────────────────────────────────

  Future<void> _setAccent(Color color) async {
    AppTheme.setAccent(color);
    await DataService.instance.saveAccentColor(color);
    PSO2App.themeNotifier.value = color;
    if (mounted) setState(() {});
  }

  Future<void> _openColorWheel(BuildContext context) async {
    final picked = await showColorPickerDialog(
      context,
      AppTheme.accent,
      title: 'App accent colour',
    );
    if (picked != null) await _setAccent(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          body: Column(
            children: [
              const AppTitleBar(),
              Container(
                height: 48,
                color: AppTheme.bgCard,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          size: 18, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back',
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.borderColor),
              Expanded(
                child: ListView(
            padding: const EdgeInsets.all(24),
            children: [

              // ── Appearance ───────────────────────────────────
              _sectionHeader('Appearance'),
              const SizedBox(height: 6),
              const Text(
                'Choose an accent colour for the app.',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 14),

              // Current colour swatch + open wheel button
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _openColorWheel(context),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: const Icon(Icons.colorize_rounded,
                          size: 20, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openColorWheel(context),
                    icon: const Icon(Icons.palette_outlined, size: 14),
                    label: const Text('Open colour wheel',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.borderColor),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick presets
              const Text('Quick presets',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
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
                  onPressed: _migrating
                      ? null
                      : () => _changeSaveLocation(provider),
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

              // ── About / Updates ──────────────────────────────
              _sectionHeader('About'),
              const SizedBox(height: 10),
              _settingTile(
                icon: Icons.article_outlined,
                title: 'Patch notes',
                subtitle: "What's new in v$kAppVersion",
                trailing: OutlinedButton(
                  onPressed: () => showPatchNotesDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.borderColor),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('View'),
                ),
              ),
              const SizedBox(height: 10),
              _settingTile(
                icon: Icons.system_update_alt_rounded,
                title: 'App version',
                subtitle: 'v$kAppVersion',
                trailing: _checkingUpdate
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _updateResult != null
                        ? ElevatedButton.icon(
                            onPressed: () =>
                                _showReleaseNotes(_updateResult!),
                            icon: const Icon(Icons.download_rounded, size: 14),
                            label: Text('Download v${_updateResult!.version}'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentGold,
                              foregroundColor: AppTheme.bgDark,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: _checkUpdate,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              side: const BorderSide(
                                  color: AppTheme.borderColor),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: const Text('Check for updates'),
                          ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
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
