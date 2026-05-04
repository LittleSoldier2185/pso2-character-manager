import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/character.dart';
import '../providers/character_provider.dart';
import '../services/file_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tag_chip.dart';

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
  bool _isEditing = false;
  bool _isSaving = false;
  final _tagController = TextEditingController();

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
    _tagController.dispose();
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
    try {
      if (_newThumbnailPath != null) {
        if (widget.character.thumbnailPath != null) {
          await FileService.deleteFile(widget.character.thumbnailPath!);
        }
        widget.character.thumbnailPath =
            await FileService.copyThumbnailFile(_newThumbnailPath!);
      }
      widget.character.name = _nameController.text.trim();
      widget.character.description = _descController.text.trim();
      widget.character.tags = _tags;
      widget.character.collectionIds = _collectionIds;
      widget.character.collectionId =
          _collectionIds.isNotEmpty ? _collectionIds.first : null;
      await context.read<CharacterProvider>().updateCharacter(widget.character);
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
    final String? thumbPath = _newThumbnailPath ?? c.thumbnailPath;
    final bool hasThumb = thumbPath != null && File(thumbPath).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editing: ${c.name}' : c.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'Export character file',
            onPressed: _exportFile,
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
                  if (_isEditing) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tagController,
                            decoration: const InputDecoration(
                                hintText: 'Add a tag'),
                            onSubmitted: (_) => _addTag(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addTag,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.bgSurface,
                              foregroundColor: AppTheme.accent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14)),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  _tags.isEmpty
                      ? const Text('No tags',
                          style: TextStyle(color: AppTheme.textSecondary))
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _tags
                              .map((tag) => TagChip(
                                    label: tag,
                                    onDeleted: _isEditing
                                        ? () => setState(
                                            () => _tags.remove(tag))
                                        : null,
                                  ))
                              .toList(),
                        ),
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

                  if (_isEditing) ...[
                    const SizedBox(height: 28),
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
                  ],
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

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() { _tags.add(tag); _tagController.clear(); });
    }
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
