import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:provider/provider.dart';
import 'providers/character_provider.dart';
import 'screens/home_screen.dart';
import 'screens/collections_screen.dart';
import 'screens/applied_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/add_character_screen.dart';
import 'screens/character_detail_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/import_bundle_dialog.dart';
import 'screens/scan_screen.dart';
import 'screens/tags_screen.dart';
import 'services/hive_service.dart';
import 'services/share_service.dart';
import 'theme/app_theme.dart';
import 'widgets/character_spinner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();

  // Load saved accent color
  final savedAccent = HiveService.staticGetAccentColor();
  if (savedAccent != null) AppTheme.setAccent(savedAccent);

  runApp(
    ChangeNotifierProvider(
      create: (_) => CharacterProvider()..loadAll(),
      child: const PSO2App(),
    ),
  );
}

class PSO2App extends StatefulWidget {
  const PSO2App({super.key});

  // Global key so settings screen can trigger theme rebuild
  static final themeNotifier = ValueNotifier<Color>(AppTheme.accent);

  @override
  State<PSO2App> createState() => _PSO2AppState();
}

class _PSO2AppState extends State<PSO2App> {
  @override
  void initState() {
    super.initState();
    PSO2App.themeNotifier.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    PSO2App.themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PSO2 Character Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    CollectionsScreen(),
    AppliedScreen(),
    GalleryScreen(),
    TagsScreen(),
    ScanScreen(),
  ];

  Future<void> _handleDroppedFiles(List<String> paths) async {
    for (final path in paths) {
      if (ShareService.isBundlePath(path)) {
        await showImportBundleFromPath(context, path);
        return; // handle one bundle at a time
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: DropTarget(
        onDragDone: (details) =>
            _handleDroppedFiles(details.files.map((f) => f.path).toList()),
        child: Row(
          children: [
            _Sidebar(
              currentIndex: _currentIndex,
              onSelect: (i) => setState(() => _currentIndex = i),
            ),
            Expanded(child: _screens[_currentIndex]),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const _Sidebar({required this.currentIndex, required this.onSelect});

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  bool _spinnerLoading = false;

  Future<void> _openSpinner(CharacterProvider provider) async {
    final characters = provider.allCharacters;
    if (characters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some characters first!')),
      );
      return;
    }
    setState(() => _spinnerLoading = true);
    final winner = await showCharacterSpinner(context, characters);
    if (mounted) setState(() => _spinnerLoading = false);
    if (winner != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CharacterDetailScreen(character: winner)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        return Container(
          width: 200,
          color: AppTheme.bgCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.person, color: AppTheme.bgDark, size: 16),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PSO2 Character Manager',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 8,
                                fontWeight: FontWeight.w500)),
                        Text('v1.2.0',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              _sectionLabel('Library'),

              _NavItem(
                icon: Icons.grid_view_rounded,
                label: 'All characters',
                badge: '${provider.allCharacters.length}',
                selected: widget.currentIndex == 0,
                onTap: () => widget.onSelect(0),
              ),
              _NavItem(
                icon: Icons.folder_rounded,
                label: 'Collections',
                badge: '${provider.allCollections.length}',
                selected: widget.currentIndex == 1,
                onTap: () => widget.onSelect(1),
              ),
              _NavItem(
                icon: Icons.check_circle_outline_rounded,
                label: 'Applied to game',
                badge: '${provider.appliedCount}',
                selected: widget.currentIndex == 2,
                onTap: () => widget.onSelect(2),
              ),
              _NavItem(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                badge: provider.getAllGalleryItems().isNotEmpty
                    ? '${provider.getAllGalleryItems().length}'
                    : null,
                selected: widget.currentIndex == 3,
                onTap: () => widget.onSelect(3),
              ),
              _NavItem(
                icon: Icons.label_rounded,
                label: 'Tags',
                badge: provider.allTags.isNotEmpty
                    ? '${provider.allTags.length}'
                    : null,
                selected: widget.currentIndex == 4,
                onTap: () => widget.onSelect(4),
              ),
              _NavItem(
                icon: Icons.radar_rounded,
                label: 'Scan folder',
                selected: widget.currentIndex == 5,
                onTap: () => widget.onSelect(5),
              ),

              const Spacer(),

              // ── Character slots ────────────────────────────────
              _sectionLabel('Character slots'),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${provider.appliedCount} / 50',
                          style: TextStyle(
                              color: provider.appliedCount > 50
                                  ? Colors.red
                                  : AppTheme.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                        Text(
                          provider.appliedCount > 50
                              ? 'over limit!'
                              : 'slots used',
                          style: TextStyle(
                              color: provider.appliedCount > 50
                                  ? Colors.red.withOpacity(0.8)
                                  : AppTheme.textSecondary,
                              fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (provider.appliedCount / 50).clamp(0.0, 1.0),
                        backgroundColor: AppTheme.bgSurface,
                        valueColor: AlwaysStoppedAnimation(
                          provider.appliedCount > 50
                              ? Colors.red
                              : AppTheme.accent,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),

              // ── App section ──────────────────────────────────────
              _sectionLabel('App'),
              _NavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                selected: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddCharacterScreen()),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add character'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 10,
          letterSpacing: 0.07,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 15,
                color: selected ? AppTheme.accent : AppTheme.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppTheme.accent : AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.accent.withOpacity(0.2)
                      : AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: selected ? AppTheme.accent : AppTheme.textSecondary,
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
