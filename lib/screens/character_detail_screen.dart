import 'dart:io';
import 'dart:ui';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character.dart';
import '../models/gallery_item.dart';
import '../models/tag.dart';
import '../providers/character_provider.dart';
import '../services/hive_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tag_chip.dart';
import 'export_bundle_dialog.dart';
import 'tags_screen.dart';

class CharacterDetailScreen extends StatefulWidget {
  final Character character;
  const CharacterDetailScreen({super.key, required this.character});

  @override
  State<CharacterDetailScreen> createState() => _CharacterDetailScreenState();
}

class _CharacterDetailScreenState extends State<CharacterDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late List<String> _tags;
  late List<String> _collectionIds;
  String? _newThumbnailPath;
  bool _removeThumbnail = false;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.character.name);
    _descController = TextEditingController(text: widget.character.description);
    _tags = List.from(widget.character.tags);
    _collectionIds = List.from(widget.character.collectionIds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickNewImage() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, dialogTitle: 'Add thumbnail image');
    if (result != null && result.files.single.path != null) {
      setState(() => _newThumbnailPath = result.files.single.path);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    final provider = context.read<CharacterProvider>();
    try {
      if (_newThumbnailPath != null) {
        // Replace thumbnail — deletes old file safely
        await provider.updateCharacterThumbnail(
            widget.character, _newThumbnailPath!);
      } else if (_removeThumbnail) {
        // Remove thumbnail — deletes file from disk
        await provider.removeCharacterThumbnail(widget.character);
      }
      widget.character.name = _nameController.text.trim();
      widget.character.description = _descController.text.trim();
      widget.character.tags = _tags;
      widget.character.collectionIds = _collectionIds;
      widget.character.collectionId =
          _collectionIds.isNotEmpty ? _collectionIds.first : null;
      await provider.updateCharacter(widget.character);
      if (mounted) setState(() { _isEditing = false; _isSaving = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _nameController.text = widget.character.name;
      _descController.text = widget.character.description;
      _tags = List.from(widget.character.tags);
      _collectionIds = List.from(widget.character.collectionIds);
      _newThumbnailPath = null;
      _removeThumbnail = false;
    });
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Delete character?'),
        content: Text(
            'Permanently delete "${widget.character.name}"? '
            'The character file and thumbnail will be removed from storage.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context
                  .read<CharacterProvider>()
                  .deleteCharacter(widget.character);
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportFile() async {
    final ext = widget.character.characterFilePath.split('.').last;
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export character file',
      fileName: '${widget.character.name}.$ext',
      type: FileType.custom,
      allowedExtensions: [ext],
    );
    if (result != null && mounted) {
      final error = await context
          .read<CharacterProvider>()
          .exportCharacterFile(widget.character, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error ?? 'Exported successfully'),
          backgroundColor: error != null ? Colors.red : Colors.green,
        ));
      }
    }
  }

  void _viewFullImage(String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collections = context.watch<CharacterProvider>().allCollections;
    final c = widget.character;
    // If user flagged removal, treat as no thumb; new pick overrides removal
    final String? thumbPath = _removeThumbnail
        ? _newThumbnailPath
        : (_newThumbnailPath ?? c.thumbnailPath);
    final bool hasThumb = thumbPath != null && File(thumbPath).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editing: ${c.name}' : c.name),
        actions: [
          // Share menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'Share / Export',
            color: AppTheme.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            onSelected: (value) async {
              if (value == 'bundle') {
                await showExportBundleDialog(context, c);
              } else if (value == 'file') {
                await _exportFile();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem<String>(
                value: 'bundle',
                child: Row(
                  children: [
                    Icon(Icons.file_upload_outlined,
                        size: 15, color: AppTheme.textSecondary),
                    SizedBox(width: 8),
                    Text('Export as .pso2char bundle',
                        style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'file',
                child: Row(
                  children: [
                    Icon(Icons.save_alt_rounded,
                        size: 15, color: AppTheme.textSecondary),
                    SizedBox(width: 8),
                    Text('Export raw file only',
                        style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit',
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _confirmDelete,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left: thumbnail + apply ────────────────────────
            Column(
              children: [
                GestureDetector(
                  onTap: _isEditing
                      ? _pickNewImage
                      : (hasThumb ? () => _viewFullImage(thumbPath!) : null),
                  child: Container(
                    width: 240,
                    height: 270,
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isEditing
                            ? AppTheme.accent
                            : AppTheme.borderColor,
                      ),
                    ),
                    child: hasThumb
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.file(File(thumbPath!),
                                    fit: BoxFit.cover),
                              ),
                              if (!_isEditing)
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                        Icons.zoom_out_map_rounded,
                                        size: 14,
                                        color: Colors.white),
                                  ),
                                ),
                            ],
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_outline,
                                    size: 60,
                                    color: AppTheme.raceColor(c.race)
                                        .withOpacity(0.4)),
                                if (_isEditing) ...[
                                  const SizedBox(height: 8),
                                  const Text('Click to add image',
                                      style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12)),
                                ],
                              ],
                            ),
                          ),
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 240,
                    child: OutlinedButton.icon(
                      onPressed: _pickNewImage,
                      icon: const Icon(Icons.add, size: 14),
                      label: Text(hasThumb
                          ? 'Change thumbnail'
                          : 'Add thumbnail',
                          style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                      ),
                    ),
                  ),
                  // Show remove button only if there is a thumbnail to remove
                  if (hasThumb) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 240,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _removeThumbnail = true;
                          _newThumbnailPath = null;
                        }),
                        icon: const Icon(Icons.delete_outline,
                            size: 14, color: Colors.redAccent),
                        label: const Text('Remove thumbnail',
                            style: TextStyle(
                                fontSize: 12, color: Colors.redAccent)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Colors.redAccent, width: 0.5),
                          padding:
                              const EdgeInsets.symmetric(vertical: 7),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _badge(c.race, AppTheme.raceColor(c.race)),
                    const SizedBox(width: 8),
                    _badge(c.gender, AppTheme.accentGold),
                  ],
                ),
                const SizedBox(height: 10),
                // ── Tier picker ──────────────────────────────
                _TierPicker(character: c),
                const SizedBox(height: 10),
                // ── Apply toggle button on detail page ─────────
                SizedBox(
                  width: 240,
                  child: _DetailApplyButton(character: c),
                ),
              ],
            ),
            const SizedBox(width: 32),
            // ── Right: details / edit ──────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Character name'),
                  const SizedBox(height: 6),
                  _isEditing
                      ? TextFormField(controller: _nameController)
                      : Text(c.name,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                  const SizedBox(height: 18),

                  _fieldLabel('Description'),
                  const SizedBox(height: 6),
                  _isEditing
                      ? TextFormField(
                          controller: _descController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              hintText: 'Notes about this character…'),
                        )
                      : c.description.isEmpty
                          ? const Text('No description',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13))
                          : Text(c.description,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13)),
                  const SizedBox(height: 18),

                  _fieldLabel('Collections'),
                  const SizedBox(height: 6),
                  _isEditing
                      ? _buildCollectionPicker(collections)
                      : _buildCollectionDisplay(collections),
                  const SizedBox(height: 18),

                  _fieldLabel('Tags'),
                  const SizedBox(height: 6),
                  _buildTagSection(context),
                  const SizedBox(height: 18),

                  _fieldLabel('Character file'),
                  const SizedBox(height: 4),
                  Text(c.characterFilePath.split(r'\').last,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('Added ${_formatDate(c.createdAt)}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),

                  const SizedBox(height: 24),
                  const Divider(color: AppTheme.borderColor, height: 1),
                  const SizedBox(height: 16),

                  // ── Save / Cancel buttons (above gallery) ────────
                  if (_isEditing) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveChanges,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Text('Save changes'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _cancelEdit,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppTheme.borderColor),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(
                                    color: AppTheme.textSecondary)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Gallery section ──────────────────────────────
                  _CharacterGallery(character: c),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionPicker(List collections) {
    if (collections.isEmpty) {
      return const Text('No collections yet.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: collections.map((col) {
        final selected = _collectionIds.contains(col.id);
        return GestureDetector(
          onTap: () => setState(() {
            if (selected) {
              _collectionIds.remove(col.id);
            } else {
              _collectionIds.add(col.id);
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.accent.withOpacity(0.12)
                  : AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: selected
                      ? AppTheme.accent
                      : AppTheme.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_rounded,
                    size: 12,
                    color: selected
                        ? AppTheme.accent
                        : AppTheme.textSecondary),
                const SizedBox(width: 5),
                Text(col.name,
                    style: TextStyle(
                        color: selected
                            ? AppTheme.accent
                            : AppTheme.textSecondary,
                        fontSize: 12)),
                if (selected) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check, size: 11, color: AppTheme.accent),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCollectionDisplay(List collections) {
    if (_collectionIds.isEmpty) {
      return const Text('No collections',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _collectionIds.map((id) {
        final col =
            collections.where((c) => c.id == id).firstOrNull;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.accentGold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: AppTheme.accentGold.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_rounded,
                  size: 12, color: AppTheme.accentGold),
              const SizedBox(width: 4),
              Text(col?.name ?? 'Unknown',
                  style: const TextStyle(
                      color: AppTheme.accentGold, fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTagSection(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final allTags = provider.allTags;
    // Resolve tag IDs to Tag objects — skip any deleted/unknown IDs
    final assignedTags = _tags
        .map((id) => provider.tagById(id))
        .whereType<Tag>()
        .toList();
    // Tags not yet assigned to this character
    final unassignedTags =
        allTags.where((t) => !_tags.contains(t.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Assigned tags as chips
        if (assignedTags.isEmpty && !_isEditing)
          const Text('No tags',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13))
        else if (assignedTags.isNotEmpty)
          Material(
            type: MaterialType.transparency,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: assignedTags
                  .map((tag) => TagChip(
                        tag: tag,
                        onDeleted: _isEditing
                            ? () => setState(() => _tags.remove(tag.id))
                            : null,
                      ))
                  .toList(),
            ),
          ),

        if (_isEditing) ...[
          const SizedBox(height: 10),
          // Unassigned tags to pick from
          if (unassignedTags.isNotEmpty) ...[
            const Text('Add tag:',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: unassignedTags
                  .map((tag) => GestureDetector(
                        onTap: () =>
                            setState(() => _tags.add(tag.id)),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(
                              8, 3, 8, 3),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: tag.color.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add,
                                  size: 11,
                                  color: tag.color.withOpacity(0.7)),
                              const SizedBox(width: 3),
                              Text(tag.name,
                                  style: TextStyle(
                                      color: tag.color.withOpacity(0.7),
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ] else if (allTags.isEmpty)
            const Text('No tags yet.',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),

          const SizedBox(height: 8),
          // Manage tags shortcut
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TagsScreen()),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.label_outline_rounded,
                    size: 12, color: AppTheme.accent.withOpacity(0.8)),
                const SizedBox(width: 4),
                Text('Manage tags →',
                    style: TextStyle(
                        color: AppTheme.accent.withOpacity(0.8),
                        fontSize: 11)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _fieldLabel(String text) => Text(text,
      style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500));

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 12)),
      );

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

// ── Tier picker widget ───────────────────────────────────

class _TierPicker extends StatelessWidget {
  final Character character;
  const _TierPicker({required this.character});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final current = character.tier;

    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Tier',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              if (current != null)
                GestureDetector(
                  onTap: () => provider.setTier(character, null),
                  child: const Text('Clear',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: CharacterTier.values.map((t) {
              final selected = current == t;
              final borderColor = Color(t.colorValue);
              final bgColor = Color(t.bgColorValue);
              return GestureDetector(
                onTap: () => provider.setTier(
                    character, selected ? null : t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? bgColor : AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? borderColor : AppTheme.borderColor,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      t.label,
                      style: TextStyle(
                        color: selected
                            ? borderColor
                            : AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Apply toggle button for detail page ───────────────────────────

class _DetailApplyButton extends StatefulWidget {
  final Character character;
  const _DetailApplyButton({required this.character});

  @override
  State<_DetailApplyButton> createState() => _DetailApplyButtonState();
}

class _DetailApplyButtonState extends State<_DetailApplyButton> {
  bool _loading = false;

  Future<void> _toggle() async {
    setState(() => _loading = true);
    final error =
        await context.read<CharacterProvider>().toggleApply(widget.character);
    if (mounted) {
      setState(() => _loading = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApplied = widget.character.isApplied;
    return ElevatedButton.icon(
      onPressed: _loading ? null : _toggle,
      icon: _loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(
              isApplied
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              size: 16),
      label: Text(
        isApplied
            ? (widget.character.slotNumber != null
                ? 'Applied · Slot ${widget.character.slotNumber}'
                : 'Applied to game')
            : 'Apply to game',
        style: const TextStyle(fontSize: 12),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isApplied ? AppTheme.accent : AppTheme.bgSurface,
        foregroundColor:
            isApplied ? AppTheme.bgDark : AppTheme.textSecondary,
        padding: const EdgeInsets.symmetric(vertical: 10),
        side: BorderSide(
          color: isApplied ? AppTheme.accent : AppTheme.borderColor,
        ),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}

// ── Character gallery ─────────────────────────────────────────────

const List<String> _kImageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

bool _isImagePath(String path) {
  final ext = path.split('.').last.toLowerCase();
  return _kImageExts.contains(ext);
}

class _CharacterGallery extends StatefulWidget {
  final Character character;
  const _CharacterGallery({required this.character});

  @override
  State<_CharacterGallery> createState() => _CharacterGalleryState();
}

class _CharacterGalleryState extends State<_CharacterGallery> {
  bool _isDragOver = false;
  int _columns = 3;
  Set<String> _blurredItems = {};
  static const double _cellSpacing = 4.0;

  // Size options: label, icon, column count
  static const _sizeOptions = [
    (label: 'Extra large', icon: Icons.crop_square_rounded,      columns: 2),
    (label: 'Large',       icon: Icons.view_agenda_outlined,     columns: 3),
    (label: 'Medium',      icon: Icons.grid_on_rounded,          columns: 4),
    (label: 'Small',       icon: Icons.apps_rounded,             columns: 5),
  ];

  @override
  void initState() {
    super.initState();
    final hive = HiveService();
    _columns = hive.getGalleryColumns();
    _blurredItems = hive.getBlurredItems();
  }

  Future<void> _addFiles(List<String> paths) async {
    final provider = context.read<CharacterProvider>();
    final validPaths = paths.where(_isImagePath).toList();
    for (final path in validPaths) {
      await provider.addGalleryItem(widget.character.id, path);
    }
    if (validPaths.isEmpty && paths.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Only image files are supported (jpg, png, gif, webp)')),
      );
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kImageExts,
      allowMultiple: true,
      dialogTitle: 'Add images to gallery',
    );
    if (result != null) {
      final paths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
      await _addFiles(paths);
    }
  }

  void _viewImage(BuildContext context, List<GalleryItem> items, int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => _GalleryViewer(items: items, initialIndex: index),
    );
  }

  void _confirmDelete(GalleryItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Remove image?'),
        content: const Text(
            'This will permanently delete the image file from storage.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<CharacterProvider>().deleteGalleryItem(item);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBlur(String itemId) async {
    await HiveService().toggleBlurredItem(itemId);
    setState(() {
      if (_blurredItems.contains(itemId)) {
        _blurredItems.remove(itemId);
      } else {
        _blurredItems.add(itemId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final items = provider.getGalleryItems(widget.character.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            const Text('Gallery',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            if (items.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${items.length}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 10)),
              ),
            const Spacer(),
            // Size picker
            PopupMenuButton<int>(
              color: AppTheme.bgCard,
              tooltip: 'Image size',
              icon: Icon(
                _sizeOptions
                    .firstWhere((o) => o.columns == _columns,
                        orElse: () => _sizeOptions[1])
                    .icon,
                size: 15,
                color: AppTheme.textSecondary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              onSelected: (cols) async {
                setState(() => _columns = cols);
                await HiveService().saveGalleryColumns(cols);
              },
              itemBuilder: (_) => _sizeOptions
                  .map((opt) => PopupMenuItem<int>(
                        value: opt.columns,
                        child: Row(
                          children: [
                            Icon(opt.icon,
                                size: 15,
                                color: _columns == opt.columns
                                    ? AppTheme.accent
                                    : AppTheme.textSecondary),
                            const SizedBox(width: 10),
                            Text(opt.label,
                                style: TextStyle(
                                    color: _columns == opt.columns
                                        ? AppTheme.accent
                                        : AppTheme.textPrimary,
                                    fontSize: 13)),
                            if (_columns == opt.columns) ...[
                              const Spacer(),
                              Icon(Icons.check_rounded,
                                  size: 13, color: AppTheme.accent),
                            ],
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: 10),

        DropTarget(
          onDragDone: (details) =>
              _addFiles(details.files.map((f) => f.path).toList()),
          onDragEntered: (_) => setState(() => _isDragOver = true),
          onDragExited: (_) => setState(() => _isDragOver = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _isDragOver
                  ? AppTheme.accent.withOpacity(0.07)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isDragOver
                    ? AppTheme.accent.withOpacity(0.5)
                    : Colors.transparent,
              ),
            ),
            // LayoutBuilder so cell size is always correct
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth - 8;
                final cellSize = (availableWidth -
                        (_columns - 1) * _cellSpacing) /
                    _columns;

                // All items + the Add button at position 0
                final totalCount = items.length + 1;
                final rowCount = (totalCount / _columns).ceil();

                return Column(
                  children: List.generate(rowCount, (row) {
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: row < rowCount - 1 ? _cellSpacing : 0),
                      child: Row(
                        children: List.generate(_columns, (col) {
                          final index = row * _columns + col;
                          final isLast = col == _columns - 1;

                          Widget cell;
                          if (index == 0) {
                            // Add button — always first
                            cell = _buildAddButton(cellSize);
                          } else if (index - 1 < items.length) {
                            final item = items[index - 1];
                            final fileExists =
                                File(item.filePath).existsSync();
                            cell = _GalleryThumb(
                              item: item,
                              fileExists: fileExists,
                              size: cellSize,
                              isBlurred: _blurredItems.contains(item.id),
                              onTap: fileExists
                                  ? () => _viewImage(
                                      context, items, index - 1)
                                  : null,
                              onDelete: () => _confirmDelete(item),
                              onToggleBlur: () => _toggleBlur(item.id),
                            );
                          } else {
                            // Empty placeholder to fill the last row
                            cell = SizedBox(
                                width: cellSize, height: cellSize);
                          }

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              cell,
                              if (!isLast)
                                SizedBox(width: _cellSpacing),
                            ],
                          );
                        }),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),

        if (_isDragOver)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Drop images here',
                style: TextStyle(color: AppTheme.accent, fontSize: 11)),
          )
        else if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
                'Add images to build a gallery for this character',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ),
      ],
    );
  }

  Widget _buildAddButton(double size) {
    return GestureDetector(
      onTap: _pickFiles,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 28, color: AppTheme.accent.withOpacity(0.7)),
            const SizedBox(height: 5),
            Text('Add',
                style: TextStyle(
                    color: AppTheme.accent.withOpacity(0.8),
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ── Gallery thumbnail ───────────────────────────────────────────

class _GalleryThumb extends StatefulWidget {
  final GalleryItem item;
  final bool fileExists;
  final double size;
  final bool isBlurred;
  final VoidCallback? onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleBlur;

  const _GalleryThumb({
    required this.item,
    required this.fileExists,
    required this.size,
    required this.isBlurred,
    required this.onTap,
    required this.onDelete,
    required this.onToggleBlur,
  });

  @override
  State<_GalleryThumb> createState() => _GalleryThumbState();
}

class _GalleryThumbState extends State<_GalleryThumb> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image (with optional blur)
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: widget.fileExists
                    ? widget.isBlurred
                        ? ImageFiltered(
                            imageFilter: ImageFilter.blur(
                                sigmaX: 18, sigmaY: 18),
                            child: Image.file(
                              File(widget.item.filePath),
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          )
                        : Image.file(
                            File(widget.item.filePath),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          )
                    : const Center(
                        child: Icon(Icons.broken_image_outlined,
                            size: 24, color: AppTheme.textSecondary)),
              ),

              // Blurred overlay label
              if (widget.isBlurred)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.visibility_off_outlined,
                        size: 16, color: Colors.white),
                  ),
                ),

              // Hover controls
              if (_hovered) ...[
                // Delete button — top right
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.close,
                          size: 11, color: Colors.white),
                    ),
                  ),
                ),
                // Blur toggle button — top left
                Positioned(
                  top: 4,
                  left: 4,
                  child: GestureDetector(
                    onTap: widget.onToggleBlur,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        widget.isBlurred
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_outlined,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Zoom icon — bottom right (only when not blurred)
                if (!widget.isBlurred && widget.fileExists)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: widget.onTap,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.zoom_out_map_rounded,
                            size: 10, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Full-screen gallery viewer with swipe navigation ────────────────

class _GalleryViewer extends StatefulWidget {
  final List<GalleryItem> items;
  final int initialIndex;
  const _GalleryViewer({
    required this.items,
    required this.initialIndex,
  });

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late PageController _pageCtrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          // Page view — swipe left/right
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) {
              final item = widget.items[i];
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 6,
                child: Image.file(
                  File(item.filePath),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              );
            },
          ),
          // Close button
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
          // Counter — top left
          if (widget.items.length > 1)
            Positioned(
              top: 10,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.items.length}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          // Left arrow
          if (_currentIndex > 0)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _pageCtrl.previousPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.chevron_left_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          // Right arrow
          if (_currentIndex < widget.items.length - 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _pageCtrl.nextPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
