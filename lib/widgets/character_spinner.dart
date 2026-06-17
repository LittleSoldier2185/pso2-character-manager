import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character_data.dart';
import '../providers/character_provider.dart';
import '../theme/app_theme.dart';

/// Shows the CS:GO-style case-opening spinner and returns the picked character.
/// Returns null if the user dismissed without clicking "View character".
Future<CharacterData?> showCharacterSpinner(
  BuildContext context,
  List<CharacterData> characters,
) async {
  if (characters.isEmpty) return null;
  if (characters.length == 1) return characters.first;

  final provider = context.read<CharacterProvider>();

  return showDialog<CharacterData>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.75),
    builder: (_) => _SpinnerDialog(characters: characters, provider: provider),
  );
}

// ── Constants ──────────────────────────────────────────────────────

const double _cardWidth   = 120.0;
const double _cardHeight  = 160.0;
const double _cardSpacing = 10.0;
const double _cardStride  = _cardWidth + _cardSpacing;
const int    _spinRepeats = 6;
const Duration _spinDuration = Duration(milliseconds: 3800);

// ── Spin entry (character + specific variant) ──────────────────────

class _SpinEntry {
  final CharacterData character;
  final VariantData variant;

  const _SpinEntry(this.character, this.variant);

  bool get isMainVariant => variant.folderName == character.mainVariant;
  String? get thumbnailPath =>
      character.thumbnailForVariant(variant.folderName);
  String get key => '${character.id}:${variant.folderName}';
}

// ── Filter entry ───────────────────────────────────────────────────

enum _FilterKind { name, race, gender, tag, tier, variant }

class _FilterEntry {
  final String value;
  final _FilterKind kind;
  final String? _label;
  const _FilterEntry(this.value, this.kind, {String? label}) : _label = label;

  @override
  bool operator ==(Object other) =>
      other is _FilterEntry && other.value == value && other.kind == kind;

  @override
  int get hashCode => Object.hash(value, kind);

  Color color(BuildContext context) {
    switch (kind) {
      case _FilterKind.race:    return AppTheme.raceColor(value);
      case _FilterKind.gender:  return AppTheme.accentGold;
      case _FilterKind.tag:     return AppTheme.newmanColor;
      case _FilterKind.name:    return AppTheme.accent;
      case _FilterKind.variant: return AppTheme.accentGold;
      case _FilterKind.tier:
        final t = CharacterTier.values.firstWhere(
            (t) => t.label == value,
            orElse: () => CharacterTier.s);
        return Color(t.colorValue);
    }
  }

  String get label => _label ?? value;
}

// ── Dialog shell ───────────────────────────────────────────────────

class _SpinnerDialog extends StatefulWidget {
  final List<CharacterData> characters;
  final CharacterProvider provider;
  const _SpinnerDialog({required this.characters, required this.provider});

  @override
  State<_SpinnerDialog> createState() => _SpinnerDialogState();
}

