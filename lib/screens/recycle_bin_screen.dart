import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character_data.dart';
import '../providers/character_provider.dart';
import '../theme/app_theme.dart';

class RecycleBinScreen extends StatelessWidget {
  const RecycleBinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        final items = provider.trashItems;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text('Recycle Bin',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  if (items.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${items.length}',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 10)),
                    ),
                  const Spacer(),
                  if (items.isNotEmpty)
                    TextButton(
                      onPressed: () => _confirmEmptyBin(context, provider, items),
                      style: TextButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 0.8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Empty bin',
                          style: TextStyle(color: Colors.red, fontSize: 11)),
                    ),
                ],
              ),
            ),
            // ── Subtitle ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Items are permanently deleted after 7 days.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ),
            // ── List ───────────────────────────────────────────
            Expanded(
              child: items.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _TrashRow(
                          character: item.character,
                          deletedAt: item.deletedAt,
                          onRestore: () => provider.restoreCharacter(item.character.id),
                          onDelete: () => _confirmPermanentDelete(
                              context, provider, item.character),
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
          Icon(Icons.delete_outline_rounded,
              size: 64,
              color: AppTheme.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Recycle bin is empty',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _confirmPermanentDelete(
      BuildContext context, CharacterProvider provider, CharacterData character) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Delete permanently?'),
        content: Text(
            '"${character.name}" will be deleted forever and cannot be recovered.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.permanentlyDeleteFromTrash(character.id);
              Navigator.pop(context);
            },
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
  }

  void _confirmEmptyBin(BuildContext context, CharacterProvider provider,
      List<({CharacterData character, DateTime deletedAt})> items) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Empty recycle bin?'),
        content: Text(
            'Permanently delete all ${items.length} item${items.length == 1 ? '' : 's'}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              for (final item in List.of(items)) {
                await provider.permanentlyDeleteFromTrash(item.character.id);
              }
            },
            child: const Text('Empty bin'),
          ),
        ],
      ),
    );
  }
}

// ── Trash row ─────────────────────────────────────────────────────

class _TrashRow extends StatelessWidget {
  final CharacterData character;
  final DateTime deletedAt;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _TrashRow({
    required this.character,
    required this.deletedAt,
    required this.onRestore,
    required this.onDelete,
  });

  String get _timeInfo {
    final daysAgo = DateTime.now().difference(deletedAt).inDays;
    final daysLeft = 7 - daysAgo;
    final agoStr = daysAgo == 0
        ? 'today'
        : daysAgo == 1
            ? '1 day ago'
            : '$daysAgo days ago';
    final leftStr = daysLeft <= 0
        ? 'expires soon'
        : daysLeft == 1
            ? '1 day left'
            : '$daysLeft days left';
    return 'Deleted $agoStr · $leftStr';
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = 7 - DateTime.now().difference(deletedAt).inDays;
    final isExpiringSoon = daysLeft <= 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 44,
              height: 44,
              child: _buildThumb(),
            ),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.name,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${character.race} · ${character.gender}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  _timeInfo,
                  style: TextStyle(
                    color: isExpiringSoon ? Colors.red : AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Restore button
          TextButton(
            onPressed: onRestore,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: AppTheme.accent.withOpacity(0.5)),
            ),
            child: Text('Restore',
                style: TextStyle(color: AppTheme.accent, fontSize: 12)),
          ),
          const SizedBox(width: 6),
          // Permanent delete
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_forever_rounded),
            iconSize: 18,
            color: AppTheme.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Delete forever',
          ),
        ],
      ),
    );
  }

  Widget _buildThumb() {
    final thumbPath = character.thumbnailPath;
    if (thumbPath != null && File(thumbPath).existsSync()) {
      return Image.file(File(thumbPath), fit: BoxFit.cover);
    }
    return Container(
      color: AppTheme.bgSurface,
      child: Center(
        child: Icon(Icons.person_outline,
            size: 24,
            color: AppTheme.raceColor(character.race).withOpacity(0.4)),
      ),
    );
  }
}
