import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/character.dart';
import '../providers/character_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/tag_chip.dart';

class AddCharacterScreen extends StatefulWidget {
  const AddCharacterScreen({super.key});

  @override
  State<AddCharacterScreen> createState() => _AddCharacterScreenState();
}

class _AddCharacterScreenState extends State<AddCharacterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tagController = TextEditingController();

  String? _selectedCharFilePath;
  String? _selectedImagePath;
  String? _detectedRace;
  String? _detectedGender;
  String? _selectedCollectionId;
  final List<String> _tags = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickCharacterFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'fhp', 'mhp', 'fnp', 'mnp', 'fdp', 'mdp', 'fcp', 'mcp'
      ],
      dialogTitle: 'Select PSO2 Character File',
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final raceGender = Character.detectRaceGender(path);
      setState(() {
        _selectedCharFilePath = path;
        _detectedRace = raceGender['race'];
        _detectedGender = raceGender['gender'];
      });
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: 'Select Thumbnail Image',
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
            content: Text('Please select a character file first'),
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
            collectionId: _selectedCollectionId,
          );
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
    final collections = context.watch<CharacterProvider>().allCollections;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Character')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: thumbnail picker
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 200,
                        height: 220,
                        decoration: BoxDecoration(
                          color: AppTheme.bgSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.borderColor, width: 1.5),
                        ),
                        child: _selectedImagePath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.file(
                                  File(_selectedImagePath!),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined,
                                      size: 40,
                                      color: AppTheme.textSecondary
                                          .withOpacity(0.5)),
                                  const SizedBox(height: 8),
                                  const Text('Click to add\nthumbnail',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image_outlined, size: 16),
                      label: const Text('Change image',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // Right: form fields
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Character File *'),
                    const SizedBox(height: 8),
                    _buildFilePicker(),
                    const SizedBox(height: 20),
                    if (_detectedRace != null) ...[
                      Row(
                        children: [
                          _infoBadge('Race: $_detectedRace',
                              AppTheme.raceColor(_detectedRace!)),
                          const SizedBox(width: 8),
                          _infoBadge(
                              'Gender: $_detectedGender', AppTheme.accentGold),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    _sectionLabel('Character Name *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                          hintText: 'Enter a name for this character'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('Collection (optional)'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: _selectedCollectionId,
                      dropdownColor: AppTheme.bgSurface,
                      decoration:
                          const InputDecoration(hintText: 'None'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('None')),
                        ...collections.map((c) => DropdownMenuItem(
                            value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedCollectionId = v),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('Tags (optional)'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _tagController,
                            decoration: const InputDecoration(
                                hintText: 'e.g. favorite, blue hair'),
                            onFieldSubmitted: (_) => _addTag(),
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
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Text('Save Character',
                                style: TextStyle(fontSize: 16)),
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

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500));

  Widget _buildFilePicker() {
    return InkWell(
      onTap: _pickCharacterFile,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _selectedCharFilePath != null
                ? AppTheme.accent
                : AppTheme.borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.upload_file,
                color: _selectedCharFilePath != null
                    ? AppTheme.accent
                    : AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedCharFilePath != null
                    ? _selectedCharFilePath!.split(r'\').last
                    : 'Click to select .fhp, .mhp, .fnp … file',
                style: TextStyle(
                    color: _selectedCharFilePath != null
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 13)),
      );
}