class _SpinnerDialogState extends State<_SpinnerDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;
  late ScrollController    _scrollCtrl;

  List<_SpinEntry> _reel       = [];
  int              _winnerIndex = 0;
  late _SpinEntry  _winner;

  bool _spinning  = false;
  bool _done      = false;
  bool _dismissed = false;

  // Filter state
  final Set<_FilterEntry> _whitelist = {};
  final Set<_FilterEntry> _blacklist = {};
  bool _showFilters     = false;
  bool _includeVariants = false;

  // Actual measured viewport width — set by LayoutBuilder
  double _reelViewportWidth = 560.0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _ctrl = AnimationController(vsync: this, duration: _spinDuration);
    _buildReel();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Eligible entries after applying filters ────────────────────

  List<_SpinEntry> get _eligible {
    final variantWhitelist =
        _whitelist.where((e) => e.kind == _FilterKind.variant).toSet();
    final nonVariantWhitelist =
        _whitelist.where((e) => e.kind != _FilterKind.variant).toSet();

    final forced     = <_SpinEntry>[];
    final candidates = <_SpinEntry>[];

    for (final char in widget.characters) {
      for (final variant in char.variants) {
        final entry   = _SpinEntry(char, variant);
        final isMain  = variant.folderName == char.mainVariant;
        final isForced = variantWhitelist.isNotEmpty &&
            variantWhitelist.any((e) => _matchesEntry(entry, e));

        if (isForced) {
          forced.add(entry);
        } else if (isMain || _includeVariants) {
          candidates.add(entry);
        }
      }
    }

    // Apply filters to base candidates
    final filteredCandidates = candidates.where((entry) {
      for (final e in _blacklist) {
        if (_matchesEntry(entry, e)) return false;
      }
      if (nonVariantWhitelist.isNotEmpty) {
        return nonVariantWhitelist.any((e) => _matchesEntry(entry, e));
      }
      return true;
    }).toList();

    // Apply only blacklist to forced entries
    final filteredForced = forced.where((entry) {
      return !_blacklist.any((e) => _matchesEntry(entry, e));
    }).toList();

    // Combine, deduplicate by key
    final seen   = <String>{};
    final result = <_SpinEntry>[];
    for (final e in [...filteredCandidates, ...filteredForced]) {
      if (seen.add(e.key)) result.add(e);
    }
    return result;
  }

  bool _matchesEntry(_SpinEntry entry, _FilterEntry filter) {
    final c = entry.character;
    switch (filter.kind) {
      case _FilterKind.name:
        return c.name.toLowerCase() == filter.value.toLowerCase();
      case _FilterKind.race:
        return c.race == filter.value;
      case _FilterKind.gender:
        return c.gender == filter.value;
      case _FilterKind.tag:
        return c.tags.contains(filter.value);
      case _FilterKind.tier:
        return c.tier != null && c.tier!.label == filter.value;
      case _FilterKind.variant:
        final parts = filter.value.split(':');
        if (parts.length < 2) return false;
        return c.id == parts[0] && entry.variant.folderName == parts[1];
    }
  }

  // ── Reel builder ───────────────────────────────────────────────

  void _buildReel() {
    final pool = _eligible;
    if (pool.isEmpty) return;

    final rng = Random();
    _winner = pool[rng.nextInt(pool.length)];

    final List<_SpinEntry> reel = [];
    for (int i = 0; i < _spinRepeats; i++) {
      final shuffled = List<_SpinEntry>.from(pool)..shuffle(rng);
      reel.addAll(shuffled);
    }
    final tailLength = (pool.length * 0.6).round().clamp(3, 12);
    for (int i = 0; i < tailLength; i++) {
      reel.add(pool[rng.nextInt(pool.length)]);
    }
    reel.add(_winner);
    _winnerIndex = reel.length - 1;
    for (int i = 0; i < 4; i++) {
      reel.add(pool[rng.nextInt(pool.length)]);
    }
    _reel = reel;
  }

  // ── Spin ───────────────────────────────────────────────────────

  void _spin() {
    if (_spinning || _eligible.isEmpty) return;
    setState(() { _spinning = true; _done = false; });

    final viewportCentre = _reelViewportWidth / 2;
    final cardCentre     = _winnerIndex * _cardStride + _cardWidth / 2;
    final targetOffset   = (cardCentre - viewportCentre).clamp(0.0, double.infinity);

    _anim = Tween<double>(begin: 0, end: targetOffset).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo),
    );

    _ctrl.reset();
    _anim.addListener(() {
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(_anim.value);
    });

    _ctrl.forward().then((_) {
      if (mounted && !_dismissed) {
        setState(() { _spinning = false; _done = true; });
      }
    });
  }

  void _reroll() {
    if (_spinning) return;
    _buildReel();
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    _spin();
  }

  // ── Filter helpers ─────────────────────────────────────────────

  List<_FilterEntry> _suggestions(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    final results = <_FilterEntry>[];

    // Tiers
    for (final t in CharacterTier.values) {
      if (t.label.toLowerCase().contains(q) || 'tier'.contains(q)) {
        results.add(_FilterEntry(t.label, _FilterKind.tier));
      }
    }
    // Races
    for (final r in ['Human', 'Newman', 'Deuman', 'CAST']) {
      if (r.toLowerCase().contains(q)) {
        results.add(_FilterEntry(r, _FilterKind.race));
      }
    }
    // Genders
    for (final g in ['Female', 'Male']) {
      if (g.toLowerCase().contains(q)) {
        results.add(_FilterEntry(g, _FilterKind.gender));
      }
    }
    // Tags
    final allTagIds = widget.characters.expand((c) => c.tags).toSet();
    for (final tagId in allTagIds) {
      final tag = widget.provider.tagById(tagId);
      if (tag != null && tag.name.toLowerCase().contains(q)) {
        results.add(_FilterEntry(tagId, _FilterKind.tag, label: tag.name));
      }
    }
    // Character names
    for (final c in widget.characters) {
      if (c.name.toLowerCase().contains(q)) {
        results.add(_FilterEntry(c.name, _FilterKind.name));
      }
    }
    // Variants — searched by "CharName · VariantName" or variant display name
    final seenVariantKeys = <String>{};
    for (final char in widget.characters) {
      for (final variant in char.variants) {
        final variantLabel = '${char.name} · ${variant.displayName}';
        if (variant.displayName.toLowerCase().contains(q) ||
            variantLabel.toLowerCase().contains(q)) {
          final key = '${char.id}:${variant.folderName}';
          if (seenVariantKeys.add(key)) {
            results.add(
                _FilterEntry(key, _FilterKind.variant, label: variantLabel));
          }
        }
      }
    }

    return results.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final eligible = _eligible;

    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: SizedBox(
        width: 600,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = MediaQuery.of(context).size.height - 48;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
            // ── Header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Icon(Icons.casino_outlined,
                      color: AppTheme.accent, size: 18),
                  const SizedBox(width: 8),
                  const Text('Random character',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  // Filter toggle
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showFilters = !_showFilters),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (_whitelist.isNotEmpty ||
                                _blacklist.isNotEmpty ||
                                _includeVariants)
                            ? AppTheme.accent.withOpacity(0.12)
                            : AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (_whitelist.isNotEmpty ||
                                  _blacklist.isNotEmpty ||
                                  _includeVariants)
                              ? AppTheme.accent
                              : AppTheme.borderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded,
                              size: 13,
                              color: (_whitelist.isNotEmpty ||
                                      _blacklist.isNotEmpty ||
                                      _includeVariants)
                                  ? AppTheme.accent
                                  : AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text('Filter',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: (_whitelist.isNotEmpty ||
                                          _blacklist.isNotEmpty ||
                                          _includeVariants)
                                      ? AppTheme.accent
                                      : AppTheme.textSecondary)),
                          if (_whitelist.isNotEmpty ||
                              _blacklist.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${_whitelist.length + _blacklist.length}',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.accent),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_spinning)
                    IconButton(
                      onPressed: () {
                        _dismissed = true;
                        Navigator.pop(context, null);
                      },
                      icon: const Icon(Icons.close,
                          size: 16, color: AppTheme.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),

            // ── Filter panel (collapsible) ───────────────────
            if (_showFilters) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FilterPanel(
                  whitelist: _whitelist,
                  blacklist: _blacklist,
                  suggestions: _suggestions,
                  eligibleCount: eligible.length,
                  includeVariants: _includeVariants,
                  onToggleVariants: () {
                    setState(() => _includeVariants = !_includeVariants);
                    if (!_spinning && !_done) _buildReel();
                  },
                  onChanged: () {
                    setState(() {});
                    if (!_spinning && !_done) _buildReel();
                  },
                ),
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.borderColor),
            const SizedBox(height: 16),

            // ── Reel area ────────────────────────────────────
            SizedBox(
              height: _cardHeight + 32,
              child: eligible.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 36,
                              color:
                                  AppTheme.textSecondary.withOpacity(0.4)),
                          const SizedBox(height: 10),
                          const Text('No characters match your filters',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_reelViewportWidth != constraints.maxWidth) {
                            _reelViewportWidth = constraints.maxWidth;
                          }
                        });
                        _reelViewportWidth = constraints.maxWidth;

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Cards
                            ShaderMask(
                              shaderCallback: (rect) => LinearGradient(
                                colors: [
                                  AppTheme.bgCard,
                                  Colors.transparent,
                                  Colors.transparent,
                                  AppTheme.bgCard,
                                ],
                                stops: const [0.0, 0.15, 0.85, 1.0],
                              ).createShader(rect),
                              blendMode: BlendMode.dstOut,
                              child: ListView.builder(
                                controller: _scrollCtrl,
                                scrollDirection: Axis.horizontal,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8),
                                itemCount: _reel.length,
                                itemBuilder: (_, i) => Padding(
                                  padding: const EdgeInsets.only(
                                      right: _cardSpacing),
                                  child: _ReelCard(entry: _reel[i]),
                                ),
                              ),
                            ),
                            // Centre marker box
                            IgnorePointer(
                              child: Container(
                                width: _cardWidth + 6,
                                height: _cardHeight + 16,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _done
                                        ? AppTheme.accent
                                        : AppTheme.accent
                                            .withOpacity(0.45),
                                    width: _done ? 2.0 : 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  color: _done
                                      ? AppTheme.accent.withOpacity(0.06)
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                            // Tick markers
                            Positioned(
                              top: 4,
                              child: _Tick(
                                  color: _done
                                      ? AppTheme.accent
                                      : AppTheme.accent.withOpacity(0.5)),
                            ),
                            Positioned(
                              bottom: 4,
                              child: _Tick(
                                  color: _done
                                      ? AppTheme.accent
                                      : AppTheme.accent.withOpacity(0.5),
                                  flipped: true),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // ── Result / spin button ─────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _done
                  ? _ResultPanel(
                      key: const ValueKey('result'),
                      winner: _winner,
                      onOpen: () {
                        _dismissed = true;
                        Navigator.pop(context, _winner.character);
                      },
                      onReroll: _reroll,
                    )
                  : _spinning
                      ? Padding(
                          key: const ValueKey('spinning'),
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text('Spinning…',
                              style: TextStyle(
                                  color: AppTheme.accent, fontSize: 13)),
                        )
                      : Padding(
                          key: const ValueKey('spin'),
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                onPressed: eligible.isEmpty ? null : _spin,
                                icon: const Icon(Icons.shuffle_rounded,
                                    size: 16),
                                label: const Text('Spin!'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 12),
                                  textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                              if (eligible.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '${eligible.length} eligible to spin',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
            ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Filter panel ───────────────────────────────────────────────────

class _FilterPanel extends StatefulWidget {
  final Set<_FilterEntry> whitelist;
  final Set<_FilterEntry> blacklist;
  final List<_FilterEntry> Function(String) suggestions;
  final int eligibleCount;
  final bool includeVariants;
  final VoidCallback onToggleVariants;
  final VoidCallback onChanged;

  const _FilterPanel({
    required this.whitelist,
    required this.blacklist,
    required this.suggestions,
    required this.eligibleCount,
    required this.includeVariants,
    required this.onToggleVariants,
    required this.onChanged,
  });

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  final _whiteCtrl = TextEditingController();
  final _blackCtrl = TextEditingController();
  List<_FilterEntry> _whiteSuggestions = [];
  List<_FilterEntry> _blackSuggestions = [];

  @override
  void dispose() {
    _whiteCtrl.dispose();
    _blackCtrl.dispose();
    super.dispose();
  }

  void _addToWhitelist(_FilterEntry e) {
    widget.whitelist.add(e);
    widget.blacklist.remove(e);
    _whiteCtrl.clear();
    setState(() => _whiteSuggestions = []);
    widget.onChanged();
  }

  void _addToBlacklist(_FilterEntry e) {
    widget.blacklist.add(e);
    widget.whitelist.remove(e);
    _blackCtrl.clear();
    setState(() => _blackSuggestions = []);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Include variants toggle ──────────────────────
          InkWell(
            onTap: widget.onToggleVariants,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.layers_outlined,
                      size: 13,
                      color: widget.includeVariants
                          ? AppTheme.accent
                          : AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Include variants',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: widget.includeVariants
                          ? AppTheme.accent
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '— each variant treated as a separate spin entry',
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary.withOpacity(0.6)),
                  ),
                  const Spacer(),
                  Switch(
                    value: widget.includeVariants,
                    onChanged: (_) => widget.onToggleVariants(),
                    activeColor: AppTheme.accent,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: AppTheme.borderColor),

          // Whitelist
          _FilterSection(
            label: 'Whitelist',
            labelColor: Colors.green,
            hint: 'Include: name, race, gender, tag, variant…',
            icon: Icons.add_circle_outline_rounded,
            entries: widget.whitelist,
            suggestions: _whiteSuggestions,
            controller: _whiteCtrl,
            onType: (q) => setState(
                () => _whiteSuggestions = widget.suggestions(q)),
            onAdd: _addToWhitelist,
            onRemove: (e) {
              widget.whitelist.remove(e);
              widget.onChanged();
              setState(() {});
            },
          ),

          const Divider(height: 1, color: AppTheme.borderColor),

          // Blacklist
          _FilterSection(
            label: 'Blacklist',
            labelColor: Colors.redAccent,
            hint: 'Exclude: name, race, gender, tag, variant…',
            icon: Icons.remove_circle_outline_rounded,
            entries: widget.blacklist,
            suggestions: _blackSuggestions,
            controller: _blackCtrl,
            onType: (q) => setState(
                () => _blackSuggestions = widget.suggestions(q)),
            onAdd: _addToBlacklist,
            onRemove: (e) {
              widget.blacklist.remove(e);
              widget.onChanged();
              setState(() {});
            },
          ),

          // Eligible count footer
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: AppTheme.borderColor)),
              borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Icon(
                  widget.eligibleCount > 0
                      ? Icons.check_circle_outline_rounded
                      : Icons.cancel_outlined,
                  size: 13,
                  color: widget.eligibleCount > 0
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.eligibleCount > 0
                      ? '${widget.eligibleCount} eligible to spin'
                      : 'No entries match — adjust your filters',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.eligibleCount > 0
                        ? AppTheme.textSecondary
                        : Colors.redAccent,
                  ),
                ),
                const Spacer(),
                if (widget.whitelist.isNotEmpty ||
                    widget.blacklist.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      widget.whitelist.clear();
                      widget.blacklist.clear();
                      widget.onChanged();
                      setState(() {});
                    },
                    child: const Text('Clear all',
                        style: TextStyle(
                            color: Colors.redAccent, fontSize: 11)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter section (whitelist or blacklist) ────────────────────────

class _FilterSection extends StatelessWidget {
  final String label;
  final Color labelColor;
  final String hint;
  final IconData icon;
  final Set<_FilterEntry> entries;
  final List<_FilterEntry> suggestions;
  final TextEditingController controller;
  final void Function(String) onType;
  final void Function(_FilterEntry) onAdd;
  final void Function(_FilterEntry) onRemove;

  const _FilterSection({
    required this.label,
    required this.labelColor,
    required this.hint,
    required this.icon,
    required this.entries,
    required this.suggestions,
    required this.controller,
    required this.onType,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(
            children: [
              Icon(icon, size: 13, color: labelColor),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: labelColor)),
            ],
          ),
          const SizedBox(height: 6),

          // Chips
          if (entries.isNotEmpty) ...[
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: entries.map((e) {
                final color = e.color(context);
                return Container(
                  padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.label,
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 3),
                      GestureDetector(
                        onTap: () => onRemove(e),
                        child: Icon(Icons.close,
                            size: 11, color: color),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
          ],

          // Search input
          TextField(
            controller: controller,
            onChanged: onType,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 14, color: AppTheme.textSecondary),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 6),
              isDense: true,
            ),
          ),

          // Suggestions dropdown
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: suggestions.map((s) {
                  final color = s.color(context);
                  final alreadyAdded = entries.contains(s);
                  return InkWell(
                    onTap: alreadyAdded ? null : () => onAdd(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            child: Text(s.kind.name,
                                style: TextStyle(
                                    color: color, fontSize: 9)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(s.label,
                                style: TextStyle(
                                    color: alreadyAdded
                                        ? AppTheme.textSecondary
                                        : AppTheme.textPrimary,
                                    fontSize: 12)),
                          ),
                          if (alreadyAdded)
                            const Text('added',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tick marker ────────────────────────────────────────────────────

class _Tick extends StatelessWidget {
  final Color color;
  final bool flipped;
  const _Tick({required this.color, this.flipped = false});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleY: flipped ? -1 : 1,
      child: CustomPaint(
        size: const Size(12, 8),
        painter: _TickPainter(color: color),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  final Color color;
  const _TickPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.color != color;
}

// ── Individual reel card ───────────────────────────────────────────

class _ReelCard extends StatelessWidget {
  final _SpinEntry entry;
  const _ReelCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final c        = entry.character;
    final thumb    = entry.thumbnailPath;
    final hasThumb = thumb != null && File(thumb).existsSync();
    final raceColor = AppTheme.raceColor(c.race);

    return Container(
      width: _cardWidth,
      height: _cardHeight,
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: raceColor.withOpacity(0.35)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Column(
          children: [
            Expanded(
              child: hasThumb
                  ? Image.file(
                      File(thumb),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : Container(
                      color: AppTheme.bgSurface,
                      child: Center(
                        child: Icon(Icons.person_outline,
                            size: 40,
                            color: raceColor.withOpacity(0.35)),
                      ),
                    ),
            ),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              color: AppTheme.bgCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!entry.isMainVariant) ...[
                    const SizedBox(height: 1),
                    Text(
                      entry.variant.displayName,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 8),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 1),
                  Text(
                    '${c.race} · ${c.gender[0]}',
                    style: TextStyle(color: raceColor, fontSize: 9),
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

// ── Result panel ───────────────────────────────────────────────────

class _ResultPanel extends StatelessWidget {
  final _SpinEntry winner;
  final VoidCallback onOpen;
  final VoidCallback onReroll;

  const _ResultPanel({
    super.key,
    required this.winner,
    required this.onOpen,
    required this.onReroll,
  });

  @override
  Widget build(BuildContext context) {
    final c = winner.character;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('You got:',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
                const Spacer(),
                Text('${c.race} · ${c.gender}',
                    style: TextStyle(
                        color: AppTheme.raceColor(c.race),
                        fontSize: 11)),
              ],
            ),
            const SizedBox(height: 2),
            Text(c.name,
                style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            if (!winner.isMainVariant) ...[
              const SizedBox(height: 2),
              Text(
                winner.variant.displayName,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReroll,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Reroll', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.borderColor),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text('View character',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
