import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/tag_data.dart';
import '../providers/character_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/tag_chip.dart';

class AlbumTagsScreen extends StatefulWidget {
  const AlbumTagsScreen({super.key});

  @override
  State<AlbumTagsScreen> createState() => _AlbumTagsScreenState();
}

class _AlbumTagsScreenState extends State<AlbumTagsScreen> {
  String _search = '';
  _SortOption _sort = _SortOption.nameAZ;

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        var tags = provider.allAlbumTags;
        if (_search.isNotEmpty) {
          tags = tags
              .where((t) => t.name.toLowerCase().contains(_search.toLowerCase()))
              .toList();
        }
        tags = List.from(tags);
        switch (_sort) {
          case _SortOption.nameAZ:
            tags.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          case _SortOption.nameZA:
            tags.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
          case _SortOption.mostUsed:
            tags.sort((a, b) => provider.albumTagUsageCount(b.id).compareTo(provider.albumTagUsageCount(a.id)));
          case _SortOption.leastUsed:
            tags.sort((a, b) => provider.albumTagUsageCount(a.id).compareTo(provider.albumTagUsageCount(b.id)));
          case _SortOption.newestFirst:
            tags.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          case _SortOption.oldestFirst:
            tags.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        }

        final allTags = provider.allAlbumTags;
        final unusedTags = allTags.where((t) => provider.albumTagUsageCount(t.id) == 0).toList();

