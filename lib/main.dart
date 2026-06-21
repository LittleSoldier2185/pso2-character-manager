import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'providers/character_provider.dart';
import 'screens/home_screen.dart';
import 'screens/collections_screen.dart';
import 'screens/applied_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/add_character_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/import_bundle_dialog.dart';
import 'screens/migration_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/tags_screen.dart';
import 'screens/update_check_dialog.dart';
import 'patch_notes.dart';
import 'services/app_update_service.dart';
import 'services/data_service.dart';
import 'services/migration_service.dart';
import 'services/share_service.dart';
import 'theme/app_theme.dart';
import 'services/app_updater.dart';
import 'widgets/app_title_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Hide native title bar; our custom _TitleBar widget replaces it.
  windowManager.waitUntilReadyToShow(
    const WindowOptions(titleBarStyle: TitleBarStyle.hidden),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  final needsMigration = await MigrationService.needsMigration();

  if (!needsMigration) {
    await _initDataService();
    final accent = await DataService.instance.getAccentColor();
    if (accent != null) AppTheme.setAccent(accent);
    final bg = await DataService.instance.getBgColor();
    if (bg != null) AppTheme.setBgBase(bg);
    final tierEffects = await DataService.instance.getTierEffects();
    if (tierEffects != null) AppTheme.loadTierEffects(tierEffects);
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => needsMigration
          ? CharacterProvider()
          : (CharacterProvider()..loadAll()),
      child: PSO2App(needsMigration: needsMigration),
    ),
  );
}

/// Initialises DataService, reading save location from the settings file.
Future<void> _initDataService() async {
  final docs = await getApplicationDocumentsDirectory();
  final appRoot = p.join(docs.path, 'PSO2CharacterManager');
  final settingsFile = File(p.join(appRoot, 'settings.json'));

  String? saveLocation;
  if (await settingsFile.exists()) {
    try {
      final j = jsonDecode(await settingsFile.readAsString())
          as Map<String, dynamic>;
      saveLocation = j['saveLocation'] as String?;
    } catch (_) {}
  }

  await DataService.init(saveLocation: saveLocation);
}

// ── Root app ──────────────────────────────────────────────────────

class PSO2App extends StatefulWidget {
  final bool needsMigration;
  const PSO2App({super.key, required this.needsMigration});

  // Notifiers so settings screen can trigger theme rebuild
  static final themeNotifier       = ValueNotifier<Color>(AppTheme.accent);
  static final bgNotifier          = ValueNotifier<Color>(AppTheme.bgBase);
  static final updateNotifier      = ValueNotifier<AppUpdateInfo?>(null);

  @override
  State<PSO2App> createState() => _PSO2AppState();
}

class _PSO2AppState extends State<PSO2App> {
  late bool _showMigration;

  @override
  void initState() {
    super.initState();
    _showMigration = widget.needsMigration;
    PSO2App.themeNotifier.addListener(_onThemeChange);
    PSO2App.bgNotifier.addListener(_onThemeChange);
    AppTheme.tierEffectNotifier.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    PSO2App.themeNotifier.removeListener(_onThemeChange);
    PSO2App.bgNotifier.removeListener(_onThemeChange);
    AppTheme.tierEffectNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() => setState(() {});

  Future<void> _onMigrationComplete() async {
    // DataService was initialised by MigrationService.run(); apply accent.
    final accent = await DataService.instance.getAccentColor();
    if (accent != null) {
      AppTheme.setAccent(accent);
      PSO2App.themeNotifier.value = accent;
    }
    final bg = await DataService.instance.getBgColor();
    if (bg != null) {
      AppTheme.setBgBase(bg);
      PSO2App.bgNotifier.value = bg;
    }
    final tierEffects = await DataService.instance.getTierEffects();
    if (tierEffects != null) AppTheme.loadTierEffects(tierEffects);
    if (!mounted) return;
    // Now it is safe to load all characters.
    context.read<CharacterProvider>().loadAll();
    setState(() => _showMigration = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PSO2 Character Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _showMigration
          ? MigrationScreen(onComplete: _onMigrationComplete)
          : const MainShell(),
    );
  }
}

// ── Main shell ────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  // ponytail: static notifier lets child screens switch tabs without callback drilling
  static final switchTabNotifier = ValueNotifier<int>(-1);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _onSwitchTab() {
    final idx = MainShell.switchTabNotifier.value;
    if (idx >= 0) {
      setState(() => _currentIndex = idx);
      MainShell.switchTabNotifier.value = -1;
    }
  }

