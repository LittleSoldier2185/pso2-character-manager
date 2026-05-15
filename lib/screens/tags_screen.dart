import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tag.dart';
import '../providers/character_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/tag_chip.dart';

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  String _search = '';
  _TagSortOption _sort = _TagSortOption.nameAZ;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        var tags = provider.allTags;
        // Apply search
        if (_search.isNotEmpty) {
          tags = tags
              .where((t) =>
                  t.name.toLowerCase().contains(_search.toLowerCase()))
              .toList();
        }
        // Apply sort
        tags = List.from(tags);
        switch (_sort) {
          case _TagSortOption.nameAZ:
            tags.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          case _TagSortOption.nameZA:
            tags.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
          case _TagSortOption.mostUsed:
            tags.sort((a, b) => provider.tagUsageCount(b.id).compareTo(provider.tagUsageCount(a.id)));
          case _TagSortOption.leastUsed:
            tags.sort((a, b) => provider.tagUsageCount(a.id).compareTo(provider.tagUsageCount(b.id)));
          case _TagSortOption.newestFirst:
            tags.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          case _TagSortOption.oldestFirst:
            tags.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        }

        Widget body = Column(
          children: [
            // ── Top bar ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
              decoration: const BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  if (canPop) ...[
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded,
                          size: 18, color: AppTheme.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Icon(Icons.label_rounded,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    _search.isNotEmpty
                        ? '${tags.length} of ${provider.allTags.length} tags'
                        : provider.allTags.isEmpty
                            ? 'Tags'
                            : '${provider.allTags.length} tag${provider.allTags.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 16),
                  // ── Search field ────────────────────────────
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search tags…',
                        prefixIcon: const Icon(Icons.search_rounded,
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
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // ── Sort button ─────────────────────────────
                  PopupMenuButton<_TagSortOption>(
                    color: AppTheme.bgCard,
                    tooltip: 'Sort tags',
                    icon: Icon(
                      _sort.icon,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppTheme.borderColor),
                    ),
                    onSelected: (opt) => setState(() => _sort = opt),
                    itemBuilder: (_) => _TagSortOption.values
                        .map((opt) => PopupMenuItem<_TagSortOption>(
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

            // ── Content ──────────────────────────────────────────
            Expanded(
              child: tags.isEmpty
                  ? _search.isNotEmpty
                      ? _buildNoResults()
                      : _buildEmpty(context, provider)
                  : _buildGrid(context, provider, tags),
            ),
          ],
        );

        // When pushed as a route, wrap in Scaffold for proper Material context
        return canPop
            ? Scaffold(backgroundColor: AppTheme.bgDark, body: body)
            : body;
      },
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 48,
              color: AppTheme.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No tags match "$_search"',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _search = ''),
            child: const Text('Clear search'),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
      BuildContext context, CharacterProvider provider, List<Tag> tags) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stats row ──────────────────────────────────────────
          Row(
            children: [
              _StatCard(
                label: 'Total tags',
                value: '${tags.length}',
                icon: Icons.label_rounded,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'In use',
                value:
                    '${tags.where((t) => provider.tagUsageCount(t.id) > 0).length}',
                icon: Icons.link_rounded,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Unused',
                value:
                    '${tags.where((t) => provider.tagUsageCount(t.id) == 0).length}',
                icon: Icons.link_off_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Tag cards grid ─────────────────────────────────────
          LayoutBuilder(builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 700 ? 3 : 2;
            final itemWidth = (constraints.maxWidth - (cols - 1) * 12) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: tags
                  .map((tag) => SizedBox(
                        width: itemWidth,
                        child: _TagCard(
                          tag: tag,
                          usageCount: provider.tagUsageCount(tag.id),
                          onEdit: () =>
                              _showTagDialog(context, provider, tag: tag),
                          onDelete: () =>
                              _confirmDelete(context, provider, tag),
                        ),
                      ))
                  .toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, CharacterProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Icon(Icons.label_outline_rounded,
                size: 36, color: AppTheme.textSecondary.withOpacity(0.4)),
          ),
          const SizedBox(height: 20),
          const Text('No tags yet',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          const Text('Create tags to organise your characters.',
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
  }

  void _showTagDialog(
    BuildContext context,
    CharacterProvider provider, {
    Tag? tag,
  }) {
    showDialog(
      context: context,
      builder: (_) => _TagDialog(tag: tag, provider: provider),
    );
  }

  void _confirmDelete(
    BuildContext context,
    CharacterProvider provider,
    Tag tag,
  ) {
    final count = provider.tagUsageCount(tag.id);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Delete tag?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: tag.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text('"${tag.name}"',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              count > 0
                  ? 'This tag is used by $count character${count == 1 ? '' : 's'}. '
                      'It will be removed from all of them.'
                  : 'This tag is not used by any characters.',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await provider.deleteTag(tag);
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

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.accent.withOpacity(0.7)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                Text(label,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tag card ───────────────────────────────────────────────────────

class _TagCard extends StatefulWidget {
  final Tag tag;
  final int usageCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TagCard({
    required this.tag,
    required this.usageCount,
    required this.onEdit,
    required this.onDelete,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered ? color.withOpacity(0.06) : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered ? color.withOpacity(0.5) : AppTheme.borderColor,
            width: _hovered ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colour strip at top
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row + action buttons
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tag.name,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onEdit,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.edit_outlined,
                              size: 14,
                              color: _hovered
                                  ? AppTheme.textSecondary
                                  : AppTheme.textSecondary.withOpacity(0.4)),
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
                                  : Colors.redAccent.withOpacity(0.3)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Chip preview
                  Material(
                    type: MaterialType.transparency,
                    child: TagChip(tag: tag),
                  ),
                  const SizedBox(height: 10),
                  // Usage count
                  Row(
                    children: [
                      Icon(
                        widget.usageCount > 0
                            ? Icons.person_rounded
                            : Icons.person_outline_rounded,
                        size: 12,
                        color: widget.usageCount > 0
                            ? color.withOpacity(0.8)
                            : AppTheme.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.usageCount > 0
                            ? '${widget.usageCount} character${widget.usageCount == 1 ? '' : 's'}'
                            : 'Unused',
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.usageCount > 0
                              ? color.withOpacity(0.8)
                              : AppTheme.textSecondary.withOpacity(0.5),
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
    );
  }
}

// ── Create / edit tag dialog ───────────────────────────────────────

class _TagDialog extends StatefulWidget {
  final Tag? tag;
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

  Future<void> _pickColor() async {
    final picked = await showColorPickerDialog(
      context,
      _color,
      title: 'Tag colour',
    );
    if (picked != null) setState(() => _color = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await widget.provider.updateTag(widget.tag!, name: name, color: _color);
      } else {
        await widget.provider.createTag(name, _color);
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
      title: Text(_isEdit ? 'Edit tag' : 'New tag',
          style:
              const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tag name',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              autofocus: !_isEdit,
              maxLength: 30,
              decoration: const InputDecoration(
                hintText: 'e.g. Favourite, Battle, Casual…',
                counterStyle:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 10),
              ),
              onSubmitted: (_) => _save(),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            const Text('Colour',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: _pickColor,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: const Icon(Icons.colorize_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _pickColor,
                  icon: const Icon(Icons.palette_outlined, size: 14),
                  label: const Text('Open colour wheel',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.borderColor),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Preview',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Material(
              type: MaterialType.transparency,
              child: TagChip(
                label: _nameCtrl.text.trim().isEmpty
                    ? 'Tag name'
                    : _nameCtrl.text.trim(),
                color: _color,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.bgDark))
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

// ── Tag sort option ───────────────────────────────────────────────

enum _TagSortOption {
  nameAZ,
  nameZA,
  mostUsed,
  leastUsed,
  newestFirst,
  oldestFirst;

  String get label {
    switch (this) {
      case _TagSortOption.nameAZ:      return 'Name A → Z';
      case _TagSortOption.nameZA:      return 'Name Z → A';
      case _TagSortOption.mostUsed:    return 'Most used';
      case _TagSortOption.leastUsed:   return 'Least used';
      case _TagSortOption.newestFirst: return 'Newest first';
      case _TagSortOption.oldestFirst: return 'Oldest first';
    }
  }

  IconData get icon {
    switch (this) {
      case _TagSortOption.nameAZ:      return Icons.sort_by_alpha_rounded;
      case _TagSortOption.nameZA:      return Icons.sort_by_alpha_rounded;
      case _TagSortOption.mostUsed:    return Icons.bar_chart_rounded;
      case _TagSortOption.leastUsed:   return Icons.bar_chart_outlined;
      case _TagSortOption.newestFirst: return Icons.schedule_rounded;
      case _TagSortOption.oldestFirst: return Icons.history_rounded;
    }
  }
}
