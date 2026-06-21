import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/character_data.dart';
import '../providers/character_provider.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/character_card.dart';
import '../widgets/character_spinner.dart';
import '../widgets/skeleton.dart';
import 'character_detail_screen.dart';
import 'import_bundle_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _cardSize = 2; // 0=S,1=M,2=L,3=XL

  static const List<double> _sizeExtents = [120, 160, 200, 260];
  static const List<double> _aspectRatios = [0.58, 0.62, 0.68, 0.72];

  @override
  void initState() {
    super.initState();
    _loadCardSize();
  }

  Future<void> _loadCardSize() async {
    final size = await DataService.instance.getCardSize();
    if (mounted) setState(() => _cardSize = size);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        final characters = provider.hasActiveFilters
            ? provider.filteredCharacters
            : provider.allCharacters;

        return Column(
          children: [
            _TopBar(
              cardSize: _cardSize,
              onSizeChanged: (i) async {
                setState(() => _cardSize = i);
                await DataService.instance.saveCardSize(i);
              },
            ),
            Expanded(
              child: provider.isLoading
                  ? SkeletonCardGrid(cardSize: _cardSize)
                  : characters.isEmpty
                      ? _buildEmpty(provider)
                      : _buildGrid(context, characters),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, List characters) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _sizeExtents[_cardSize],
        childAspectRatio: _aspectRatios[_cardSize],
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        final c = characters[index];
        return CharacterCard(
          character: c,
          cardSize: _cardSize,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CharacterDetailScreen(character: c)),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(CharacterProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            provider.hasActiveFilters
                ? Icons.search_off_rounded
                : Icons.group_outlined,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            provider.hasActiveFilters
                ? 'No characters match your search'
                : 'No characters yet',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          if (provider.hasActiveFilters)
            TextButton(
              onPressed: provider.clearAllFilters,
              child: const Text('Clear all filters'),
            )
          else
            Text(
              'Click "Add character" in the sidebar to get started',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────

class _TopBar extends StatefulWidget {
  final int cardSize;
  final void Function(int) onSizeChanged;

  const _TopBar({
    required this.cardSize,
    required this.onSizeChanged,
  });

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  final _searchCtrl = TextEditingController();
  bool _spinnerLoading = false;

  @override
  void initState() {
    super.initState();
    PSO2App.bgNotifier.addListener(_onBgChange);
  }

  void _onBgChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    PSO2App.bgNotifier.removeListener(_onBgChange);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openSpinner(CharacterProvider provider) async {
    final characters = provider.hasActiveFilters
        ? provider.filteredCharacters
        : provider.allCharacters;
    if (characters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No characters to pick from!')),
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

  IconData _cardSizeIcon(int size) {
    switch (size) {
      case 0: return Icons.grid_on_rounded;
      case 1: return Icons.grid_view_rounded;
      case 2: return Icons.view_agenda_outlined;
      case 3: return Icons.crop_free_rounded;
      default: return Icons.grid_view_rounded;
    }
  }

  PopupMenuItem<int> _sizeMenuItem(
      int value, String label, IconData icon, int current) {
    final selected = current == value;
    return PopupMenuItem<int>(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 15,
              color: selected ? AppTheme.accent : AppTheme.textSecondary),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color:
                      selected ? AppTheme.accent : AppTheme.textPrimary)),
          if (selected) ...[
            const Spacer(),
            Icon(Icons.check_rounded, size: 13, color: AppTheme.accent),
          ],
        ],
      ),
    );
  }

  void _openFilterPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FilterPanel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        // Sync controller when provider query changes externally (e.g. clearAllFilters)
        if (_searchCtrl.text != provider.searchQuery) {
          _searchCtrl.value = TextEditingValue(text: provider.searchQuery);
        }

        final count = provider.hasActiveFilters
            ? provider.filteredCharacters.length
            : provider.allCharacters.length;
        final hasFilters = provider.activeFilterCount > 0;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // ── Keyword search ───────────────────────────
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => provider.setSearchQuery(v),
                      style: TextStyle(
                          color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search characters…',
                        hintStyle: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 6),
                          child: Icon(Icons.search_rounded,
                              size: 14, color: AppTheme.textSecondary),
                        ),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 0, minHeight: 0),
                        suffixIcon: provider.searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  provider.setSearchQuery('');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(Icons.close,
                                      size: 14,
                                      color: AppTheme.textSecondary),
                                ),
                              )
                            : null,
                        suffixIconConstraints:
                            const BoxConstraints(minWidth: 0, minHeight: 0),
                        filled: true,
                        fillColor: AppTheme.bgSurface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppTheme.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppTheme.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppTheme.accent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ── Filter button ─────────────────────────────
                  GestureDetector(
                    onTap: () => _openFilterPanel(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: hasFilters
                            ? AppTheme.accent.withOpacity(0.12)
                            : AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: hasFilters
                              ? AppTheme.accent
                              : AppTheme.borderColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded,
                              size: 14,
                              color: hasFilters
                                  ? AppTheme.accent
                                  : AppTheme.textSecondary),
                          if (hasFilters) ...[
                            const SizedBox(width: 4),
                            Text('${provider.activeFilterCount}',
                                style: TextStyle(
                                    color: AppTheme.accent, fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // ── Sort button ───────────────────────────────
                  _SortButton(provider: provider),
                  const SizedBox(width: 6),

                  // ── Size picker dropdown ──────────────────
                  PopupMenuButton<int>(
                    color: AppTheme.bgCard,
                    tooltip: 'Card size',
                    icon: Icon(
                      _cardSizeIcon(widget.cardSize),
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppTheme.borderColor),
                    ),
                    onSelected: (i) => widget.onSizeChanged(i),
                    itemBuilder: (_) => [
                      _sizeMenuItem(3, 'Extra large',
                          Icons.crop_free_rounded, widget.cardSize),
                      _sizeMenuItem(2, 'Large',
                          Icons.view_agenda_outlined, widget.cardSize),
                      _sizeMenuItem(1, 'Medium',
                          Icons.grid_view_rounded, widget.cardSize),
                      _sizeMenuItem(0, 'Small',
                          Icons.grid_on_rounded, widget.cardSize),
                    ],
                  ),
                  const SizedBox(width: 2),

                  // ── Import bundle button ──────────────────
                  GestureDetector(
                    onTap: () => showImportBundlePicker(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Icon(Icons.file_download_outlined,
                          size: 14,
                          color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // ── Random pick button ────────────────────────
                  GestureDetector(
                    onTap: _spinnerLoading
                        ? null
                        : () => _openSpinner(provider),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: _spinnerLoading
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppTheme.accent))
                          : Icon(Icons.casino_outlined,
                              size: 14,
                              color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),

              // ── Status bar ────────────────────────────────────
              if (provider.hasActiveFilters) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$count result${count == 1 ? '' : 's'}',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    if (provider.searchQuery.isNotEmpty) ...[
                      Text(' · ',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11)),
                      Text(
                        '"${provider.searchQuery}"',
                        style: TextStyle(
                            color: AppTheme.accent, fontSize: 11),
                      ),
                    ],
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        provider.clearAllFilters();
                      },
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: const BorderSide(color: Colors.red, width: 0.8)),
                      child: const Text('Clear all',
                          style: TextStyle(color: Colors.red, fontSize: 11)),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  '$count character${count == 1 ? '' : 's'} · ${provider.sortOption.label}',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Sort button ────────────────────────────────────────────────────

class _SortButton extends StatelessWidget {
  final CharacterProvider provider;
  const _SortButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: AppTheme.bgCard,
      tooltip: 'Sort',
      icon: Icon(
        provider.sortOption.icon,
        size: 16,
        color: AppTheme.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      onSelected: (value) {
        if (value == '__favourites_top__') {
          provider.setFavouritesOnTop(!provider.favouritesOnTop);
        } else {
          final opt = SortOption.values.firstWhere((o) => o.name == value);
          provider.setSortOption(opt);
        }
      },
      itemBuilder: (_) => [
        // Favourites on top toggle — always at the top of the menu
        PopupMenuItem<String>(
          value: '__favourites_top__',
          child: Row(
            children: [
              Icon(
                provider.favouritesOnTop
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 14,
                color: provider.favouritesOnTop
                    ? Colors.pinkAccent
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text('Favourites on top',
                  style: TextStyle(
                      color: provider.favouritesOnTop
                          ? Colors.pinkAccent
                          : AppTheme.textPrimary,
                      fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        ...SortOption.values.map((opt) => PopupMenuItem<String>(
              value: opt.name,
              child: Row(
                children: [
                  Icon(opt.icon,
                      size: 14,
                      color: provider.sortOption == opt
                          ? AppTheme.accent
                          : AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(opt.label,
                      style: TextStyle(
                          color: provider.sortOption == opt
                              ? AppTheme.accent
                              : AppTheme.textPrimary,
                          fontSize: 13)),
                  if (provider.sortOption == opt) ...[
                    const Spacer(),
                    Icon(Icons.check_rounded,
                        size: 13, color: AppTheme.accent),
                  ],
                ],
              ),
            )),
      ],
    );
  }
}

// ── Filter panel ───────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  const _FilterPanel();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      height: screenHeight * 0.65,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Consumer<CharacterProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Text('Filters',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    if (provider.activeFilterCount > 0)
                      TextButton(
                        onPressed: provider.clearAllFilters,
                        style: TextButton.styleFrom(
                            side: const BorderSide(color: Colors.red, width: 0.8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: const Text('Clear all',
                            style:
                                TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppTheme.borderColor),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Saved presets ─────────────────────────
                    if (provider.savedPresets.isNotEmpty) ...[
                      _section('Saved presets', [
                        ...provider.savedPresets.map((preset) =>
                          _PresetChip(
                            preset: preset,
                            onTap: () {
                              provider.applyPreset(preset);
                              Navigator.pop(context);
                            },
                            onDelete: () => provider.deletePreset(preset.id),
                          )),
                      ]),
                      const SizedBox(height: 16),
                    ],
                    // Save current filter button
                    if (provider.hasActiveFilters)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _SavePresetButton(provider: provider),
                      ),
                    _section('Tier', [
                      ...CharacterTier.values.map((t) => _TierChip(
                            tier: t,
                            selected: provider.filterTiers.contains(t),
                            onTap: () => provider.toggleFilterTier(t),
                          )),
                    ]),
                    const SizedBox(height: 16),
                    _section('Race', [
                      _Chip(
                          label: 'Human',
                          color: AppTheme.humanColor,
                          selected: provider.filterRace == 'Human',
                          onTap: () => provider.setFilterRace('Human')),
                      _Chip(
                          label: 'Newman',
                          color: AppTheme.newmanColor,
                          selected: provider.filterRace == 'Newman',
                          onTap: () => provider.setFilterRace('Newman')),
                      _Chip(
                          label: 'Deuman',
                          color: AppTheme.deumanColor,
                          selected: provider.filterRace == 'Deuman',
                          onTap: () => provider.setFilterRace('Deuman')),
                      _Chip(
                          label: 'CAST',
                          color: AppTheme.castColor,
                          selected: provider.filterRace == 'CAST',
                          onTap: () => provider.setFilterRace('CAST')),
                    ]),
                    const SizedBox(height: 16),
                    _section('Gender', [
                      _Chip(
                          label: 'All',
                          selected: provider.filterGender == null,
                          onTap: () => provider.setFilterGender(null),
                          isRadio: true),
                      _Chip(
                          label: 'Female',
                          selected: provider.filterGender == 'Female',
                          onTap: () => provider.setFilterGender('Female'),
                          isRadio: true),
                      _Chip(
                          label: 'Male',
                          selected: provider.filterGender == 'Male',
                          onTap: () => provider.setFilterGender('Male'),
                          isRadio: true),
                    ]),
                    const SizedBox(height: 16),
                    _section('Status', [
                      _Chip(
                          label: 'Applied to game',
                          icon: Icons.check_circle_outline_rounded,
                          selected: provider.filterApplied == true,
                          onTap: () => provider.setFilterApplied(true)),
                      _Chip(
                          label: 'Not applied',
                          icon: Icons.radio_button_unchecked_rounded,
                          selected: provider.filterApplied == false,
                          onTap: () => provider.setFilterApplied(false)),
                    ]),
                    if (provider.allTags.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _TagFilterSection(provider: provider),
                    ],
                    if (provider.allCollections.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _section(
                          'Collection',
                          provider.allCollections
                              .map((col) => _Chip(
                                    label: col.name,
                                    icon: Icons.folder_rounded,
                                    selected:
                                        provider.filterCollectionId == col.id,
                                    onTap: () => provider.setFilterCollection(
                                        provider.filterCollectionId == col.id
                                            ? null
                                            : col.id),
                                  ))
                              .toList()),
                    ],
                    const SizedBox(height: 16),
                    // ── Persist filter toggle ────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Remember filter on close',
                                    style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                                SizedBox(height: 2),
                                Text(
                                    'Restore active filter when app reopens',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          Switch(
                            value: provider.persistFilter,
                            onChanged: (v) => provider.setPersistFilter(v),
                            activeColor: AppTheme.accent,
                          ),
                        ],
                      ),
                    ),

                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String label, List<Widget> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
                letterSpacing: 0.07)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    );
  }
}

// ── Tag filter section ────────────────────────────────────────

class _TagFilterSection extends StatefulWidget {
  final CharacterProvider provider;
  const _TagFilterSection({required this.provider});

  @override
  State<_TagFilterSection> createState() => _TagFilterSectionState();
}

class _TagFilterSectionState extends State<_TagFilterSection> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final allTags = provider.allTags
        .where((t) =>
            _query.isEmpty ||
            t.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header + match mode
        Row(
          children: [
            Text('TAGS',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    letterSpacing: 0.07)),
            const Spacer(),
            // Match All / Match Any toggle
            GestureDetector(
              onTap: () => provider.setMatchAll(!provider.matchAll),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.accent.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(provider.matchAll
                        ? Icons.join_inner
                        : Icons.join_full,
                        size: 12, color: AppTheme.accent),
                    const SizedBox(width: 4),
                    Text(
                      provider.matchAll ? 'Match all' : 'Match any',
                      style: TextStyle(
                          color: AppTheme.accent, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          provider.matchAll
              ? 'AND — must have all whitelisted tags'
              : 'OR — must have at least one whitelisted tag',
          style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 10),
        ),
        const SizedBox(height: 8),

        // Search bar
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Search tags…',
            hintStyle: TextStyle(
                color: AppTheme.textSecondary, fontSize: 12),
            prefixIcon: Icon(Icons.search_rounded,
                size: 14, color: AppTheme.textSecondary),
            suffixIcon: _query.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                    child: Icon(Icons.close,
                        size: 13, color: AppTheme.textSecondary),
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 6),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),

        if (allTags.isEmpty)
          Text('No tags match',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: allTags.map((tag) {
              final isWhite = provider.filterTags.contains(tag.id);
              final isBlack =
                  provider.filterTagsBlacklist.contains(tag.id);
              final tagColor = tag.color;

              return GestureDetector(
                onTap: () {
                  if (isWhite) {
                    // white → black
                    provider.toggleFilterTagBlacklist(tag.id);
                  } else if (isBlack) {
                    // black → none
                    provider.toggleFilterTagBlacklist(tag.id);
                  } else {
                    // none → white
                    provider.toggleFilterTag(tag.id);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isWhite
                        ? tagColor.withOpacity(0.18)
                        : isBlack
                            ? Colors.red.withOpacity(0.1)
                            : AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isWhite
                          ? tagColor
                          : isBlack
                              ? Colors.redAccent
                              : AppTheme.borderColor,
                      width: (isWhite || isBlack) ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // State icon
                      if (isWhite)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.add_circle_outline_rounded,
                              size: 11, color: tagColor),
                        )
                      else if (isBlack)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                              Icons.remove_circle_outline_rounded,
                              size: 11,
                              color: Colors.redAccent),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: tagColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      Text(
                        tag.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: (isWhite || isBlack)
                              ? FontWeight.w500
                              : FontWeight.normal,
                          color: isWhite
                              ? tagColor
                              : isBlack
                                  ? Colors.redAccent
                                  : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

        // Legend
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.add_circle_outline_rounded,
                size: 11, color: AppTheme.accent),
            const SizedBox(width: 4),
            Text('Whitelist',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 10)),
            const SizedBox(width: 12),
            const Icon(Icons.remove_circle_outline_rounded,
                size: 11, color: Colors.redAccent),
            const SizedBox(width: 4),
            Text('Blacklist',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 10)),
            const SizedBox(width: 12),
            Text('Tap to cycle: none → whitelist → blacklist → none',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

// ── Tier chip ──────────────────────────────────────────────────

class _TierChip extends StatelessWidget {
  final CharacterTier tier;
  final bool selected;
  final VoidCallback onTap;

  const _TierChip({
    required this.tier,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Color(tier.colorValue);
    final bgColor = Color(tier.bgColorValue);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? bgColor : AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? borderColor : AppTheme.borderColor,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tier.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? borderColor : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;
  final bool isRadio; // kept for API compatibility, no longer affects rendering

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.icon,
    this.isRadio = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.12) : AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? c : AppTheme.borderColor,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12,
                  color: selected ? c : AppTheme.textSecondary),
              const SizedBox(width: 4),
            ] else if (color != null) ...[
              Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                    color: selected ? c : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Preset chip ─────────────────────────────────────────────

class _PresetChip extends StatelessWidget {
  final FilterPreset preset;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PresetChip({
    required this.preset,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(preset.colorValue);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(preset.name,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.close, size: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Save preset button ─────────────────────────────────────

class _SavePresetButton extends StatelessWidget {
  final CharacterProvider provider;
  const _SavePresetButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSaveDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppTheme.accent.withOpacity(0.4),
              style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_add_outlined,
                size: 14, color: AppTheme.accent),
            const SizedBox(width: 6),
            Text('Save current filter as preset',
                style: TextStyle(
                    color: AppTheme.accent, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showSaveDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    Color selectedColor = AppTheme.accent;
    final colors = [
      AppTheme.accent,
      AppTheme.accentGold,
      Colors.pinkAccent,
      Colors.green,
      Colors.purple,
      Colors.orange,
    ];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('Save filter preset'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Preset name e.g. S tier Newmans'),
              ),
              const SizedBox(height: 14),
              Text('Colour',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: colors.map((c) => GestureDetector(
                  onTap: () => setState(() => selectedColor = c),
                  child: Container(
                    width: 24, height: 24,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selectedColor == c
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                await provider.saveCurrentAsPreset(name, selectedColor);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
