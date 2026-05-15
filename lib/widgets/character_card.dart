import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character.dart';
import '../providers/character_provider.dart';
import '../theme/app_theme.dart';
import 'tag_chip.dart';

class CharacterCard extends StatelessWidget {
  final Character character;
  final VoidCallback onTap;

  const CharacterCard(
      {super.key, required this.character, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        final hasUpdate = provider.hasUpdate(character.id);

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasUpdate
                    ? AppTheme.accentGold
                    : character.isApplied
                        ? AppTheme.accent
                        : AppTheme.borderColor,
                width: (hasUpdate || character.isApplied) ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Thumbnail ────────────────────────────────────
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildThumbnail(),
                        // Race dot
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.raceColor(character.race),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // Favourite heart — bottom left
                        Positioned(
                          bottom: 5,
                          left: 5,
                          child: GestureDetector(
                            onTap: () => provider.toggleFavourite(character),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: character.isFavourite
                                    ? Colors.pinkAccent.withOpacity(0.85)
                                    : Colors.black.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                character.isFavourite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 11,
                                color: character.isFavourite
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ),
                        // Update badge — top right (takes priority over slot)
                        if (hasUpdate)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGold,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                      Icons.sync_rounded,
                                      size: 9,
                                      color: AppTheme.bgDark),
                                  const SizedBox(width: 2),
                                  const Text(
                                    'Updated',
                                    style: TextStyle(
                                        color: AppTheme.bgDark,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (character.isApplied &&
                            character.slotNumber != null)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Slot ${character.slotNumber}',
                                style: const TextStyle(
                                    color: AppTheme.bgDark,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // ── Info + apply button ───────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 7, 6, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  character.name,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${character.race} · ${character.gender[0]}',
                                  style: TextStyle(
                                      color:
                                          AppTheme.raceColor(character.race),
                                      fontSize: 10),
                                ),
                                if (character.description.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    character.description,
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          _ApplyToggleButton(character: character),
                        ],
                      ),
                      // Update row — shown below name when game folder has newer file
                      if (hasUpdate) ...[
                        const SizedBox(height: 6),
                        _UpdateRow(character: character),
                      ],
                      if (character.tags.isNotEmpty && !hasUpdate) ...[
                        const SizedBox(height: 5),
                        Material(
                          type: MaterialType.transparency,
                          child: Wrap(
                            spacing: 3,
                            runSpacing: 3,
                            children: character.tags
                                .take(2)
                                .map((id) {
                                  final tag = provider.tagById(id);
                                  return tag != null
                                      ? TagChip(tag: tag)
                                      : const SizedBox.shrink();
                                })
                                .toList(),
                          ),
                        ),
                      ],
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

  Widget _buildThumbnail() {
    if (character.thumbnailPath != null) {
      final file = File(character.thumbnailPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return Container(
      color: AppTheme.bgSurface,
      child: Center(
        child: Icon(Icons.person_outline,
            size: 36,
            color:
                AppTheme.raceColor(character.race).withOpacity(0.35)),
      ),
    );
  }
}

// ── Update row ─────────────────────────────────────────────────────

class _UpdateRow extends StatefulWidget {
  final Character character;
  const _UpdateRow({required this.character});

  @override
  State<_UpdateRow> createState() => _UpdateRowState();
}

class _UpdateRowState extends State<_UpdateRow> {
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final provider = context.read<CharacterProvider>();
    final error =
        await provider.syncCharacterFromGameFolder(widget.character);
    if (mounted) {
      setState(() => _syncing = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Character synced from game folder'),
          backgroundColor: Colors.green,
        ));
      }
    }
  }

  void _showSyncDialog() {
    final provider = context.read<CharacterProvider>();
    final updateTime = provider.getUpdateTime(widget.character.id);
    final syncedAt = widget.character.lastSyncedAt;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.sync_rounded,
                  color: AppTheme.accentGold, size: 16),
            ),
            const SizedBox(width: 10),
            const Text('Character file updated'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${widget.character.name}" was modified in PSO2 after being applied. '
              'The game folder has a newer version than what is stored in your library.',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Library file: ',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                      Text(
                        syncedAt != null
                            ? _formatDateTime(syncedAt)
                            : 'Unknown',
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('Game folder file: ',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                      Text(
                        updateTime != null
                            ? _formatDateTime(updateTime)
                            : 'Unknown',
                        style: TextStyle(
                            color: AppTheme.accentGold, fontSize: 12),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('newer',
                            style: TextStyle(
                                color: AppTheme.accentGold,
                                fontSize: 9,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Syncing will copy the updated file from the game folder back into your library.',
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.dismissUpdate(widget.character.id);
              Navigator.pop(context);
            },
            child: const Text('Keep old version'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _sync();
            },
            icon: const Icon(Icons.sync_rounded, size: 14),
            label: const Text('Sync from game folder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: AppTheme.bgDark,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _syncing ? null : _showSyncDialog,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        decoration: BoxDecoration(
          color: AppTheme.accentGold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
              color: AppTheme.accentGold.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            _syncing
                ? SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppTheme.accentGold),
                  )
                : Icon(Icons.sync_rounded,
                    size: 11, color: AppTheme.accentGold),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _syncing ? 'Syncing…' : 'File updated in game',
                style: TextStyle(
                    color: AppTheme.accentGold, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!_syncing)
              Text(
                'Sync ↗',
                style: TextStyle(
                    color: AppTheme.accentGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w500),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Apply toggle button ────────────────────────────────────────────

class _ApplyToggleButton extends StatefulWidget {
  final Character character;
  const _ApplyToggleButton({required this.character});

  @override
  State<_ApplyToggleButton> createState() => _ApplyToggleButtonState();
}

class _ApplyToggleButtonState extends State<_ApplyToggleButton> {
  bool _loading = false;

  Future<void> _toggle() async {
    setState(() => _loading = true);
    final provider = context.read<CharacterProvider>();
    final error = await provider.toggleApply(widget.character);
    if (mounted) {
      setState(() => _loading = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApplied = widget.character.isApplied;
    return GestureDetector(
      onTap: _loading ? null : _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isApplied ? AppTheme.accent : AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: isApplied ? AppTheme.accent : AppTheme.borderColor),
        ),
        child: _loading
            ? Padding(
                padding: const EdgeInsets.all(5),
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppTheme.accent))
            : Icon(
                isApplied ? Icons.check_rounded : Icons.add_rounded,
                size: 16,
                color: isApplied ? AppTheme.bgDark : AppTheme.textSecondary),
      ),
    );
  }
}