  @override
  void initState() {
    super.initState();
    MainShell.switchTabNotifier.addListener(_onSwitchTab);
    AppUpdateService.check()
        .then((info) => PSO2App.updateNotifier.value = info);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final shownPatchNotes = await _maybeShowPatchNotes();
      if (!shownPatchNotes) await _maybePromptGameFolder();
    });
  }

  @override
  void dispose() {
    MainShell.switchTabNotifier.removeListener(_onSwitchTab);
    super.dispose();
  }

  Future<bool> _maybeShowPatchNotes() async {
    final settings = await DataService.instance.getSettings();
    if (settings.lastSeenVersion == kAppVersion) return false;
    await DataService.instance.saveLastSeenVersion(kAppVersion);
    if (!mounted) return false;
    showPatchNotesDialog(context);  // ignore: use_build_context_synchronously
    return true;
  }

  Future<void> _maybePromptGameFolder() async {
    final settings = await DataService.instance.getSettings();
    if (settings.gameFolderPromptShown || settings.gameFolderPath != null) {
      return;
    }
    settings.gameFolderPromptShown = true;
    await DataService.instance.saveSettings(settings);
    if (!mounted) return;
    showDialog(context: context, builder: (_) => _GameFolderPromptDialog());  // ignore: use_build_context_synchronously
  }

  Future<void> _handleDroppedFiles(List<String> paths) async {
    for (final path in paths) {
      if (ShareService.isBundlePath(path)) {
        await showImportBundleFromPath(context, path);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([PSO2App.bgNotifier, PSO2App.themeNotifier]),
      builder: (context, _) => Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Column(
          children: [
            const AppTitleBar(),
            Expanded(
              child: DropTarget(
                onDragDone: (details) =>
                    _handleDroppedFiles(details.files.map((f) => f.path).toList()),
                child: Row(
                  children: [
                    _Sidebar(
                      currentIndex: _currentIndex,
                      onSelect: (i) => setState(() => _currentIndex = i),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _currentIndex,
                        children: [
                          HomeScreen(),
                          CollectionsScreen(),
                          AppliedScreen(),
                          GalleryScreen(),
                          TagsScreen(),
                          ScanScreen(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────

class _Sidebar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const _Sidebar({required this.currentIndex, required this.onSelect});

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _collapsed ? 56 : 200,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(right: BorderSide(color: AppTheme.borderColor)),
      ),
      // LayoutBuilder drives layout from actual pixel width so the
      // content never overflows during the AnimatedContainer transition.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 150;
          return Consumer<CharacterProvider>(
            builder: (context, provider, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ────────────────────────────────────────
                  if (narrow)
                    GestureDetector(
                      onTap: () => setState(() => _collapsed = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                              bottom:
                                  BorderSide(color: AppTheme.borderColor)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppTheme.accent
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Icon(Icons.person,
                                  color: AppTheme.accent, size: 16),
                            ),
                            const SizedBox(height: 5),
                            Icon(Icons.chevron_right_rounded,
                                color: AppTheme.textSecondary, size: 14),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                      decoration: BoxDecoration(
                        border: Border(
                            bottom:
                                BorderSide(color: AppTheme.borderColor)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color:
                                      AppTheme.accent.withValues(alpha: 0.4)),
                            ),
                            child: Icon(Icons.person,
                                color: AppTheme.accent, size: 15),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Character Manager',
                                    style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.1)),
                                ValueListenableBuilder<AppUpdateInfo?>(
                                  valueListenable: PSO2App.updateNotifier,
                                  builder: (_, update, child) {
                                    if (update == null) {
                                      return Text('v$kAppVersion',
                                          style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 10));
                                    }
                                    return GestureDetector(
                                      onTap: () => AppUpdater.installWithProgress(context, update),
                                      child: Tooltip(
                                        message:
                                            'v${update.version} available — click to download',
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('v$kAppVersion',
                                                style: TextStyle(
                                                    color:
                                                        AppTheme.textSecondary,
                                                    fontSize: 10)),
                                            const SizedBox(width: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppTheme.accentGold
                                                    .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'v${update.version}',
                                                style: const TextStyle(
                                                    color: AppTheme.accentGold,
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _collapsed = true),
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: Icon(Icons.chevron_left_rounded,
                                  color: AppTheme.textSecondary, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (!narrow) const SizedBox(height: 8),
                  if (!narrow) _sectionLabel('Library'),

                  _NavItem(
                    icon: Icons.grid_view_rounded,
                    label: 'All characters',
                    badge: '${provider.allCharacters.length}',
                    selected: widget.currentIndex == 0,
                    onTap: () => widget.onSelect(0),
                    collapsed: narrow,
                  ),
                  _NavItem(
                    icon: Icons.folder_rounded,
                    label: 'Collections',
                    badge: '${provider.allCollections.length}',
                    selected: widget.currentIndex == 1,
                    onTap: () => widget.onSelect(1),
                    collapsed: narrow,
                  ),
                  _NavItem(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Applied to game',
                    badge: '${provider.appliedCount}',
                    selected: widget.currentIndex == 2,
                    onTap: () => widget.onSelect(2),
                    collapsed: narrow,
                  ),
                  _NavItem(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    badge: provider.getAllGalleryItems().isNotEmpty
                        ? '${provider.getAllGalleryItems().length}'
                        : null,
                    selected: widget.currentIndex == 3,
                    onTap: () => widget.onSelect(3),
                    collapsed: narrow,
                  ),
                  _NavItem(
                    icon: Icons.label_rounded,
                    label: 'Tags',
                    badge: provider.allTags.isNotEmpty
                        ? '${provider.allTags.length}'
                        : null,
                    selected: widget.currentIndex == 4,
                    onTap: () => widget.onSelect(4),
                    collapsed: narrow,
                  ),
                  _NavItem(
                    icon: Icons.radar_rounded,
                    label: 'Scan folder',
                    selected: widget.currentIndex == 5,
                    onTap: () => widget.onSelect(5),
                    collapsed: narrow,
                  ),
                  _UpdatesNavItem(
                      updateCount: provider.totalUpdatesCount,
                      collapsed: narrow),

                  const Spacer(),

                  if (!narrow) ...[
                    // ── Applied count ────────────────────────────────
                    _sectionLabel('Applied'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                      child: Row(
                        children: [
                          Text(
                            '${provider.appliedCount}',
                            style: TextStyle(
                                color: AppTheme.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'characters applied',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    _sectionLabel('App'),
                  ],

                  _NavItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    selected: false,
                    collapsed: narrow,
                    onTap: () => SettingsScreen.show(context),
                  ),

                  if (narrow)
                    Tooltip(
                      message: 'Add character',
                      preferBelow: false,
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const AddCharacterScreen()),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Icon(Icons.add,
                                color: AppTheme.bgDark, size: 18),
                          ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const AddCharacterScreen()),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add character'),
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 10,
          letterSpacing: 0.07,
        ),
      ),
    );
  }
}

// ── Updates nav item ──────────────────────────────────────────────

class _UpdatesNavItem extends StatelessWidget {
  final int updateCount;
  final bool collapsed;
  const _UpdatesNavItem(
      {required this.updateCount, this.collapsed = false});

  @override
  Widget build(BuildContext context) {
    final hasUpdates = updateCount > 0;
    void openDialog() => showDialog(
          context: context,
          builder: (_) => const UpdateCheckDialog(),
        );

    if (collapsed) {
      return Tooltip(
        message: hasUpdates
            ? 'Sync from game ($updateCount)'
            : 'Sync from game',
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 400),
        child: GestureDetector(
          onTap: openDialog,
          child: Container(
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: hasUpdates
                  ? AppTheme.accentGold.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(Icons.sync_rounded,
                      size: 16,
                      color: hasUpdates
                          ? AppTheme.accentGold
                          : AppTheme.textSecondary),
                ),
                if (hasUpdates)
                  Positioned(
                    right: 10,
                    top: 8,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentGold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: openDialog,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: hasUpdates
              ? AppTheme.accentGold.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.sync_rounded,
                size: 15,
                color: hasUpdates
                    ? AppTheme.accentGold
                    : AppTheme.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sync from game',
                style: TextStyle(
                  color: hasUpdates
                      ? AppTheme.accentGold
                      : AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            if (hasUpdates)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$updateCount',
                  style: const TextStyle(
                      color: AppTheme.accentGold,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Nav item ──────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;
  final bool collapsed;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return Tooltip(
        message: badge != null ? '$label ($badge)' : label,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 400),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Icon(icon,
                  size: 16,
                  color: selected
                      ? AppTheme.accent
                      : AppTheme.textSecondary),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 15,
                color: selected
                    ? AppTheme.accent
                    : AppTheme.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color:
                      selected ? AppTheme.accent : AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.accent.withValues(alpha: 0.2)
                      : AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: selected
                        ? AppTheme.accent
                        : AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── First-run game folder prompt ──────────────────────────────────

class _GameFolderPromptDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sports_esports_outlined,
                      size: 20, color: AppTheme.accent),
                  const SizedBox(width: 10),
                  Text(
                    'Set up game folder',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Point the app to your PSO2 character data folder to enable '
                'Apply to game, Scan folder, and Sync from game features.',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary),
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      SettingsScreen.show(context);
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