        return Column(
          children: [
            // ── Top bar ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  Icon(Icons.label_rounded, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    _search.isNotEmpty
                        ? '${tags.length} of ${allTags.length} album tags'
                        : allTags.isEmpty
                            ? 'Album Tags'
                            : '${allTags.length} album tag${allTags.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search album tags…',
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 15, color: AppTheme.textSecondary),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                onPressed: () => setState(() => _search = ''),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                      ),
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PopupMenuButton<_SortOption>(
                    color: AppTheme.bgCard,
                    tooltip: 'Sort',
                    icon: Icon(_sort.icon, size: 16, color: AppTheme.textSecondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppTheme.borderColor),
                    ),
                    onSelected: (opt) => setState(() => _sort = opt),
                    itemBuilder: (_) => _SortOption.values
                        .map((opt) => PopupMenuItem<_SortOption>(
                              value: opt,
                              child: Row(
                                children: [
                                  Icon(opt.icon,
                                      size: 14,
                                      color: _sort == opt
                                          ? AppTheme.accent
                                          : AppTheme.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(opt.label,
                                      style: TextStyle(
                                          color: _sort == opt
                                              ? AppTheme.accent
                                              : AppTheme.textPrimary,
                                          fontSize: 13)),
                                  if (_sort == opt) ...[
                                    const Spacer(),
                                    Icon(Icons.check_rounded,
                                        size: 13, color: AppTheme.accent),
                                  ],
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showTagDialog(context, provider),
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('New tag', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────────
            Expanded(
              child: tags.isEmpty
                  ? _search.isNotEmpty
                      ? _buildNoResults()
                      : _buildEmpty(context, provider)
                  : _buildGrid(context, provider, tags, allTags, unusedTags),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoResults() => Center(
        child: Text('No tags match "$_search"',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
      );

  Widget _buildEmpty(BuildContext context, CharacterProvider provider) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.label_outline_rounded,
                size: 56,
                color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No album tags yet',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('Create tags to organise your albums.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showTagDialog(context, provider),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Create first tag'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      );

  Widget _buildGrid(BuildContext context, CharacterProvider provider,
      List<TagData> tags, List<TagData> allTags, List<TagData> unusedTags) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Row(
            children: [
              _StatCard(label: 'Total tags', value: '${allTags.length}', icon: Icons.label_rounded),
              const SizedBox(width: 12),
              _StatCard(
                  label: 'In use',
                  value: '${allTags.where((t) => provider.albumTagUsageCount(t.id) > 0).length}',
                  icon: Icons.photo_album_outlined),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Unused',
                value: '${unusedTags.length}',
                icon: Icons.link_off_rounded,
                onDelete: unusedTags.isNotEmpty
                    ? () => _deleteAllUnused(context, provider, unusedTags)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (_, constraints) {
            final cols = constraints.maxWidth > 700 ? 3 : 2;
            final itemWidth = (constraints.maxWidth - (cols - 1) * 12) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: tags.map((tag) {
                final count = provider.albumTagUsageCount(tag.id);
                return SizedBox(
                  width: itemWidth,
                  child: _TagCard(
                    tag: tag,
                    usageCount: count,
                    onEdit: () => _showTagDialog(context, provider, tag: tag),
                    onDelete: () => _confirmDelete(context, provider, tag),
                    onTap: count > 0
                        ? () {
                            provider.clearAlbumTagFilter();
                            provider.toggleAlbumTagFilter(tag.id);
                            MainShell.switchTabNotifier.value = 4;
                          }
                        : null,
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _deleteAllUnused(BuildContext context, CharacterProvider provider,
      List<TagData> unused) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Delete all unused tags?'),
        content: Text(
          'Permanently delete ${unused.length} unused tag${unused.length == 1 ? '' : 's'}.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      for (final tag in unused) {
        await provider.deleteAlbumTag(tag);
      }
    }
  }

  void _showTagDialog(BuildContext context, CharacterProvider provider, {TagData? tag}) {
    showDialog(
      context: context,
      builder: (_) => _TagDialog(tag: tag, provider: provider),
    );
  }

  void _confirmDelete(BuildContext context, CharacterProvider provider, TagData tag) {
    final count = provider.albumTagUsageCount(tag.id);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Delete tag?'),
        content: Text(
          count > 0
              ? '"${tag.name}" is used by $count album${count == 1 ? '' : 's'}. It will be removed from all of them.'
              : '"${tag.name}" is not used by any albums.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await provider.deleteAlbumTag(tag);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onDelete;

  const _StatCard({required this.label, required this.value, required this.icon, this.onDelete});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.accent.withValues(alpha: 0.7)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                    Text(label,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              if (onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  child: Tooltip(
                    message: 'Delete all unused',
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_sweep_outlined,
                          size: 15, color: Colors.redAccent.withValues(alpha: 0.7)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

// ── Tag card ───────────────────────────────────────────────────────

class _TagCard extends StatefulWidget {
  final TagData tag;
  final int usageCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const _TagCard({
    required this.tag,
    required this.usageCount,
    required this.onEdit,
    required this.onDelete,
    this.onTap,
  });

  @override
  State<_TagCard> createState() => _TagCardState();
}

class _TagCardState extends State<_TagCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tag = widget.tag;
    final color = tag.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hovered ? color.withValues(alpha: 0.06) : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? color.withValues(alpha: 0.5) : AppTheme.borderColor,
              width: _hovered ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 10, height: 10,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(tag.name,
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        GestureDetector(
                          onTap: widget.onEdit,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.edit_outlined,
                                size: 14,
                                color: _hovered
                                    ? AppTheme.textSecondary
                                    : AppTheme.textSecondary.withValues(alpha: 0.4)),
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onDelete,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.delete_outline,
                                size: 14,
                                color: _hovered
                                    ? Colors.redAccent
                                    : Colors.redAccent.withValues(alpha: 0.3)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Material(type: MaterialType.transparency, child: TagChip(tag: tag)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          widget.usageCount > 0
                              ? Icons.photo_album_rounded
                              : Icons.photo_album_outlined,
                          size: 12,
                          color: widget.usageCount > 0
                              ? color.withValues(alpha: 0.8)
                              : AppTheme.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.usageCount > 0
                              ? '${widget.usageCount} album${widget.usageCount == 1 ? '' : 's'}'
                              : 'Unused',
                          style: TextStyle(
                            fontSize: 11,
                            color: widget.usageCount > 0
                                ? color.withValues(alpha: 0.8)
                                : AppTheme.textSecondary.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
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
}

// ── Create / edit tag dialog ───────────────────────────────────────

class _TagDialog extends StatefulWidget {
  final TagData? tag;
  final CharacterProvider provider;
  const _TagDialog({this.tag, required this.provider});

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  late TextEditingController _nameCtrl;
  late Color _color;
  bool _saving = false;

  bool get _isEdit => widget.tag != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.tag?.name ?? '');
    _color = widget.tag?.color ?? AppTheme.accent;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await widget.provider.updateAlbumTag(widget.tag!, name: name, color: _color);
      } else {
        await widget.provider.createAlbumTag(name, _color);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      title: Text(_isEdit ? 'Edit album tag' : 'New album tag',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tag name',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              autofocus: !_isEdit,
              maxLength: 30,
              decoration: InputDecoration(
                hintText: 'e.g. Event, Story arc, Series…',
                counterStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
              ),
              onSubmitted: (_) => _save(),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text('Colour',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    final picked = await showColorPickerDialog(context, _color, title: 'Tag colour');
                    if (picked != null) setState(() => _color = picked);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: const Icon(Icons.colorize_rounded, size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  type: MaterialType.transparency,
                  child: TagChip(
                    label: _nameCtrl.text.trim().isEmpty ? 'Preview' : _nameCtrl.text.trim(),
                    color: _color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

// ── Sort option ────────────────────────────────────────────────────

enum _SortOption {
  nameAZ, nameZA, mostUsed, leastUsed, newestFirst, oldestFirst;

  String get label => switch (this) {
    _SortOption.nameAZ      => 'Name A → Z',
    _SortOption.nameZA      => 'Name Z → A',
    _SortOption.mostUsed    => 'Most used',
    _SortOption.leastUsed   => 'Least used',
    _SortOption.newestFirst => 'Newest first',
    _SortOption.oldestFirst => 'Oldest first',
  };

  IconData get icon => switch (this) {
    _SortOption.nameAZ      => Icons.sort_by_alpha_rounded,
    _SortOption.nameZA      => Icons.sort_by_alpha_rounded,
    _SortOption.mostUsed    => Icons.bar_chart_rounded,
    _SortOption.leastUsed   => Icons.bar_chart_outlined,
    _SortOption.newestFirst => Icons.schedule_rounded,
    _SortOption.oldestFirst => Icons.history_rounded,
  };
}
