import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/character_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/character_card.dart';
import 'character_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        final characters = provider.hasActiveFilters
            ? provider.filteredCharacters
            : provider.allCharacters;

        return Column(
          children: [
            // Not const — TopBar uses accent color
            _TopBar(),
            Expanded(
              child: characters.isEmpty
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
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.68,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        final c = characters[index];
        return CharacterCard(
          character: c,
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
            style: const TextStyle(
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
            const Text(
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
  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  OverlayEntry? _suggestionOverlay;
  final _layerLink = LayerLink();
  String _typedValue = '';

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    _removeSuggestions();
    super.dispose();
  }

  void _onType(String value, CharacterProvider provider) {
    setState(() => _typedValue = value);
    if (value.trim().isEmpty) {
      _removeSuggestions();
    } else {
      _showSuggestions(value, provider);
    }
  }

  void _onSubmit(String value, CharacterProvider provider) {
    final v = value.trim();
    if (v.isEmpty) return;
    provider.addPendingToken(v);
    _inputController.clear();
    setState(() => _typedValue = '');
    _removeSuggestions();
  }

  void _onBackspace(CharacterProvider provider) {
    if (_inputController.text.isEmpty && provider.pendingTokens.isNotEmpty) {
      provider.removePendingToken(provider.pendingTokens.last);
    }
  }

  void _showSuggestions(String query, CharacterProvider provider) {
    _removeSuggestions();
    final q = query.toLowerCase();
    final tagMatches = provider.allTags
        .where((t) =>
            t.toLowerCase().contains(q) &&
            !provider.pendingTokens.contains(t))
        .take(4)
        .toList();
    final nameMatches = provider.allCharacters
        .where((c) =>
            c.name.toLowerCase().contains(q) &&
            !provider.pendingTokens.contains(c.name))
        .take(3)
        .toList();

    if (tagMatches.isEmpty && nameMatches.isEmpty) return;

    _suggestionOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        width: 280,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 42),
          child: Material(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(8),
            elevation: 4,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (nameMatches.isNotEmpty) ...[
                    _suggestionHeader('Characters'),
                    ...nameMatches.map((c) => _suggestionItem(
                          c.name, 'name', AppTheme.accent,
                          () => _addToken(c.name, provider))),
                  ],
                  if (tagMatches.isNotEmpty) ...[
                    _suggestionHeader('Tags'),
                    ...tagMatches.map((t) => _suggestionItem(
                          t, 'tag', AppTheme.newmanColor,
                          () => _addToken(t, provider))),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_suggestionOverlay!);
  }

  Widget _suggestionHeader(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
        child: Text(label.toUpperCase(),
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 9, letterSpacing: 0.07)),
      );

  Widget _suggestionItem(
      String text, String type, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(type, style: TextStyle(color: color, fontSize: 9)),
            ),
            const SizedBox(width: 8),
            Text(text,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _addToken(String token, CharacterProvider provider) {
    provider.addPendingToken(token);
    _inputController.clear();
    setState(() => _typedValue = '');
    _removeSuggestions();
    _focusNode.requestFocus();
  }

  void _removeSuggestions() {
    _suggestionOverlay?.remove();
    _suggestionOverlay = null;
  }

  void _openFilterPanel(BuildContext context) {
    _removeSuggestions();
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
        final count = provider.hasActiveFilters
            ? provider.filteredCharacters.length
            : provider.allCharacters.length;
        final hasPending = provider.hasPendingChanges;
        final hasFilters = provider.activeFilterCount > 0;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: AppTheme.bgCard,
            border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // ── Keyword token input ──────────────────────
                  Expanded(
                    child: CompositedTransformTarget(
                      link: _layerLink,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _focusNode.hasFocus
                                ? AppTheme.accent
                                : AppTheme.borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 10),
                              child: Icon(Icons.search_rounded,
                                  size: 14,
                                  color: AppTheme.textSecondary),
                            ),
                            ...provider.pendingTokens.map((token) =>
                                _TokenPill(
                                  token: token,
                                  onRemove: () =>
                                      provider.removePendingToken(token),
                                )),
                            Expanded(
                              child: KeyboardListener(
                                focusNode: FocusNode(),
                                onKeyEvent: (event) {
                                  if (event.character == null &&
                                      _inputController.text.isEmpty) {
                                    _onBackspace(provider);
                                  }
                                },
                                child: TextField(
                                  controller: _inputController,
                                  focusNode: _focusNode,
                                  onChanged: (v) => _onType(v, provider),
                                  onSubmitted: (v) => _onSubmit(v, provider),
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: provider.pendingTokens.isEmpty
                                        ? 'Type keyword + Enter to search…'
                                        : 'Add more keywords…',
                                    hintStyle: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 10),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                            if (provider.pendingTokens.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  provider.clearTokens();
                                  _inputController.clear();
                                  setState(() => _typedValue = '');
                                  _removeSuggestions();
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(Icons.close,
                                      size: 14,
                                      color: AppTheme.textSecondary),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ── Apply button ──────────────────────────────
                  ElevatedButton(
                    onPressed: provider.pendingTokens.isNotEmpty
                        ? () {
                            provider.applySearch();
                            _removeSuggestions();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          hasPending ? AppTheme.accent : AppTheme.bgSurface,
                      foregroundColor:
                          hasPending ? AppTheme.bgDark : AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      textStyle: const TextStyle(fontSize: 12),
                      side: BorderSide(
                        color: hasPending
                            ? AppTheme.accent
                            : AppTheme.borderColor,
                      ),
                    ),
                    child: const Text('Apply'),
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
                ],
              ),

              // ── Status bar ────────────────────────────────────
              if (provider.appliedTokens.isNotEmpty ||
                  provider.hasActiveFilters) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$count result${count == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    if (provider.appliedTokens.isNotEmpty) ...[
                      const Text(' · ',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11)),
                      // No const — accent is dynamic
                      Text(
                        'Keywords: ${provider.appliedTokens.join(', ')}',
                        style: TextStyle(
                            color: AppTheme.accent, fontSize: 11),
                      ),
                    ],
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        provider.clearAllFilters();
                        _inputController.clear();
                        setState(() => _typedValue = '');
                      },
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text('Clear all',
                          style: TextStyle(color: Colors.red, fontSize: 11)),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  '$count character${count == 1 ? '' : 's'} · ${provider.sortOption.label}',
                  style: const TextStyle(
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

// ── Token pill ─────────────────────────────────────────────────────

class _TokenPill extends StatelessWidget {
  final String token;
  final VoidCallback onRemove;
  const _TokenPill({required this.token, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // No const — accent is dynamic
          Text(token,
              style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 3),
          GestureDetector(
            onTap: onRemove,
            // No const — accent is dynamic
            child: Icon(Icons.close, size: 11, color: AppTheme.accent),
          ),
        ],
      ),
    );
  }
}

// ── Sort button ────────────────────────────────────────────────────

class _SortButton extends StatelessWidget {
  final CharacterProvider provider;
  const _SortButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SortOption>(
      color: AppTheme.bgCard,
      tooltip: 'Sort',
      icon: Icon(
        provider.sortOption.icon,
        size: 16,
        color: AppTheme.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      onSelected: provider.setSortOption,
      itemBuilder: (_) => SortOption.values
          .map((opt) => PopupMenuItem(
                value: opt,
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
                      // No const — accent is dynamic
                      Icon(Icons.check_rounded,
                          size: 13, color: AppTheme.accent),
                    ],
                  ],
                ),
              ))
          .toList(),
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
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                    const Text('Filters',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    if (provider.activeFilterCount > 0)
                      TextButton(
                        onPressed: provider.clearAllFilters,
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
              const Divider(height: 1, color: AppTheme.borderColor),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
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
                          label: 'Female',
                          selected: provider.filterGender == 'Female',
                          onTap: () => provider.setFilterGender('Female')),
                      _Chip(
                          label: 'Male',
                          selected: provider.filterGender == 'Male',
                          onTap: () => provider.setFilterGender('Male')),
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
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
                letterSpacing: 0.07)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.icon,
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
          border: Border.all(color: selected ? c : AppTheme.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 12,
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
                    color: selected ? c : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
