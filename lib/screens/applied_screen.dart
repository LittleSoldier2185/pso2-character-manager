import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character_data.dart';
import '../providers/character_provider.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/character_card.dart';
import '../widgets/skeleton.dart';
import 'character_detail_screen.dart';

class AppliedScreen extends StatefulWidget {
  const AppliedScreen({super.key});

  @override
  State<AppliedScreen> createState() => _AppliedScreenState();
}

class _AppliedScreenState extends State<AppliedScreen> {
  String _search = '';
  int _cardSize = 2;
  SortOption _sortOption = SortOption.nameAZ;

  static const List<double> _sizeExtents  = [120, 160, 200, 260];
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

  List<CharacterData> _sorted(List<CharacterData> list) {
    final out = List<CharacterData>.from(list);
    switch (_sortOption) {
      case SortOption.nameAZ:
        out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case SortOption.nameZA:
        out.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      case SortOption.newestFirst:
        out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case SortOption.oldestFirst:
        out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case SortOption.lastApplied:
        out.sort((a, b) {
          final at = a.lastSyncedAt ?? a.createdAt;
          final bt = b.lastSyncedAt ?? b.createdAt;
          return bt.compareTo(at);
        });
      case SortOption.tierHighest:
        out.sort((a, b) {
          final at = a.tierIndex ?? 999;
          final bt = b.tierIndex ?? 999;
          if (at != bt) return at.compareTo(bt);
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      case SortOption.lastModified:
        out.sort((a, b) => b.lastModifiedAt.compareTo(a.lastModifiedAt));
    }
    return out;
  }

  IconData _sizeIcon(int s) {
    switch (s) {
      case 0:  return Icons.grid_on_rounded;
      case 1:  return Icons.grid_view_rounded;
      case 2:  return Icons.view_agenda_outlined;
      default: return Icons.crop_free_rounded;
    }
  }

  PopupMenuItem<int> _sizeItem(int value, String label, IconData icon) {
    final sel = _cardSize == value;
    return PopupMenuItem<int>(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 15,
              color: sel ? AppTheme.accent : AppTheme.textSecondary),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: sel ? AppTheme.accent : AppTheme.textPrimary)),
          if (sel) ...[
            const Spacer(),
            Icon(Icons.check_rounded, size: 13, color: AppTheme.accent),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<SortOption> _sortItem(SortOption opt) {
    final sel = _sortOption == opt;
    return PopupMenuItem<SortOption>(
      value: opt,
      child: Row(
        children: [
          Icon(opt.icon,
              size: 14,
              color: sel ? AppTheme.accent : AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(opt.label,
              style: TextStyle(
                  fontSize: 13,
                  color: sel ? AppTheme.accent : AppTheme.textPrimary)),
          if (sel) ...[
            const Spacer(),
            Icon(Icons.check_rounded, size: 13, color: AppTheme.accent),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        var applied = provider.appliedCharacters;
        final totalCount = applied.length;

        if (_search.isNotEmpty) {
          applied = applied
              .where((c) =>
                  c.name.toLowerCase().contains(_search.toLowerCase()))
              .toList();
        }
        applied = _sorted(applied);

        // Expand to one entry per applied variant
        final pairs = [
          for (final c in applied)
            for (final v in c.appliedVariants) (c, v),
        ];

        return Column(
          children: [
            // ── Top bar ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text(
                    _search.isNotEmpty
                        ? '${applied.length} of $totalCount applied'
                        : '$totalCount applied',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                  // Search bar
                  SizedBox(
                    width: 190,
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search applied…',
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 15, color: AppTheme.textSecondary),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                onPressed: () => setState(() => _search = ''),
                              )
                            : null,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                      ),
                      style: TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sort button
                  PopupMenuButton<SortOption>(
                    color: AppTheme.bgCard,
                    tooltip: 'Sort',
                    icon: Icon(_sortOption.icon,
                        size: 16, color: AppTheme.textSecondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppTheme.borderColor),
                    ),
                    onSelected: (opt) => setState(() => _sortOption = opt),
                    itemBuilder: (_) => SortOption.values
                        .map(_sortItem)
                        .toList(),
                  ),
                  const SizedBox(width: 4),
                  // Card size button
                  PopupMenuButton<int>(
                    color: AppTheme.bgCard,
                    tooltip: 'Card size',
                    icon: Icon(_sizeIcon(_cardSize),
                        size: 16, color: AppTheme.textSecondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppTheme.borderColor),
                    ),
                    onSelected: (i) async {
                      setState(() => _cardSize = i);
                      await DataService.instance.saveCardSize(i);
                    },
                    itemBuilder: (_) => [
                      _sizeItem(3, 'Extra large', Icons.crop_free_rounded),
                      _sizeItem(2, 'Large', Icons.view_agenda_outlined),
                      _sizeItem(1, 'Medium', Icons.grid_view_rounded),
                      _sizeItem(0, 'Small', Icons.grid_on_rounded),
                    ],
                  ),
                  const Spacer(),
                  _GameFolderStatus(provider: provider),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────
            Expanded(
              child: provider.isLoading
                  ? SkeletonCardGrid(cardSize: _cardSize)
                  : totalCount == 0
                  ? _buildEmpty()
                  : applied.isEmpty
                      ? Center(
                          child: Text(
                            'No results for "$_search"',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 14),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: _sizeExtents[_cardSize],
                            childAspectRatio: _aspectRatios[_cardSize],
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: pairs.length,
                          itemBuilder: (context, index) {
                            final (c, vName) = pairs[index];
                            return CharacterCard(
                              character: c,
                              cardSize: _cardSize,
                              variantFolderName: vName,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        CharacterDetailScreen(character: c)),
                              ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No characters applied yet',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Click the + button on any character card to apply it',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Game folder status chip ────────────────────────────────────────

class _GameFolderStatus extends StatelessWidget {
  final CharacterProvider provider;
  const _GameFolderStatus({required this.provider});

  @override
  Widget build(BuildContext context) {
    final hasFolder = provider.gameFolderPath != null;
    return GestureDetector(
      onTap: () => _showFolderDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: hasFolder
              ? AppTheme.accent.withOpacity(0.1)
              : AppTheme.accentGold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: hasFolder
                ? AppTheme.accent.withOpacity(0.4)
                : AppTheme.accentGold.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFolder ? Icons.folder_rounded : Icons.folder_off_outlined,
              size: 13,
              color: hasFolder ? AppTheme.accent : AppTheme.accentGold,
            ),
            const SizedBox(width: 5),
            Text(
              hasFolder ? 'Game folder set' : 'Set game folder',
              style: TextStyle(
                fontSize: 11,
                color: hasFolder ? AppTheme.accent : AppTheme.accentGold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFolderDialog(BuildContext context) {
    final controller =
        TextEditingController(text: provider.gameFolderPath ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('PSO2 game folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set the path to your PSO2 character data folder.\n\n'
              'Example: C:\\PSO2\\pso2_bin\\data\\win32',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'C:\\PSO2\\pso2_bin\\data\\win32',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final path = controller.text.trim();
              if (path.isNotEmpty) {
                await provider.setGameFolderPath(path);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
