import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../models/character_data.dart';
import '../providers/character_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/tag_chip.dart';

class AddCharacterScreen extends StatefulWidget {
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
  bool _nameWasAutoFilled = false;
  CharacterData? _targetCharacter; // if set, save as variant of this character

  // Conflict resolution state
  // null = no conflict, non-null = user chose custom storage name
  String? _customStorageName;
  // true = replace existing, false/null = save with new name
  bool _replaceExisting = false;
  String? _conflictingCharName;

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
    if (!CharacterData.isValidExtension(path)) return;
    final raceGender = CharacterData.detectRaceGender(path);
    if (_nameController.text.isEmpty || _nameWasAutoFilled) {
      _nameController.text = p.basenameWithoutExtension(path);
      _nameWasAutoFilled = true;
    }
    setState(() {
      _selectedCharFilePath = path;
      _detectedRace = raceGender['race'];
      _detectedGender = raceGender['gender'];
      // Reset conflict state when a new file is selected
      _customStorageName = null;
      _replaceExisting = false;
      _conflictingCharName = null;
    });
  }

  Future<void> _pickCharacterFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: CharacterData.validExtensions,
      dialogTitle: 'Add Character File',
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      _setCharFile(path);
      if (_targetCharacter == null) await _checkConflict(path);
    }
  }

  Future<void> _checkConflict(String filePath) async {
    final provider = context.read<CharacterProvider>();
    String? conflictName;
    try {
      conflictName = await provider.checkFileConflict(filePath);
    } catch (_) {
      conflictName = null;
    }
    if (conflictName != null && mounted) {
      setState(() => _conflictingCharName = conflictName);
      await _showConflictDialog(filePath, conflictName);
    }
  }

  Future<void> _showConflictDialog(
      String filePath, String conflictingCharName) async {
    final ext = p.extension(filePath); // e.g. ".fhp"
    final originalName = p.basenameWithoutExtension(filePath); // e.g. "3001"
    final renameController =
        TextEditingController(text: '${originalName}_copy');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final previewName = '${renameController.text.trim()}$ext';
          final isRenameEmpty = renameController.text.trim().isEmpty;
          return AlertDialog(
            backgroundColor: AppTheme.bgCard,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.warning_amber_rounded,
                      color: AppTheme.accentGold, size: 16),
                ),
                const SizedBox(width: 10),
                const Text('Filename already exists'),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Conflict info box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                        children: [
                          TextSpan(
                            text: p.basename(filePath),
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500),
                          ),
                          const TextSpan(text: ' is already registered as '),
                          TextSpan(
                            text: '"$conflictingCharName"',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500),
                          ),
                          const TextSpan(
                              text:
                                  ' in your library. Saving with the same name would overwrite it.'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Rename this file to save as a new entry:',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  // Rename input + extension label
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: renameController,
                          onChanged: (_) => setSt(() {}),
                          decoration: InputDecoration(
                            hintText: '${originalName}_copy',
                            errorText: isRenameEmpty ? 'Name required' : null,
                          ),
                          style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Text(ext,
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Will be saved as: $previewName',
                    style: TextStyle(
                        color: AppTheme.accent.withOpacity(0.8),
                        fontSize: 11),
                  ),
                ],
              ),
            ),
            actions: [
              // Cancel
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedCharFilePath = null;
                    _detectedRace = null;
                    _detectedGender = null;
                    _conflictingCharName = null;
                    _customStorageName = null;
                    _replaceExisting = false;
                  });
                },
                child: const Text('Cancel'),
              ),
              // Replace existing
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _replaceExisting = true;
                    _customStorageName = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text('Replace existing'),
              ),
              // Save with new name
              ElevatedButton(
                onPressed: isRenameEmpty
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        setState(() {
                          _customStorageName = renameController.text.trim();
                          _replaceExisting = false;
                        });
                      },
                child: const Text('Save with new name'),
              ),
            ],
          );
        },
      ),
    );
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
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCharFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add a character file first'),
            backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final provider = context.read<CharacterProvider>();

      if (_targetCharacter != null) {
        await provider.addVariant(
          character: _targetCharacter!,
          displayName: _nameController.text.trim(),
          sourceFilePath: _selectedCharFilePath!,
          sourceThumbnailPath: _selectedImagePath,
        );
      } else if (_replaceExisting && _conflictingCharName != null) {
        final existing = provider.allCharacters.firstWhere(
          (c) => c.name == _conflictingCharName,
          orElse: () => throw StateError('not found'),
        );
        await provider.replaceCharacterFile(existing, _selectedCharFilePath!);
        await provider.addCharacter(
          name: _nameController.text.trim(),
          sourceFilePath: _selectedCharFilePath!,
          sourceThumbnailPath: _selectedImagePath,
          tags: _tags,
          collectionIds: _selectedCollectionIds,
          description: _descController.text.trim(),
        );
      } else {
        await provider.addCharacter(
          name: _nameController.text.trim(),
          sourceFilePath: _selectedCharFilePath!,
          sourceThumbnailPath: _selectedImagePath,
          tags: _tags,
          collectionIds: _selectedCollectionIds,
          description: _descController.text.trim(),
          customStorageName: _customStorageName,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider    = context.watch<CharacterProvider>();
    final collections = provider.allCollections;
    final characters  = provider.allCharacters;

    return Scaffold(
      appBar: AppBar(title: const Text('Add character')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: thumbnail + char file ──────────────────
              SizedBox(
                width: 210,
                child: Column(
                  children: [
                    DropTarget(
                      onDragEntered: (_) =>
                          setState(() => _isDraggingImage = true),
                      onDragExited: (_) =>
                          setState(() => _isDraggingImage = false),
                      onDragDone: (details) {
                        setState(() => _isDraggingImage = false);
                        final dropped = details.files.firstOrNull;
                        if (dropped != null) {
                          final ext =
                              dropped.path.split('.').last.toLowerCase();
                          if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']
                              .contains(ext)) {
                            setState(
                                () => _selectedImagePath = dropped.path);
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
                                      File(_selectedImagePath!),
                                      fit: BoxFit.cover),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 36,
                                        color: AppTheme.textSecondary
                                            .withOpacity(0.5)),
                                    const SizedBox(height: 8),
                                    Text('Drop image here',
                                        style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12)),
                                    Text('or click to browse',
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
                          side: BorderSide(
                              color: AppTheme.borderColor),
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropTarget(
                      onDragEntered: (_) =>
                          setState(() => _isDraggingFile = true),
                      onDragExited: (_) =>
                          setState(() => _isDraggingFile = false),
                      onDragDone: (details) async {
                        setState(() => _isDraggingFile = false);
                        final dropped = details.files.firstOrNull;
                        if (dropped != null) {
                          _setCharFile(dropped.path);
                          if (_targetCharacter == null) await _checkConflict(dropped.path);
                        }
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
                                    : AppTheme.textSecondary
                                        .withOpacity(0.5),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selectedCharFilePath != null
                                    ? _selectedCharFilePath!
                                        .split(r'\')
                                        .last
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
                          side: BorderSide(
                              color: AppTheme.borderColor),
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    // Conflict resolution status
                    if (_conflictingCharName != null) ...[
                      const SizedBox(height: 10),
                      _ConflictStatusBadge(
                        conflictingName: _conflictingCharName!,
                        customName: _customStorageName,
                        replaceExisting: _replaceExisting,
                        originalExt: _selectedCharFilePath != null
                            ? p.extension(_selectedCharFilePath!)
                            : '',
                      ),
                    ],
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
              // ── Right: form fields ───────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(_targetCharacter != null
                        ? 'Variant name *'
                        : 'Character name *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      onChanged: (_) => _nameWasAutoFilled = false,
                      decoration: InputDecoration(
                          hintText: _targetCharacter != null
                              ? 'e.g. Summer look, Battle outfit…'
                              : 'Enter a name for this character'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Name is required'
                              : null,
                    ),
                    const SizedBox(height: 18),
                    _buildVariantPicker(context, characters),
                    if (_targetCharacter == null) ...[
                      const SizedBox(height: 18),
                      _label('Description (optional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            hintText:
                                'Notes about this character, style, build…'),
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
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : Text(
                                _targetCharacter != null
                                    ? 'Save variant'
                                    : 'Save character',
                                style: const TextStyle(fontSize: 15)),
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

  Widget _buildVariantPicker(BuildContext context, List<CharacterData> characters) {
    if (_targetCharacter == null) {
      return OutlinedButton.icon(
        onPressed: characters.isEmpty
            ? null
            : () async {
                final picked = await _pickCharacter(context, characters);
                if (picked != null) setState(() => _targetCharacter = picked);
              },
        icon: const Icon(Icons.call_split_rounded, size: 14),
        label: Text(characters.isEmpty
            ? 'No existing characters'
            : 'Add as variant of existing character'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textSecondary,
          side: BorderSide(color: AppTheme.borderColor),
          textStyle: const TextStyle(fontSize: 12),
        ),
      );
    }
    final raceColor = AppTheme.raceColor(_targetCharacter!.race);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: raceColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Adding as variant of',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                Text(_targetCharacter!.name,
                    style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _targetCharacter = null),
            child: Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<CharacterData?> _pickCharacter(
      BuildContext context, List<CharacterData> characters) async {
    String query = '';
    return showDialog<CharacterData>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final filtered = query.isEmpty
              ? characters
              : characters
                  .where((c) =>
                      c.name.toLowerCase().contains(query.toLowerCase()))
                  .toList();
          return AlertDialog(
            backgroundColor: AppTheme.bgCard,
            title: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search characters…',
                prefixIcon: Icon(Icons.search_rounded,
                    size: 16, color: AppTheme.textSecondary),
              ),
              onChanged: (v) => setSt(() => query = v),
            ),
            content: SizedBox(
              width: 300,
              height: 320,
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No characters found',
                          style: TextStyle(color: AppTheme.textSecondary)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final rc = AppTheme.raceColor(c.race);
                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                                color: rc, shape: BoxShape.circle),
                          ),
                          title: Text(c.name,
                              style: TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 13)),
                          subtitle: Text(
                              '${c.race} · ${c.gender} · ${c.variants.length} variant${c.variants.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11)),
                          onTap: () => Navigator.pop(ctx, c),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCollectionPicker(List collections) {
    if (collections.isEmpty) {
      return Text(
          'No collections yet — create one in the Collections tab.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12));
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

  Widget _label(String text) => Text(text,
      style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500));

  Widget _badge(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 11)),
      );
}

/// Shows the current conflict resolution status below the file picker
class _ConflictStatusBadge extends StatelessWidget {
  final String conflictingName;
  final String? customName;
  final bool replaceExisting;
  final String originalExt;

  const _ConflictStatusBadge({
    required this.conflictingName,
    required this.customName,
    required this.replaceExisting,
    required this.originalExt,
  });

  @override
  Widget build(BuildContext context) {
    if (replaceExisting) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.red.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.swap_horiz_rounded,
                size: 13, color: Colors.red),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Will replace "$conflictingName"\'s file',
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }
    if (customName != null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.drive_file_rename_outline_rounded,
                size: 13, color: AppTheme.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Saved as: $customName$originalExt',
                style:
                    TextStyle(color: AppTheme.accent, fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
