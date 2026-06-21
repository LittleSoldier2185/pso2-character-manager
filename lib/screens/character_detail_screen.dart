import 'dart:io';
import 'dart:ui';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';
import '../models/character_data.dart';
import '../models/gallery_data.dart';
import '../models/tag_data.dart';
import '../providers/character_provider.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_title_bar.dart';
import '../widgets/tag_chip.dart';
import '../widgets/tier_border.dart';
import 'add_variant_screen.dart';
import 'export_bundle_dialog.dart';
import 'tags_screen.dart';

class CharacterDetailScreen extends StatefulWidget {
  final CharacterData character;
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

  Future<void> _openFolder() async {
    final folder = widget.character.folderPath;
    if (Directory(folder).existsSync()) {
      await Process.run('explorer.exe', [folder]);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Folder not found')),
        );
      }
    }
  }

  Future<void> _exportFile() async {
    final ext = (widget.character.characterFilePath ?? '').split('.').last;
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
      body: Column(
        children: [
          const AppTitleBar(),
          // ── Screen header ───────────────────────────────────────
          Container(
            height: 48,
            color: AppTheme.bgCard,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded,
                      size: 18, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Back',
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: Text(
                    _isEditing ? 'Editing: ${c.name}' : c.name,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Share menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.ios_share_outlined,
                      color: AppTheme.textPrimary),
                  tooltip: 'Share / Export',
                  color: AppTheme.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: AppTheme.borderColor),
                  ),
                  onSelected: (value) async {
                    if (value == 'bundle') {
                      await showExportBundleDialog(context, c);
                    } else if (value == 'file') {
                      await _exportFile();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
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
                    PopupMenuItem<String>(
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
                IconButton(
                  icon: Icon(Icons.folder_open_outlined,
                      color: AppTheme.textPrimary),
                  onPressed: _openFolder,
                  tooltip: 'Open character folder',
                ),
                if (!_isEditing)
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        color: AppTheme.textPrimary),
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
          ),
          Divider(height: 1, color: AppTheme.borderColor),
          // ── Body ────────────────────────────────────────────────
          Expanded(child: SingleChildScrollView(
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
                                  Text('Click to add image',
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
                        side: BorderSide(color: AppTheme.borderColor),
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
                // ── Border customization ─────────────────────
                _BorderPicker(character: c),
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
                          style: TextStyle(
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
                          ? Text('No description',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13))
                          : Text(c.description,
                              style: TextStyle(
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
                  Text(c.characterFilePath?.split(r'\').last ?? '',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('Added ${_formatDate(c.createdAt)}',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),

                  const SizedBox(height: 20),

                  // ── Variants ─────────────────────────────────────
                  _VariantsSection(character: c),

                  const SizedBox(height: 24),
                  Divider(color: AppTheme.borderColor, height: 1),
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
                              side: BorderSide(
                                  color: AppTheme.borderColor),
                            ),
                            child: Text('Cancel',
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
      )),
    ],
  ),
);
  }

  Widget _buildCollectionPicker(List collections) {
    if (collections.isEmpty) {
      return Text('No collections yet.',
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
      return Text('No collections',
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
        .whereType<TagData>()
        .toList();
    // Tags not yet assigned to this character
    final unassignedTags =
        allTags.where((t) => !_tags.contains(t.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Assigned tags as chips
        if (assignedTags.isEmpty && !_isEditing)
          Text('No tags',
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
            Text('Add tag:',
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
            Text('No tags yet.',
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
      style: TextStyle(
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
  final CharacterData character;
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
              Text('Tier',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              if (current != null)
                GestureDetector(
                  onTap: () => provider.setTier(character, null),
                  child: Text('Clear',
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
              final isS = t == CharacterTier.s;
              final label = isS
                  ? RainbowText(t.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))
                  : Text(t.label, style: TextStyle(color: selected ? borderColor : AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w700));
              return GestureDetector(
                onTap: () => provider.setTier(character, selected ? null : t),
                child: isS && selected
                    ? SizedBox(
                        width: 40,
                        height: 36,
                        child: buildTierBorder(
                          effect: TierBorderEffect.rainbow,
                          color: borderColor,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(color: bgColor, child: Center(child: label)),
                          ),
                        ),
                      )
                    : AnimatedContainer(
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
                        child: Center(child: label),
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
  final CharacterData character;
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
        isApplied ? 'Applied to game' : 'Apply to game',
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
  final CharacterData character;
  const _CharacterGallery({required this.character});

  @override
  State<_CharacterGallery> createState() => _CharacterGalleryState();
}

class _CharacterGalleryState extends State<_CharacterGallery> {
  bool _isDragOver = false;
  int _columns = 3;
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
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await DataService.instance.getSettings();
    if (mounted) setState(() => _columns = s.galleryColumns);
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

  void _viewImage(BuildContext context, List<GalleryItemData> items, int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => _GalleryViewer(
          items: items,
          folderPath: widget.character.folderPath,
          initialIndex: index),
    );
  }

  void _confirmDelete(GalleryItemData item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Remove image?'),
        content: Text(
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

  Future<void> _toggleBlur(GalleryItemData item) async {
    final provider = context.read<CharacterProvider>();
    await provider.toggleGalleryItemBlur(item);
  }

  Future<void> _setAsThumbnail(GalleryItemData item) async {
    final provider = context.read<CharacterProvider>();
    await provider.updateCharacterThumbnail(
        widget.character, item.filePath(widget.character.folderPath));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Thumbnail updated'),
        duration: Duration(seconds: 2),
      ));
    }
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
            Text('Gallery',
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
                    style: TextStyle(
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
                side: BorderSide(color: AppTheme.borderColor),
              ),
              onSelected: (cols) async {
                setState(() => _columns = cols);
                await DataService.instance.saveGalleryColumns(cols);
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
                            final resolvedPath = item.filePath(
                                widget.character.folderPath);
                            final fileExists =
                                File(resolvedPath).existsSync();
                            cell = _GalleryThumb(
                              item: item,
                              filePath: resolvedPath,
                              fileExists: fileExists,
                              size: cellSize,
                              isBlurred: item.isBlurred,
                              onTap: fileExists
                                  ? () => _viewImage(
                                      context, items, index - 1)
                                  : null,
                              onDelete: () => _confirmDelete(item),
                              onToggleBlur: () => _toggleBlur(item),
                              onSetAsThumbnail: fileExists
                                  ? () => _setAsThumbnail(item)
                                  : null,
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
          Padding(
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

enum _GalleryCtxAction { copy, setThumbnail }

class _GalleryThumb extends StatefulWidget {
  final GalleryItemData item;
  final String filePath;
  final bool fileExists;
  final double size;
  final bool isBlurred;
  final VoidCallback? onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleBlur;
  final VoidCallback? onSetAsThumbnail;

  const _GalleryThumb({
    required this.item,
    required this.filePath,
    required this.fileExists,
    required this.size,
    required this.isBlurred,
    required this.onTap,
    required this.onDelete,
    required this.onToggleBlur,
    this.onSetAsThumbnail,
  });

  @override
  State<_GalleryThumb> createState() => _GalleryThumbState();
}

class _GalleryThumbState extends State<_GalleryThumb> {
  bool _hovered = false;

  Future<void> _copyToClipboard() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      await Pasteboard.writeImage(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Image copied to clipboard'),
          duration: Duration(seconds: 2),
        ));
      }
    } catch (_) {}
  }

  void _showContextMenu(BuildContext ctx, Offset pos) async {
    final size = MediaQuery.of(ctx).size;
    final result = await showMenu<_GalleryCtxAction>(
      context: ctx,
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      position: RelativeRect.fromLTRB(
          pos.dx, pos.dy, size.width - pos.dx, size.height - pos.dy),
      items: [
        PopupMenuItem(
          value: _GalleryCtxAction.copy,
          child: _menuRow(Icons.copy_rounded, 'Copy to clipboard'),
        ),
        if (widget.onSetAsThumbnail != null)
          PopupMenuItem(
            value: _GalleryCtxAction.setThumbnail,
            child: _menuRow(Icons.portrait_rounded, 'Set as thumbnail'),
          ),
      ],
    );
    if (!mounted) return;
    switch (result) {
      case _GalleryCtxAction.copy:
        await _copyToClipboard();
      case _GalleryCtxAction.setThumbnail:
        widget.onSetAsThumbnail?.call();
      case null:
        break;
    }
  }

  Widget _menuRow(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppTheme.textSecondary),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: widget.fileExists
            ? (d) => _showContextMenu(context, d.globalPosition)
            : null,
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
                              File(widget.filePath),
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          )
                        : Image.file(
                            File(widget.filePath),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          )
                    : Center(
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
  final List<GalleryItemData> items;
  final String folderPath;
  final int initialIndex;
  const _GalleryViewer({
    required this.items,
    required this.folderPath,
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
                  File(item.filePath(widget.folderPath)),
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

// ── Variants section ──────────────────────────────────────────────────

class _VariantsSection extends StatefulWidget {
  final CharacterData character;
  const _VariantsSection({required this.character});

  @override
  State<_VariantsSection> createState() => _VariantsSectionState();
}

class _VariantsSectionState extends State<_VariantsSection> {
  double _cardWidth = 100;

  // Thumbnail height + content area (taller at Medium+ because extra info shows)
  static double _rowHeight(double w) =>
      (w * 0.85).roundToDouble() + (w >= 100.0 ? 76.0 : 44.0);

  static const _sizeOptions = [
    (label: 'Small',       icon: Icons.grid_on_rounded,      width: 72.0),
    (label: 'Medium',      icon: Icons.view_module_rounded,  width: 100.0),
    (label: 'Large',       icon: Icons.view_agenda_outlined, width: 130.0),
    (label: 'Extra large', icon: Icons.crop_square_rounded,  width: 160.0),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final variants = widget.character.variants;
    final hasGameFolder = provider.gameFolderPath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Variants',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            if (variants.length > 1) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Text('${variants.length}',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 10)),
              ),
            ],
            const Spacer(),
            PopupMenuButton<double>(
              color: AppTheme.bgCard,
              tooltip: 'Card size',
              icon: Icon(
                _sizeOptions
                    .firstWhere((o) => o.width == _cardWidth,
                        orElse: () => _sizeOptions[1])
                    .icon,
                size: 15,
                color: AppTheme.textSecondary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppTheme.borderColor),
              ),
              onSelected: (w) => setState(() => _cardWidth = w),
              itemBuilder: (_) => _sizeOptions
                  .map((opt) => PopupMenuItem<double>(
                        value: opt.width,
                        child: Row(
                          children: [
                            Icon(opt.icon,
                                size: 15,
                                color: _cardWidth == opt.width
                                    ? AppTheme.accent
                                    : AppTheme.textSecondary),
                            const SizedBox(width: 10),
                            Text(opt.label,
                                style: TextStyle(
                                    color: _cardWidth == opt.width
                                        ? AppTheme.accent
                                        : AppTheme.textPrimary,
                                    fontSize: 13)),
                            if (_cardWidth == opt.width) ...[
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
        const SizedBox(height: 8),
        SizedBox(
          height: _rowHeight(_cardWidth),
          child: ReorderableListView(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              context.read<CharacterProvider>().reorderVariants(
                  widget.character, oldIndex, newIndex);
            },
            footer: Padding(
              padding: const EdgeInsets.only(left: 0),
              child: _AddVariantButton(
                width: _cardWidth,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddVariantScreen(character: widget.character),
                  ),
                ),
              ),
            ),
            children: [
              for (int i = 0; i < variants.length; i++)
                ReorderableDelayedDragStartListener(
                  key: ValueKey(variants[i].folderName),
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _VariantCard(
                      variant: variants[i],
                      character: widget.character,
                      cardWidth: _cardWidth,
                      isMain: variants[i].folderName ==
                          widget.character.mainVariant,
                      isApplied: widget.character
                          .isVariantApplied(variants[i].folderName),
                      hasGameFolder: hasGameFolder,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Variant card ──────────────────────────────────────────────────────

class _VariantCard extends StatelessWidget {
  final VariantData variant;
  final CharacterData character;
  final bool isMain;
  final bool isApplied;
  final bool hasGameFolder;
  final double cardWidth;

  const _VariantCard({
    required this.variant,
    required this.character,
    required this.cardWidth,
    required this.isMain,
    required this.isApplied,
    required this.hasGameFolder,
  });

  void _showRenameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: variant.displayName);
    showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Rename variant'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Variant name'),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) Navigator.pop(context, name);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    ).then((name) {
      if (name != null && context.mounted) {
        context.read<CharacterProvider>().renameVariant(character, variant, name);
      }
    });
  }

  Future<void> _apply(BuildContext context) async {
    final error = await context
        .read<CharacterProvider>()
        .applyVariant(character, variant.folderName);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red));
    }
  }

  Future<void> _unapply(BuildContext context) async {
    await context
        .read<CharacterProvider>()
        .unapplyVariant(character, variant.folderName);
  }

  Future<void> _changeThumbnail(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: 'Select thumbnail for ${variant.displayName}',
    );
    if (result != null &&
        result.files.single.path != null &&
        context.mounted) {
      await context.read<CharacterProvider>().setVariantThumbnail(
          character, variant, result.files.single.path!);
    }
  }

  Future<void> _exportBundle(BuildContext context) async {
    final safeName = variant.displayName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export variant as bundle',
      fileName: '${character.name}_$safeName.pso2char',
      type: FileType.custom,
      allowedExtensions: ['pso2char'],
    );
    if (result != null && context.mounted) {
      final error = await context
          .read<CharacterProvider>()
          .exportVariantBundle(character, variant, result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error ?? 'Exported successfully'),
          backgroundColor: error != null ? Colors.red : Colors.green,
        ));
      }
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Delete variant?'),
        content: Text(
          'Permanently delete "${variant.displayName}"? '
          'All files in this variant folder will be removed.',
          style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final error = await context
                  .read<CharacterProvider>()
                  .deleteVariant(character, variant);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(error),
                  backgroundColor: Colors.red,
                ));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatSyncDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final thumbPath = character.thumbnailForVariant(variant.folderName);
    final thumbFile = thumbPath != null ? File(thumbPath) : null;
    final hasThumb = thumbFile != null && thumbFile.existsSync();
    final thumbHeight = (cardWidth * 0.85).roundToDouble();
    final showDetails = cardWidth >= 100.0;

    return PopupMenuButton<_VariantAction>(
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      onSelected: (action) async {
        switch (action) {
          case _VariantAction.rename:
            _showRenameDialog(context);
          case _VariantAction.changeThumbnail:
            await _changeThumbnail(context);
          case _VariantAction.duplicate:
            await context
                .read<CharacterProvider>()
                .duplicateVariant(character, variant);
          case _VariantAction.setMain:
            await context
                .read<CharacterProvider>()
                .setMainVariant(character, variant.folderName);
          case _VariantAction.apply:
            await _apply(context);
          case _VariantAction.unapply:
            await _unapply(context);
          case _VariantAction.exportBundle:
            await _exportBundle(context);
          case _VariantAction.delete:
            _confirmDelete(context);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _VariantAction.rename,
          child: _MenuRow(Icons.edit_outlined, 'Rename'),
        ),
        const PopupMenuItem(
          value: _VariantAction.changeThumbnail,
          child: _MenuRow(Icons.image_outlined, 'Change thumbnail'),
        ),
        const PopupMenuItem(
          value: _VariantAction.duplicate,
          child: _MenuRow(Icons.copy_outlined, 'Duplicate'),
        ),
        const PopupMenuDivider(),
        if (!isMain)
          const PopupMenuItem(
            value: _VariantAction.setMain,
            child: _MenuRow(Icons.star_outline_rounded, 'Set as main'),
          ),
        if (hasGameFolder && !isApplied)
          const PopupMenuItem(
            value: _VariantAction.apply,
            child: _MenuRow(Icons.upload_rounded, 'Apply to game'),
          ),
        if (isApplied)
          const PopupMenuItem(
            value: _VariantAction.unapply,
            child: _MenuRow(Icons.eject_rounded, 'Unapply'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _VariantAction.exportBundle,
          child: _MenuRow(Icons.file_upload_outlined, 'Export as bundle'),
        ),
        const PopupMenuItem(
          value: _VariantAction.delete,
          child: _MenuRow(Icons.delete_outline, 'Delete',
              color: Colors.redAccent),
        ),
      ],
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isMain
                ? AppTheme.accent.withValues(alpha: 0.6)
                : AppTheme.borderColor,
            width: isMain ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
              child: SizedBox(
                width: cardWidth,
                height: thumbHeight,
                child: hasThumb
                    ? Image.file(thumbFile!, fit: BoxFit.cover)
                    : Container(
                        color: AppTheme.bgCard,
                        child: Icon(Icons.person_outline_rounded,
                            size: 26, color: AppTheme.borderColor),
                      ),
              ),
            ),
            // Name + badges + optional detail info
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 5),
              child: Column(
                children: [
                  Text(
                    variant.displayName,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isMain)
                        _badge('Main', AppTheme.accent),
                      if (isApplied) ...[
                        if (isMain) const SizedBox(width: 3),
                        _badge('On', AppTheme.accentGold),
                      ],
                    ],
                  ),
                  if (showDetails) ...[
                    const SizedBox(height: 5),
                    if (variant.originalFileName != null)
                      Text(
                        variant.originalFileName!,
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 8),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    if (variant.lastSyncedAt != null)
                      Text(
                        _formatSyncDate(variant.lastSyncedAt!),
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 8),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 8, fontWeight: FontWeight.w600)),
      );
}

enum _VariantAction {
  rename,
  changeThumbnail,
  duplicate,
  setMain,
  apply,
  unapply,
  exportBundle,
  delete,
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuRow(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: c, fontSize: 13)),
      ],
    );
  }
}

// ── Add variant button ────────────────────────────────────────────────

class _AddVariantButton extends StatelessWidget {
  final VoidCallback onTap;
  final double width;
  const _AddVariantButton({required this.onTap, this.width = 100});

  @override
  Widget build(BuildContext context) {
    final height = (width * 0.85).roundToDouble() + (width >= 100.0 ? 62.0 : 40.0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppTheme.borderColor,
              width: 1,
              style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 22, color: AppTheme.textSecondary),
            SizedBox(height: 4),
            Text('Add',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Border picker ─────────────────────────────────────────────────

class _BorderPicker extends StatelessWidget {
  final CharacterData character;
  const _BorderPicker({required this.character});

  // Effects that have hardcoded colors — color picker disabled when these are active
  static const _noColorEffects = {
    TierBorderEffect.rainbow,
    TierBorderEffect.auroraPulse,
    TierBorderEffect.prismaticSparkle,
    TierBorderEffect.holographic,
  };

  static const _presetColors = [
    Color(0xFFFFFFFF), // white
    Color(0xFFFFD700), // gold
    Color(0xFFC0C0C0), // silver
    Color(0xFFFF4444), // red
    Color(0xFFFF8C00), // orange
    Color(0xFF44DDAA), // teal
    Color(0xFF4488FF), // blue
    Color(0xFFCC44FF), // purple
    Color(0xFFFF44AA), // pink
  ];

  bool get _isCustom =>
      character.customBorderEffect != null || character.customBorderColor != null;

  TierBorderEffect get _currentEffect {
    if (character.customBorderEffect != null) {
      return TierBorderEffect.values.firstWhere(
        (e) => e.name == character.customBorderEffect,
        orElse: () => TierBorderEffect.shimmer,
      );
    }
    final t = character.tier;
    return t != null ? AppTheme.effectForTier(t) : TierBorderEffect.shimmer;
  }

  Color get _currentColor {
    if (character.customBorderColor != null) {
      return Color(character.customBorderColor!);
    }
    final t = character.tier;
    return t != null ? Color(t.colorValue) : AppTheme.accent;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CharacterProvider>();

    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Border',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),

          // ── Mode toggle ────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: 'Use tier',
                  selected: !_isCustom,
                  onTap: () => provider.setCustomBorder(character),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ModeChip(
                  label: 'Custom',
                  selected: _isCustom,
                  onTap: () {
                    if (!_isCustom) {
                      provider.setCustomBorder(character,
                          effect: _currentEffect.name,
                          color: _currentColor.toARGB32());
                    }
                  },
                ),
              ),
            ],
          ),

          if (_isCustom) ...[
            const SizedBox(height: 10),

            // ── Effect dropdown ────────────────────────────────
            Text('Effect',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: DropdownButton<TierBorderEffect>(
                value: _currentEffect,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                dropdownColor: AppTheme.bgCard,
                style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 12),
                icon: Icon(Icons.expand_more_rounded,
                    color: AppTheme.textSecondary, size: 16),
                items: TierBorderEffect.values
                    .map((fx) => DropdownMenuItem(
                          value: fx,
                          child: Text(fx.displayName),
                        ))
                    .toList(),
                onChanged: (fx) {
                  if (fx == null) return;
                  final clearColor = _noColorEffects.contains(fx);
                  provider.setCustomBorder(character,
                      effect: fx.name,
                      color: clearColor ? null : character.customBorderColor);
                },
              ),
            ),

            const SizedBox(height: 10),

            // ── Color swatches ─────────────────────────────────
            Opacity(
              opacity: _noColorEffects.contains(_currentEffect) ? 0.35 : 1.0,
              child: IgnorePointer(
                ignoring: _noColorEffects.contains(_currentEffect),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Text('Color',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._presetColors.map((c) {
                  final selected = character.customBorderColor != null &&
                      Color(character.customBorderColor!) == c;
                  return GestureDetector(
                    onTap: () => provider.setCustomBorder(character,
                        effect: character.customBorderEffect,
                        color: c.toARGB32()),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppTheme.accent
                              : AppTheme.borderColor,
                          width: selected ? 2 : 1,
                        ),
                      ),
                    ),
                  );
                }),
                // No color (use tier/default) — clears both overrides
                GestureDetector(
                  onTap: () => provider.setCustomBorder(character),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.bgSurface,
                      border: Border.all(
                        color: character.customBorderColor == null
                            ? AppTheme.accent
                            : AppTheme.borderColor,
                        width: character.customBorderColor == null ? 2 : 1,
                      ),
                    ),
                    child: CustomPaint(painter: _CrossPainter(
                        color: AppTheme.textSecondary)),
                  ),
                ),
                // Custom color wheel
                GestureDetector(
                  onTap: () async {
                    final picked = await showColorPickerDialog(
                      context,
                      _currentColor,
                      title: 'Border color',
                    );
                    if (picked != null && context.mounted) {
                      provider.setCustomBorder(character,
                          effect: character.customBorderEffect,
                          color: picked.toARGB32());
                    }
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.borderColor),
                      gradient: const SweepGradient(colors: [
                        Color(0xFFFF0000), Color(0xFFFFFF00),
                        Color(0xFF00FF00), Color(0xFF00FFFF),
                        Color(0xFF0000FF), Color(0xFFFF00FF),
                        Color(0xFFFF0000),
                      ]),
                    ),
                    child: Center(
                      child: Icon(Icons.add,
                          size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accent.withOpacity(0.12)
              : AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppTheme.accent : AppTheme.textSecondary,
              fontSize: 11,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  final Color color;
  const _CrossPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const pad = 5.0;
    canvas.drawLine(Offset(pad, pad),
        Offset(size.width - pad, size.height - pad), paint);
    canvas.drawLine(Offset(size.width - pad, pad),
        Offset(pad, size.height - pad), paint);
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.color != color;
}

