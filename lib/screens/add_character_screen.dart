import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/character.dart';
import '../providers/character_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/tag_chip.dart';

class AddCharacterScreen extends StatefulWidget {
  /// Pre-fill a file path when opening from the scan result screen.
  final String? prefilledFilePath;

  const AddCharacterScreen({super.key, this.prefilledFilePath});

  @override
  State<AddCharacterScreen> createState() => _AddCharacterScreenState();
}

class _AddCharacterScreenState extends State<AddCharacterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tagController = TextEditingController();
  final _descController = TextEditingController();

  String? _selectedCharFilePath;
  String? _selectedImagePath;
  String? _detectedRace;
  String? _detectedGender;
  final List<String> _selectedCollectionIds = [];
  final List<String> _tags = [];
  bool _isSaving = false;
  bool _isDraggingFile = false;
  bool _isDraggingImage = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledFilePath != null) {
      _setCharFile(widget.prefilledFilePath!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _setCharFile(String path) {
    if (!Character.isValidExtension(path)) return;
    final raceGender = Character.detectRaceGender(path);
    setState(() {
      _selectedCharFilePath = path;
      _detectedRace = raceGender['race'];
      _detectedGender = raceGender['gender'];
    });
  }

  Future<void> _pickCharacterFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: Character.validExtensions,
      dialogTitle: 'Add Character File',
    );
    if (result != null && result.files.single.path != null) {
      _setCharFile(result.files.single.path!);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: 'Add Thumbnail Image',
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedImagePath = result.files.single.path);
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() { _tags.add(tag); _tagController.clear(); });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCharFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a character file first'),
            backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await context.read<CharacterProvider>().addCharacter(
            name: _nameController.text.trim(),
            sourceFilePath: _selectedCharFilePath!,
            sourceThumbnailPath: _selectedImagePath,
            tags: _tags,
            collectionIds: _selectedCollectionIds,
            description: _descController.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collections = context.watch<CharacterProvider>().allCollections;
    return Scaffold(
      appBar: AppBar(title: const Text('Add character')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: thumbnail + char file ────────────────────
              SizedBox(
                width: 210,
                child: Column(
                  children: [
                    // Thumbnail drop zone
                    DropTarget(
                      onDragEntered: (_) => setState(() => _isDraggingImage = true),
                      onDragExited: (_) => setState(() => _isDraggingImage = false),
                      onDragDone: (details) {
                        setState(() => _isDraggingImage = false);
                        final dropped = details.files.firstOrNull;
                        if (dropped != null) {
                          final ext = dropped.path.split('.').last.toLowerCase();
                          if (['jpg','jpeg','png','gif','webp','bmp'].contains(ext)) {
                            setState(() => _selectedImagePath = dropped.path);
                          }
                        }
                      },
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 210,
                          height: 230,
                          decoration: BoxDecoration(
                            color: _isDraggingImage
                                ? AppTheme.accent.withOpacity(0.08)
                                : AppTheme.bgSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isDraggingImage
                                  ? AppTheme.accent
                                  : AppTheme.borderColor,
                              width: _isDraggingImage ? 2 : 1.5,
                            ),
                          ),
                          child: _selectedImagePath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.file(
                                      File(_selectedImagePath!), fit: BoxFit.cover),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined,
                                        size: 36,
                                        color: AppTheme.textSecondary.withOpacity(0.5)),
                                    const SizedBox(height: 8),
                                    const Text('Drop image here',
                                        style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12)),
                                    const Text('or click to browse',
                                        style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image_outlined, size: 15),
                        label: Text(_selectedImagePath == null
                            ? 'Add thumbnail'
                            : 'Change thumbnail'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: AppTheme.borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Character file drop zone
                    DropTarget(
                      onDragEntered: (_) => setState(() => _isDraggingFile = true),
                      onDragExited: (_) => setState(() => _isDraggingFile = false),
                      onDragDone: (details) {
                        setState(() => _isDraggingFile = false);
                        final dropped = details.files.firstOrNull;
                        if (dropped != null) _setCharFile(dropped.path);
                      },
                      child: GestureDetector(
                        onTap: _pickCharacterFile,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _isDraggingFile
                                ? AppTheme.accent.withOpacity(0.08)
                                : AppTheme.bgSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _selectedCharFilePath != null
                                  ? AppTheme.accent
                                  : _isDraggingFile
                                      ? AppTheme.accent
                                      : AppTheme.borderColor,
                              width: _isDraggingFile ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _selectedCharFilePath != null
                                    ? Icons.check_circle_outline
                                    : Icons.upload_file_outlined,
                                size: 28,
                                color: _selectedCharFilePath != null
                                    ? AppTheme.accent
                                    : AppTheme.textSecondary.withOpacity(0.5),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selectedCharFilePath != null
                                    ? _selectedCharFilePath!.split(r'\').last
                                    : 'Drop .fhp .mhp .fnp…\nor click to browse',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _selectedCharFilePath != null
                                      ? AppTheme.textPrimary
                                      : AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickCharacterFile,
                        icon: const Icon(Icons.add, size: 15),
                        label: Text(_selectedCharFilePath == null
                            ? 'Add character file'
                            : 'Change file'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: AppTheme.borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    // Race / Gender badge
                    if (_detectedRace != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _badge(_detectedRace!,
                              AppTheme.raceColor(_detectedRace!)),
                          const SizedBox(width: 6),
                          _badge(_detectedGender!, AppTheme.accentGold),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 28),
              // ── Right: form fields ─────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Character name *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                          hintText: 'Enter a name for this character'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    _label('Description (optional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          hintText: 'Notes about this character, style, build…'),
                    ),
                    const SizedBox(height: 18),
                    _label('Collections (optional)'),
                    const SizedBox(height: 6),
                    _buildCollectionPicker(collections),
                    const SizedBox(height: 18),
                    _label('Tags (optional)'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _tagController,
                            decoration: const InputDecoration(
                                hintText: 'Type a tag and press Add'),
                            onFieldSubmitted: (_) => _addTag(),
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
                    if (_tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _tags
                            .map((tag) => TagChip(
                                  label: tag,
                                  onDeleted: () =>
                                      setState(() => _tags.remove(tag)),
                                ))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Save character',
                                style: TextStyle(fontSize: 15)),
                      ),
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

  Widget _buildCollectionPicker(List collections) {
    if (collections.isEmpty) {
      return Text('No collections yet — create one in the Collections tab.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: collections.map((col) {
        final selected = _selectedCollectionIds.contains(col.id);
        return GestureDetector(
          onTap: () => setState(() {
            if (selected) {
              _selectedCollectionIds.remove(col.id);
            } else {
              _selectedCollectionIds.add(col.id);
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.accent.withOpacity(0.12)
                  : AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: selected ? AppTheme.accent : AppTheme.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_rounded,
                    size: 12,
                    color: selected ? AppTheme.accent : AppTheme.textSecondary),
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

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500));

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 11)),
      );
}
