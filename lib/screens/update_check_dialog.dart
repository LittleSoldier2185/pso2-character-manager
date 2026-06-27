import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character_data.dart';
import '../providers/character_provider.dart';
import '../theme/app_theme.dart';

class UpdateCheckDialog extends StatefulWidget {
  const UpdateCheckDialog({super.key});

  @override
  State<UpdateCheckDialog> createState() => _UpdateCheckDialogState();
}

class _UpdateEntry {
  final CharacterData character;
  final String variantFolderName;
  final String variantDisplayName;
  final DateTime gameModified;

  const _UpdateEntry({
    required this.character,
    required this.variantFolderName,
    required this.variantDisplayName,
    required this.gameModified,
  });

  String get actionKey => '${character.id}:$variantFolderName';
}

class _UpdateCheckDialogState extends State<UpdateCheckDialog> {
  bool _checking = true;
  final Set<String> _actioning = {};

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    setState(() => _checking = true);
    await context.read<CharacterProvider>().checkForUpdates();
    if (mounted) setState(() => _checking = false);
  }

  List<_UpdateEntry> _buildEntries(CharacterProvider provider) {
    final entries = <_UpdateEntry>[];
    for (final c in provider.charactersWithUpdates) {
      final times = provider.getVariantUpdateTimes(c.id);
      for (final e in times.entries) {
        final variant =
            c.variants.where((v) => v.folderName == e.key).firstOrNull;
        entries.add(_UpdateEntry(
          character: c,
          variantFolderName: e.key,
          variantDisplayName: variant?.displayName ?? e.key,
          gameModified: e.value,
        ));
      }
    }
    return entries;
  }

  Future<void> _update(_UpdateEntry entry) async {
    setState(() => _actioning.add(entry.actionKey));
    final error = await context
        .read<CharacterProvider>()
        .syncCharacterFromGameFolder(
            entry.character, entry.variantFolderName);
    if (!mounted) return;
    setState(() => _actioning.remove(entry.actionKey));
    if (error != null) _showError(error);
  }

  Future<void> _addNew(_UpdateEntry entry) async {
    setState(() => _actioning.add(entry.actionKey));
    final error = await context
        .read<CharacterProvider>()
        .addNewFromGameFolder(entry.character, entry.variantFolderName);
    if (!mounted) return;
    setState(() => _actioning.remove(entry.actionKey));
    if (error != null) _showError(error);
  }

  void _ignore(_UpdateEntry entry) => context
      .read<CharacterProvider>()
      .dismissUpdate(entry.character.id,
          variantFolderName: entry.variantFolderName);

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
    ));
  }

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        if (provider.gameFolderPath == null) {
          return _buildNoGameFolder();
        }

        final entries = _buildEntries(provider);

        return Dialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
            child: Column(
              children: [
                // ── Header ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                  child: Row(
                    children: [
                      Icon(Icons.sync_rounded, size: 16, color: AppTheme.accent),
                      const SizedBox(width: 8),
                      Text(
                        'Sync from game',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500),
                      ),
                      if (!_checking && entries.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${entries.length}',
                            style: const TextStyle(
                                color: AppTheme.accentGold,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
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

                // ── Body ───────────────────────────────────────────
                Expanded(
                  child: _checking
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 14),
                              Text('Checking files…',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        )
                      : entries.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded,
                                      size: 52,
                                      color: AppTheme.accent
                                          .withValues(alpha: 0.35)),
                                  const SizedBox(height: 14),
                                  Text(
                                    'All files are up to date',
                                    style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'No newer versions found in the game folder',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              itemCount: entries.length,
                              itemBuilder: (_, i) {
                                final entry = entries[i];
                                final actioning =
                                    _actioning.contains(entry.actionKey);
                                return _UpdateRow(
                                  entry: entry,
                                  actioning: actioning,
                                  onUpdate:
                                      actioning ? null : () => _update(entry),
                                  onAddNew:
                                      actioning ? null : () => _addNew(entry),
                                  onIgnore:
                                      actioning ? null : () => _ignore(entry),
                                  formatDate: _fmt,
                                );
                              },
                            ),
                ),

                // ── Footer ─────────────────────────────────────────
                Divider(height: 1, color: AppTheme.borderColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: _checking ? null : _runCheck,
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text('Recheck'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoGameFolder() {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_off_outlined,
                  size: 44,
                  color: AppTheme.accentGold.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text('Game folder not set',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(
                'Set your PSO2 game folder path in Settings to enable update detection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Single update row ─────────────────────────────────────────────

class _UpdateRow extends StatelessWidget {
  final _UpdateEntry entry;
  final bool actioning;
  final VoidCallback? onUpdate;
  final VoidCallback? onAddNew;
  final VoidCallback? onIgnore;
  final String Function(DateTime) formatDate;

  const _UpdateRow({
    required this.entry,
    required this.actioning,
    required this.onUpdate,
    required this.onAddNew,
    required this.onIgnore,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final c = entry.character;
    final raceColor = AppTheme.raceColor(c.race);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: raceColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: raceColor.withValues(alpha: 0.3)),
            ),
            child: c.thumbnailPath != null &&
                    File(c.thumbnailPath!).existsSync()
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.file(File(c.thumbnailPath!),
                        fit: BoxFit.cover))
                : Icon(Icons.person_outline,
                    size: 18, color: raceColor.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 10),
          // Name + variant + info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('${c.race} · ${c.gender[0]}',
                        style: TextStyle(color: raceColor, fontSize: 10)),
                    const SizedBox(width: 4),
                    Text('· ${entry.variantDisplayName}',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(width: 6),
                    Text(
                      '· updated ${formatDate(entry.gameModified)}',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Action buttons / spinner
          if (actioning)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.accent),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Btn(
                  label: 'Update',
                  color: AppTheme.accent,
                  filled: true,
                  onTap: onUpdate,
                ),
                const SizedBox(width: 5),
                _Btn(
                  label: 'Add new',
                  color: AppTheme.textSecondary,
                  onTap: onAddNew,
                ),
                const SizedBox(width: 2),
                TextButton(
                  onPressed: onIgnore,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: const Text('Ignore'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;

  const _Btn({
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 11);
    const padding = EdgeInsets.symmetric(horizontal: 10, vertical: 4);
    const size = Size.zero;
    const target = MaterialTapTargetSize.shrinkWrap;

    if (filled) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppTheme.bgDark,
          padding: padding,
          minimumSize: size,
          tapTargetSize: target,
          textStyle: style,
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: padding,
        minimumSize: size,
        tapTargetSize: target,
        textStyle: style,
      ),
      child: Text(label),
    );
  }
}
