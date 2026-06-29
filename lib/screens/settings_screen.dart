import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/character_data.dart';
import '../patch_notes.dart';
import '../providers/character_provider.dart';
import '../services/app_update_service.dart';
import '../services/app_updater.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tag_chip.dart';
import '../widgets/tier_border.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static Future<void> show(BuildContext context) => showDialog(
        context: context,
        barrierColor: Colors.transparent, // we handle the barrier ourselves
        builder: (_) => const SettingsScreen(),
      );

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedCat = 0;

  // ── Cards tab staged state ─────────────────────────────────────
  late Map<CharacterTier, TierBorderEffect> _pendingEffects;
  bool _effectsDirty = false;

  @override
  void initState() {
    super.initState();
    _pendingEffects = {
      for (final tier in CharacterTier.values)
        tier: AppTheme.effectForTier(tier),
    };
  }

  Future<void> _applyEffects() async {
    for (final entry in _pendingEffects.entries) {
      AppTheme.setTierEffect(entry.key, entry.value);
    }
    AppTheme.tierEffectNotifier.value++;
    await DataService.instance.saveTierEffects(AppTheme.tierEffects);
    if (mounted) setState(() => _effectsDirty = false);
  }

  bool _migrating = false;
  int _migProgress = 0;
  int _migTotal = 0;

  bool _checkingUpdate = false;
  AppUpdateInfo? _updateResult;
  bool _upToDate = false;

  bool _backingUp = false;
  int _backupDone = 0;
  int _backupTotal = 0;

  bool _scanningDupes = false;

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
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            Text(
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 360),
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
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close,
                          size: 16, color: AppTheme.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppTheme.borderColor),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    info.body?.trim().isNotEmpty == true
                        ? info.body!
                        : 'No release notes provided.',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.6),
                  ),
                ),
              ),
              Divider(height: 1, color: AppTheme.borderColor),
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
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        launchUrl(Uri.parse(info.url), mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.open_in_browser_rounded, size: 14),
                      label: const Text('Download manually'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: BorderSide(color: AppTheme.borderColor),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
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

  // ── Library backup ────────────────────────────────────────────

  Future<void> _backupLibrary() async {
    final folder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose backup destination folder',
    );
    if (folder == null || !mounted) return;
    final now = DateTime.now();
    final stamp =
        '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    final destPath = '$folder/PSO2_Backup_$stamp.zip';
    setState(() { _backingUp = true; _backupDone = 0; _backupTotal = 0; });
    try {
      await DataService.instance.exportBackupZip(destPath, (done, total) {
        if (mounted) setState(() { _backupDone = done; _backupTotal = total; });
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Backup saved'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Backup failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  // ── Library stats ─────────────────────────────────────────────

  void _showStats(CharacterProvider provider) {
    showDialog(
      context: context,
      builder: (_) => _StatsDialog(provider: provider),
    );
  }

  // ── Apply history ─────────────────────────────────────────────

  Future<void> _showApplyHistory() async {
    final entries = await DataService.instance.getApplyHistory();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => _ApplyHistoryDialog(entries: entries),
    );
  }

  // ── Duplicate detection ───────────────────────────────────────

  Future<void> _findDuplicates(CharacterProvider provider) async {
    setState(() => _scanningDupes = true);
    try {
      final dupes =
          await DataService.instance.findDuplicates(provider.allCharacters);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => _DuplicatesDialog(groups: dupes),
      );
    } finally {
      if (mounted) setState(() => _scanningDupes = false);
    }
  }

  // ── App update ────────────────────────────────────────────────

  Future<void> _checkUpdate() async {
    setState(() { _checkingUpdate = true; _updateResult = null; _upToDate = false; });
    final info = await AppUpdateService.check();
    if (!mounted) return;
    PSO2App.updateNotifier.value = info;
    setState(() {
      _checkingUpdate = false;
      _updateResult = info;
      _upToDate = info == null;
    });
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

  Future<void> _setBg(Color color) async {
    AppTheme.setBgBase(color);
    await DataService.instance.saveBgColor(color);
    PSO2App.bgNotifier.value = color;
    if (mounted) setState(() {});
  }

  Future<void> _openBgColorWheel(BuildContext context) async {
    final picked = await showColorPickerDialog(
      context,
      AppTheme.bgBase,
      title: 'Background colour',
    );
    if (picked != null) await _setBg(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        return Material(
          color: Colors.transparent,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.black.withOpacity(0.38),
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () {},
                  child: _buildPanel(context, provider),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static const _cats = [
    (label: 'Appearance',     icon: Icons.palette_outlined),
    (label: 'Cards',          icon: Icons.style_outlined),
    (label: 'Storage',        icon: Icons.folder_outlined),
    (label: 'Gallery',          icon: Icons.photo_library_outlined),
    (label: 'About',          icon: Icons.info_outline_rounded),
  ];

  Widget _buildPanel(BuildContext context, CharacterProvider provider) {
    final screen = MediaQuery.of(context).size;
    final w = (screen.width * 0.75).clamp(700.0, 1100.0);
    final h = (w * 9 / 16).clamp(0.0, screen.height * 0.90);
    return Container(
      width: w,
      height: h,
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.50),
            blurRadius: 48,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.07),
            blurRadius: 80,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Divider(height: 1, color: AppTheme.borderColor),
            Flexible(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSidebar(),
                  VerticalDivider(
                      width: 1, thickness: 1, color: AppTheme.borderColor),
                  Expanded(child: _buildContent(provider)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return SizedBox(
      width: 152,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        itemCount: _cats.length,
        itemBuilder: (_, i) => _SidebarItem(
          icon: _cats[i].icon,
          label: _cats[i].label,
          selected: _selectedCat == i,
          onTap: () => setState(() => _selectedCat = i),
        ),
      ),
    );
  }

  Widget _buildContent(CharacterProvider provider) {
    final widgets = switch (_selectedCat) {
      0 => _appearanceWidgets(),
      1 => _cardsWidgets(),
      2 => _storageWidgets(provider),
      3 => _galleryAlbumsWidgets(provider),
      _ => _aboutWidgets(),
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      shrinkWrap: true,
      children: widgets,
    );
  }

  List<Widget> _appearanceWidgets() => [
        _sectionHeader('Accent colour'),
        const SizedBox(height: 6),
        Text(
          'Choose an accent colour for the app.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
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
                side: BorderSide(color: AppTheme.borderColor),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Quick presets',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AppTheme.accentPresets.map((preset) {
            final isActive =
                AppTheme.accent.toARGB32() == preset.color.toARGB32();
            return GestureDetector(
              onTap: () => _setAccent(preset.color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 80,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? preset.color.withOpacity(0.14)
                      : AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? preset.color : AppTheme.borderColor,
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
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                    color: preset.color.withOpacity(0.5),
                                    blurRadius: 10)
                              ]
                            : null,
                      ),
                      child: isActive
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(preset.name,
                        style: TextStyle(
                          color: isActive ? preset.color : AppTheme.textSecondary,
                          fontSize: 11,
                        )),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        _sectionHeader('Background colour'),
        const SizedBox(height: 6),
        Text(
          'Choose a background colour for the app.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            GestureDetector(
              onTap: () => _openBgColorWheel(context),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.bgBase,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: const Icon(Icons.colorize_rounded,
                    size: 20, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _openBgColorWheel(context),
              icon: const Icon(Icons.palette_outlined, size: 14),
              label: const Text('Open colour wheel',
                  style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(color: AppTheme.borderColor),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Quick presets',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AppTheme.bgPresets.map((preset) {
            final isActive =
                AppTheme.bgBase.toARGB32() == preset.color.toARGB32();
            return GestureDetector(
              onTap: () => _setBg(preset.color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 80,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.accent.withOpacity(0.14)
                      : AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? AppTheme.accent : AppTheme.borderColor,
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
                        border: Border.all(color: AppTheme.borderColor),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                    color: AppTheme.accent.withOpacity(0.4),
                                    blurRadius: 10)
                              ]
                            : null,
                      ),
                      child: isActive
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(preset.name,
                        style: TextStyle(
                          color:
                              isActive ? AppTheme.accent : AppTheme.textSecondary,
                          fontSize: 11,
                        )),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
      ];

  List<Widget> _galleryAlbumsWidgets(CharacterProvider provider) {
    final layout = provider.defaultReaderLayout;
    return [
      _sectionHeader('Gallery'),
      const SizedBox(height: 10),
      _ToggleRow(
        label: 'Blur sensitive images in viewer',
        subtitle: 'Blurred images require a click to reveal in the gallery and album reader',
        value: provider.blurSensitiveInViews,
        onChanged: (v) {
          provider.setBlurSensitiveInViews(v);
          setState(() {});
        },
      ),
      const SizedBox(height: 20),
      _sectionHeader('Albums'),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Card style',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text('Visual style for album cards in the grid',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final opt in [
                  (value: 'default',  icon: Icons.grid_view_rounded,    label: 'Default'),
                  (value: 'book',     icon: Icons.menu_book_rounded,     label: 'Book'),
                  (value: 'polaroid', icon: Icons.photo_rounded,         label: 'Polaroid'),
                  (value: 'magazine', icon: Icons.newspaper_rounded,     label: 'Magazine'),
                ]) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        provider.setAlbumCardStyle(opt.value);
                        setState(() {});
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 4),
                        decoration: BoxDecoration(
                          color: provider.albumCardStyle == opt.value
                              ? AppTheme.accent.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: provider.albumCardStyle == opt.value
                                ? AppTheme.accent.withValues(alpha: 0.6)
                                : AppTheme.borderColor,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(opt.icon,
                                size: 18,
                                color: provider.albumCardStyle == opt.value
                                    ? AppTheme.accent
                                    : AppTheme.textSecondary),
                            const SizedBox(height: 4),
                            Text(opt.label,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: provider.albumCardStyle == opt.value
                                        ? AppTheme.accent
                                        : AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (opt.value != 'magazine') const SizedBox(width: 6),
                ],
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Default reader layout',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('Layout mode used when opening an album',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                for (final opt in [
                  (value: 'horizontal', icon: Icons.swap_horiz_rounded,   label: 'Horizontal'),
                  (value: 'vertical',   icon: Icons.swap_vert_rounded,     label: 'Vertical'),
                  (value: 'book',       icon: Icons.menu_book_rounded,     label: 'Book'),
                ])
                  Tooltip(
                    message: opt.label,
                    child: GestureDetector(
                      onTap: () {
                        provider.setDefaultReaderLayout(opt.value);
                        setState(() {});
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: layout == opt.value
                              ? AppTheme.accent.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: layout == opt.value
                                ? AppTheme.accent.withValues(alpha: 0.6)
                                : AppTheme.borderColor,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(opt.icon,
                                size: 15,
                                color: layout == opt.value
                                    ? AppTheme.accent
                                    : AppTheme.textSecondary),
                            const SizedBox(width: 5),
                            Text(opt.label,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: layout == opt.value
                                        ? AppTheme.accent
                                        : AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _cardsWidgets() => [
        _sectionHeader('Tier border effects'),
        const SizedBox(height: 6),
        Text(
          'Choose a border animation for each tier, then hit Apply.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        ...CharacterTier.values.map(_tierEffectRow),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_effectsDirty)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  'Unsaved changes',
                  style: TextStyle(
                      color: AppTheme.accentGold, fontSize: 11),
                ),
              ),
            ElevatedButton.icon(
              onPressed: _effectsDirty ? _applyEffects : null,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Apply'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ];

  Widget _tierEffectRow(CharacterTier tier) {
    final current = _pendingEffects[tier] ?? AppTheme.effectForTier(tier);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Color(tier.bgColorValue),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: tier == CharacterTier.s
                  ? RainbowText(tier.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))
                  : Text(tier.label, style: TextStyle(color: Color(tier.colorValue), fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('${tier.label} Tier',
                style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13)),
          ),
          DropdownButton<TierBorderEffect>(
            value: current,
            dropdownColor: AppTheme.bgCard,
            underline: const SizedBox.shrink(),
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
            items: (AppTheme.tierEffectOptions[tier] ?? TierBorderEffect.values)
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.displayName),
                    ))
                .toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _pendingEffects[tier] = val;
                _effectsDirty = true;
              });
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _storageWidgets(CharacterProvider provider) => [
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _migTotal > 0 ? _migProgress / _migTotal : null,
                      backgroundColor: AppTheme.bgSurface,
                      valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                      minHeight: 4,
                    ),
                  ],
                )
              : const LinearProgressIndicator(),
        ],
        const SizedBox(height: 24),
        _sectionHeader('PSO2 game folder'),
        const SizedBox(height: 10),
        _settingTile(
          icon: Icons.sports_esports_outlined,
          title: 'Game folder path',
          subtitle:
              provider.gameFolderPath ?? 'Not set — apply feature disabled',
          subtitleColor:
              provider.gameFolderPath == null ? AppTheme.accentGold : null,
          trailing: ElevatedButton(
            onPressed: () => _changeGameFolder(provider),
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(
                provider.gameFolderPath == null ? 'Set' : 'Change'),
          ),
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 24),
        _sectionHeader('Backup'),
        const SizedBox(height: 10),
        _settingTile(
          icon: Icons.archive_outlined,
          title: 'Backup library',
          subtitle: 'Export all characters, collections, and tags as a zip file',
          trailing: _backingUp
              ? SizedBox(
                  width: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _backupTotal > 0
                            ? 'Zipping $_backupDone / $_backupTotal…'
                            : 'Preparing…',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _backupTotal > 0
                            ? _backupDone / _backupTotal
                            : null,
                        backgroundColor: AppTheme.bgSurface,
                        valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                        minHeight: 3,
                      ),
                    ],
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _backupLibrary,
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('Backup'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
        ),
        const SizedBox(height: 24),
        _sectionHeader('Maintenance'),
        const SizedBox(height: 10),
        _settingTile(
          icon: Icons.content_copy_outlined,
          title: 'Find duplicate files',
          subtitle: 'Scan for characters that share the same underlying file',
          trailing: _scanningDupes
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : OutlinedButton.icon(
                  onPressed: () => _findDuplicates(
                      context.read<CharacterProvider>()),
                  icon: const Icon(Icons.search_rounded, size: 14),
                  label: const Text('Scan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(color: AppTheme.borderColor),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
        ),
        const SizedBox(height: 8),
      ];

  List<Widget> _aboutWidgets() {
    final provider = context.read<CharacterProvider>();
    return [
        _sectionHeader('About'),
        const SizedBox(height: 10),
        _settingTile(
          icon: Icons.bar_chart_rounded,
          title: 'Library stats',
          subtitle: 'Race, tier, and gender breakdown of your library',
          trailing: OutlinedButton(
            onPressed: () => _showStats(provider),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: BorderSide(color: AppTheme.borderColor),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('View'),
          ),
        ),
        const SizedBox(height: 10),
        _settingTile(
          icon: Icons.history_rounded,
          title: 'Apply history',
          subtitle: 'View recently applied and unapplied characters',
          trailing: OutlinedButton(
            onPressed: _showApplyHistory,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: BorderSide(color: AppTheme.borderColor),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('View'),
          ),
        ),
        const SizedBox(height: 10),
        _settingTile(
          icon: Icons.article_outlined,
          title: 'Patch notes',
          subtitle: 'View recent changes and new features',
          trailing: OutlinedButton(
            onPressed: () => showPatchNotesDialog(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: BorderSide(color: AppTheme.borderColor),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              : _upToDate
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 6),
                        const Text('Up to date',
                            style:
                                TextStyle(color: Colors.green, fontSize: 12)),
                      ],
                    )
                  : _updateResult != null
                      ? ElevatedButton.icon(
                          onPressed: () => _showReleaseNotes(_updateResult!),
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
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.14)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          child: const Text('Check for updates'),
                        ),
        ),
        const SizedBox(height: 8),
      ];
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
      child: Row(
        children: [
          Icon(Icons.settings_outlined, size: 16, color: AppTheme.accent),
          const SizedBox(width: 10),
          Text(
            'Settings',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          _GlassIconButton(
            icon: Icons.close_rounded,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Text(
        text,
        style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4),
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
        color: AppTheme.bgSurface,
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
                    style: TextStyle(
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

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.accent,
            ),
          ],
        ),
      );
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accent.withOpacity(0.15)
                : _hovered
                    ? AppTheme.bgSurface
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? AppTheme.accent.withOpacity(0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  size: 16,
                  color: active ? AppTheme.accent : AppTheme.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? AppTheme.accent : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.bgSurface
                : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Icon(widget.icon,
              size: 16,
              color: _hovered
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary),
        ),
      ),
    );
  }
}

// ── Apply history dialog ──────────────────────────────────────────

class _ApplyHistoryDialog extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  const _ApplyHistoryDialog({required this.entries});

  String _relativeTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 14, 12),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 16, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text('Apply history',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppTheme.borderColor),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text('No history yet.',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: entries.length,
                      itemBuilder: (_, i) {
                        final e = entries[i];
                        final isApply = e['action'] == 'apply';
                        final variant = e['variantFolderName'] as String? ?? '';
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isApply
                                ? Icons.check_circle_outline_rounded
                                : Icons.remove_circle_outline_rounded,
                            size: 18,
                            color: isApply ? Colors.green : Colors.redAccent,
                          ),
                          title: Text(e['characterName'] as String? ?? '',
                              style: TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 13)),
                          subtitle: variant.isNotEmpty &&
                                  variant != e['characterName']
                              ? Text(variant,
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11))
                              : null,
                          trailing: Text(
                            _relativeTime(e['at'] as String? ?? ''),
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        );
                      },
                    ),
            ),
            Divider(height: 1, color: AppTheme.borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats dialog ─────────────────────────────────────────────────

class _StatsDialog extends StatelessWidget {
  final CharacterProvider provider;
  const _StatsDialog({required this.provider});

  @override
  Widget build(BuildContext context) {
    final chars = provider.allCharacters;
    final total = chars.length;
    if (total == 0) {
      return AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Library stats'),
        content: Text('No characters yet.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      );
    }

    final races = ['Human', 'Newman', 'Deuman', 'CAST'];
    final raceCounts = {for (final r in races) r: chars.where((c) => c.race == r).length};
    final femaleCt     = chars.where((c) => c.gender == 'Female').length;
    final maleCt       = chars.where((c) => c.gender == 'Male').length;
    final appliedCt    = chars.where((c) => c.isApplied).length;
    final totalVariants = chars.fold(0, (s, c) => s + (c.variants.length - 1));

    final tierOrder = [null, ...CharacterTier.values];
    final tierCounts = {
      for (final t in tierOrder)
        t: chars.where((c) => c.tier == t).length,
    };

    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 14, 12),
              child: Row(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 16, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text('Library stats',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppTheme.borderColor),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary row
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _StatsChip(label: '$total characters', icon: Icons.group_rounded),
                    _StatsChip(label: '$totalVariants variants', icon: Icons.layers_rounded),
                    _StatsChip(label: '$appliedCt applied', icon: Icons.check_circle_outline_rounded),
                    _StatsChip(label: '${provider.allTags.length} tags', icon: Icons.label_rounded),
                    _StatsChip(label: '${provider.allCollections.length} collections', icon: Icons.folder_rounded),
                  ]),
                  const SizedBox(height: 20),

                  // Race breakdown
                  Text('Race', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  ...races.map((r) {
                    final ct = raceCounts[r]!;
                    final pct = ct / total;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        SizedBox(width: 56, child: Text(r, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 7,
                              backgroundColor: AppTheme.bgSurface,
                              valueColor: AlwaysStoppedAnimation(AppTheme.raceColor(r)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(width: 24, child: Text('$ct', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11), textAlign: TextAlign.right)),
                      ]),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Gender breakdown
                  Text('Gender', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(children: [
                    SizedBox(width: 56, child: Text('Female', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
                    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: femaleCt / total, minHeight: 7, backgroundColor: AppTheme.bgSurface, valueColor: AlwaysStoppedAnimation(Colors.pinkAccent)))),
                    const SizedBox(width: 8),
                    SizedBox(width: 24, child: Text('$femaleCt', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11), textAlign: TextAlign.right)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    SizedBox(width: 56, child: Text('Male', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
                    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: maleCt / total, minHeight: 7, backgroundColor: AppTheme.bgSurface, valueColor: AlwaysStoppedAnimation(Colors.blueAccent)))),
                    const SizedBox(width: 8),
                    SizedBox(width: 24, child: Text('$maleCt', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11), textAlign: TextAlign.right)),
                  ]),

                  const SizedBox(height: 16),

                  // Tier breakdown
                  Text('Tier', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  ...tierOrder.map((t) {
                    final ct = tierCounts[t]!;
                    if (ct == 0) return const SizedBox.shrink();
                    final label = t?.label ?? '—';
                    final color = t != null ? Color(t.colorValue) : AppTheme.textSecondary;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        SizedBox(width: 56, child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500))),
                        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: ct / total, minHeight: 7, backgroundColor: AppTheme.bgSurface, valueColor: AlwaysStoppedAnimation(color)))),
                        const SizedBox(width: 8),
                        SizedBox(width: 24, child: Text('$ct', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11), textAlign: TextAlign.right)),
                      ]),
                    );
                  }),
                ],
              ),
            ),
            Divider(height: 1, color: AppTheme.borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _StatsChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.accent),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Duplicates dialog ─────────────────────────────────────────────

class _DuplicatesDialog extends StatelessWidget {
  final List<List<CharacterData>> groups;
  const _DuplicatesDialog({required this.groups});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 540),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 14, 12),
              child: Row(
                children: [
                  Icon(Icons.content_copy_outlined,
                      size: 16, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text('Duplicate files',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close,
                        size: 16, color: AppTheme.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppTheme.borderColor),
            Expanded(
              child: groups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 36,
                              color: Colors.green.withOpacity(0.7)),
                          const SizedBox(height: 10),
                          Text('No duplicate files found.',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: groups.length,
                      itemBuilder: (_, gi) {
                        final group = groups[gi];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Group ${gi + 1} — ${group.length} characters share the same file',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 6),
                              ...group.map((c) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 3),
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_outline_rounded,
                                            size: 14,
                                            color: AppTheme.textSecondary),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            c.name,
                                            style: TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontSize: 13),
                                          ),
                                        ),
                                        Text(
                                          '${c.race} · ${c.gender[0]}',
                                          style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Divider(height: 1, color: AppTheme.borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
