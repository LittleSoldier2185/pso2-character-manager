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
  State<CharacterDetailScreen> createState() =>
      _CharacterDetailScreenState();
}

class _CharacterDetailScreenState extends State<CharacterDetailScreen> {
  late TextEditingController _nameController;
  late List<String> _tags;
  String? _collectionId;
  String? _newThumbnailPath;
  bool _isEditing = false;
  bool _isSaving = false;
  final _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.character.name);
    _tags = List.from(widget.character.tags);
    _collectionId = widget.character.collectionId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickNewImage() async {
    final result =
        await FilePicker.platform.pickFiles(type: FileType.image);
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
      widget.character.tags = _tags;
      widget.character.collectionId = _collectionId;
      await context
          .read<CharacterProvider>()
          .updateCharacter(widget.character);
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Delete Character?'),
        content: Text(
            'This will permanently delete "${widget.character.name}" and remove '
            'the character file and thumbnail from storage.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    final collections =
        context.watch<CharacterProvider>().allCollections;
    final c = widget.character;
    final String? thumbPath = _newThumbnailPath ?? c.thumbnailPath;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editing: ${c.name}' : c.name),
        actions: [
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
            // Left: thumbnail
            Column(
              children: [
                GestureDetector(
                  onTap: _isEditing ? _pickNewImage : null,
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
                    child: thumbPath != null &&
                            File(thumbPath).existsSync()
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(File(thumbPath),
                                fit: BoxFit.cover),
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
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _badge(c.race, AppTheme.raceColor(c.race)),
                    const SizedBox(width: 8),
                    _badge(c.gender, AppTheme.accentGold),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 32),
            // Right: details / edit form
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Character Name'),
                  const SizedBox(height: 6),
                  _isEditing
                      ? TextFormField(controller: _nameController)
                      : Text(c.name,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                  const SizedBox(height: 20),
                  _label('Collection'),
                  const SizedBox(height: 6),
                  _isEditing
                      ? DropdownButtonFormField<String?>(
                          value: _collectionId,
                          dropdownColor: AppTheme.bgSurface,
                          decoration:
                              const InputDecoration(hintText: 'None'),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('None')),
                            ...collections.map((col) => DropdownMenuItem(
                                  value: col.id,
                                  child: Text(col.name),
                                )),
                          ],
                          onChanged: (v) =>
                              setState(() => _collectionId = v),
                        )
                      : Text(
                          _collectionId != null
                              ? (collections
                                      .where(
                                          (col) => col.id == _collectionId)
                                      .firstOrNull
                                      ?.name ??
                                  'Unknown')
                              : 'No collection',
                          style: const TextStyle(
                              color: AppTheme.textSecondary)),
                  const SizedBox(height: 20),
                  _label('Tags'),
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
                              foregroundColor: AppTheme.accent),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _tags
                        .map((tag) => TagChip(
                              label: tag,
                              onDeleted: _isEditing
                                  ? () =>
                                      setState(() => _tags.remove(tag))
                                  : null,
                            ))
                        .toList(),
                  ),
                  if (_tags.isEmpty)
                    const Text('No tags',
                        style:
                            TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 20),
                  _label('Character File'),
                  const SizedBox(height: 6),
                  Text(c.characterFilePath.split(r'\').last,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Added ${_formatDate(c.createdAt)}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  if (_isEditing) ...[
                    const SizedBox(height: 32),
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
                                : const Text('Save Changes'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              _isEditing = false;
                              _nameController.text =
                                  widget.character.name;
                              _tags =
                                  List.from(widget.character.tags);
                              _collectionId =
                                  widget.character.collectionId;
                              _newThumbnailPath = null;
                            }),
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

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500));

  Widget _badge(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
