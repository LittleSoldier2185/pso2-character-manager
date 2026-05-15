import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/collection.dart';
import '../providers/character_provider.dart';
import '../services/file_service.dart';
import '../theme/app_theme.dart';
import '../widgets/character_card.dart';
import '../widgets/tag_chip.dart';
import 'character_detail_screen.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  Collection? _openCollection;

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        if (_openCollection != null) {
          final still = provider.allCollections
              .where((c) => c.id == _openCollection!.id)
              .firstOrNull;
          if (still == null) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => setState(() => _openCollection = null));
          }
          return _CollectionDetailView(
            collection: still ?? _openCollection!,
            onBack: () => setState(() => _openCollection = null),
          );
        }
        return _CollectionGridView(
            onOpen: (col) => setState(() => _openCollection = col));
      },
    );
  }
}

class _CollectionGridView extends StatefulWidget {
  final ValueChanged<Collection> onOpen;
  const _CollectionGridView({required this.onOpen});

  @override
  State<_CollectionGridView> createState() => _CollectionGridViewState();
}

class _CollectionGridViewState extends State<_CollectionGridView> {
  String _search = '';

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _CollectionDialog(
        mode: _CollectionDialogMode.create,
        onSave: (name, desc, thumbPath, accentVal) async {
          await ctx.read<CharacterProvider>().addCollection(
                name,
                thumbnailPath: thumbPath,
                description: desc,
                accentColorValue: accentVal,
              );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        var collections = provider.allCollections;
        if (_search.isNotEmpty) {
          collections = collections
              .where((c) =>
                  c.name.toLowerCase().contains(_search.toLowerCase()))
              .toList();
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: const BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(
                    bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  Text(
                    _search.isNotEmpty
                        ? '${collections.length} of ${provider.allCollections.length} collections'
                        : '${collections.length} collection${collections.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search collections…',
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 15, color: AppTheme.textSecondary),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                onPressed: () =>
                                    setState(() => _search = ''),
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
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(context),
                    icon: const Icon(
                        Icons.create_new_folder_outlined,
                        size: 15),
                    label: const Text('New'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: collections.isEmpty
                  ? _buildEmpty(context)
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 240,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: collections.length,
                      itemBuilder: (context, i) => _CollectionCard(
                        collection: collections[i],
                        onOpen: widget.onOpen,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _search.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.folder_outlined,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _search.isNotEmpty
                ? 'No collections match "$_search"'
                : 'No collections yet',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          if (_search.isEmpty)
            ElevatedButton.icon(
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Create your first collection'),
            ),
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final Collection collection;
  final ValueChanged<Collection> onOpen;
  const _CollectionCard({required this.collection, required this.onOpen});

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _CollectionDialog(
        mode: _CollectionDialogMode.edit,
        collection: collection,
        onSave: (name, desc, thumbPath, accentVal) async {
          // thumbnail already handled inside dialog via provider
          collection.name = name;
          collection.description = desc;
          collection.accentColorValue = accentVal;
          await ctx.read<CharacterProvider>().updateCollection(collection);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Delete collection?'),
        content: Text(
            'Delete "${collection.name}"? Characters inside will not be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context
                  .read<CharacterProvider>()
                  .deleteCollection(collection.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final chars = provider.getCharactersForCollection(collection.id);
    final count = chars.length;
    final previews = chars.take(4).toList();
    final remaining = count - previews.length;
    final hasThumb = collection.thumbnailPath != null &&
        File(collection.thumbnailPath!).existsSync();
    // Use collection's custom accent or fall back to app accent
    final accentCol = collection.accentColor ?? AppTheme.accent;

    return GestureDetector(
      onTap: () => onOpen(collection),
      child: Container(
        decoration: BoxDecoration(
          color: accentCol.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: accentCol.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colour strip at top
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: accentCol,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(9)),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
                child: hasThumb
                    ? Image.file(File(collection.thumbnailPath!),
                        fit: BoxFit.cover, width: double.infinity)
                    : _buildPreviewGrid(previews, remaining),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder_rounded,
                          size: 14, color: accentCol),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          collection.name,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showEditDialog(context),
                        child: const Icon(Icons.edit_outlined,
                            size: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _confirmDelete(context),
                        child: const Icon(Icons.delete_outline,
                            size: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  if (collection.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      collection.description,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('$count character${count == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11)),
                      const Spacer(),
                      Row(children: [
                        Text('Open',
                            style: TextStyle(
                                color: accentCol, fontSize: 10)),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_forward_rounded,
                            size: 10, color: accentCol),
                      ]),
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

  Widget _buildPreviewGrid(List previews, int remaining) {
    if (previews.isEmpty) {
      return Container(
        color: AppTheme.bgSurface,
        child: Center(
          child: Icon(Icons.folder_open_outlined,
              size: 36,
              color: AppTheme.textSecondary.withOpacity(0.3)),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        ...previews.map((c) => _PreviewCell(character: c)),
        if (remaining > 0)
          Container(
            color: AppTheme.bgSurface,
            child: Center(
              child: Text('+$remaining',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ),
          ),
      ],
    );
  }
}

class _PreviewCell extends StatelessWidget {
  final dynamic character;
  const _PreviewCell({required this.character});

  @override
  Widget build(BuildContext context) {
    if (character.thumbnailPath != null) {
      final file = File(character.thumbnailPath!);
      if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    }
    return Container(
      color: AppTheme.bgSurface,
      child: Center(
        child: Icon(Icons.person_outline,
            size: 22,
            color: AppTheme.raceColor(character.race).withOpacity(0.4)),
      ),
    );
  }
}

class _CollectionDetailView extends StatefulWidget {
  final Collection collection;
  final VoidCallback onBack;
  const _CollectionDetailView(
      {required this.collection, required this.onBack});

  @override
  State<_CollectionDetailView> createState() =>
      _CollectionDetailViewState();
}

class _CollectionDetailViewState extends State<_CollectionDetailView> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        var chars =
            provider.getCharactersForCollection(widget.collection.id);
        if (_search.isNotEmpty) {
          chars = chars
              .where((c) =>
                  c.name.toLowerCase().contains(_search.toLowerCase()) ||
                  c.tags.any((t) =>
                      t.toLowerCase().contains(_search.toLowerCase())))
              .toList();
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: const BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(
                    bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    // No const — accent is dynamic
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back_rounded,
                            size: 16, color: AppTheme.accent),
                        const SizedBox(width: 4),
                        Text('Collections',
                            style: TextStyle(
                                color: AppTheme.accent, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('/',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(width: 8),
                  const Icon(Icons.folder_rounded,
                      size: 14, color: AppTheme.accentGold),
                  const SizedBox(width: 5),
                  Text(widget.collection.name,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                        '${provider.getCharacterCountForCollection(widget.collection.id)}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11)),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search in collection…',
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 15,
                            color: AppTheme.textSecondary),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                onPressed: () =>
                                    setState(() => _search = ''),
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
                ],
              ),
            ),
            Expanded(
              child: chars.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _search.isNotEmpty
                                ? Icons.search_off_rounded
                                : Icons.folder_open_outlined,
                            size: 56,
                            color: AppTheme.textSecondary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _search.isNotEmpty
                                ? 'No results for "$_search"'
                                : 'This collection is empty',
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 15),
                          ),
                          if (_search.isEmpty) ...[
                            const SizedBox(height: 6),
                            const Text(
                              'Edit a character and assign it to this collection',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        childAspectRatio: 0.68,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: chars.length,
                      itemBuilder: (context, index) {
                        final c = chars[index];
                        return CharacterCard(
                          character: c,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    CharacterDetailScreen(character: c)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Collection dialog (create / edit) ─────────────────────────────

enum _CollectionDialogMode { create, edit }

class _CollectionDialog extends StatefulWidget {
  final _CollectionDialogMode mode;
  final Collection? collection; // null when creating
  final Future<void> Function(
      String name, String desc, String? thumbPath, int? accentVal) onSave;

  const _CollectionDialog({
    required this.mode,
    required this.onSave,
    this.collection,
  });

  @override
  State<_CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<_CollectionDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  String? _pickedThumb;
  bool _removeThumbnail = false;
  int? _accentVal;
  bool _saving = false;

  // The 6 accent presets from AppTheme
  static final List<Color> _presets =
      AppTheme.accentPresets.map((p) => p.color).toList();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    final col = widget.collection;
    _nameCtrl = TextEditingController(text: col?.name ?? '');
    _descCtrl = TextEditingController(text: col?.description ?? '');
    _pickedThumb = col?.thumbnailPath;
    _accentVal = col?.accentColorValue;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.mode == _CollectionDialogMode.edit;
  bool get _hasThumb =>
      !_removeThumbnail &&
      _pickedThumb != null &&
      File(_pickedThumb!).existsSync();

  Future<void> _pickThumb() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image);
    if (r != null && r.files.single.path != null) {
      setState(() {
        _pickedThumb = r.files.single.path;
        _removeThumbnail = false;
      });
    }
  }

  Future<void> _handleSave() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final provider = context.read<CharacterProvider>();
      String? finalThumbPath = widget.collection?.thumbnailPath;

      if (_isEdit && widget.collection != null) {
        // Handle thumbnail changes via provider (deletes old file safely)
        if (_pickedThumb != null &&
            !_removeThumbnail &&
            _pickedThumb != widget.collection!.thumbnailPath) {
          await provider.updateCollectionThumbnail(
              widget.collection!, _pickedThumb!);
          finalThumbPath = widget.collection!.thumbnailPath;
        } else if (_removeThumbnail) {
          await provider.removeCollectionThumbnail(widget.collection!);
          finalThumbPath = null;
        }
      } else {
        // Create mode — copy new thumbnail if picked
        if (_pickedThumb != null) {
          finalThumbPath =
              await FileService.copyThumbnailFile(_pickedThumb!);
        } else {
          finalThumbPath = null;
        }
      }

      await widget.onSave(
          name, _descCtrl.text.trim(), finalThumbPath, _accentVal);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.mode == _CollectionDialogMode.create;
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                children: [
                  Text(
                    isCreate ? 'New collection' : 'Edit collection',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        size: 16, color: AppTheme.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // ── Tab bar ──────────────────────────────────────────
            TabBar(
              controller: _tabCtrl,
              labelColor: AppTheme.accent,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.accent,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
              tabs: [
                const Tab(text: 'Info'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Characters'),
                      if (isCreate) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSurface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('after save',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 9)),
                        ),
                      ] else ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${context.watch<CharacterProvider>().getCharacterCountForCollection(widget.collection?.id ?? '')}',
                            style: TextStyle(
                                color: AppTheme.accent, fontSize: 9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 1, color: AppTheme.borderColor),
            // ── Tab views ────────────────────────────────────────
            SizedBox(
              height: 340,
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── Info tab ──────────────────────────────────
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thumbnail row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Thumb preview box
                            GestureDetector(
                              onTap: _pickThumb,
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: AppTheme.bgSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppTheme.borderColor,
                                      style: BorderStyle.solid),
                                ),
                                child: _hasThumb
                                    ? ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(7),
                                        child: Image.file(
                                            File(_pickedThumb!),
                                            fit: BoxFit.cover))
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate_outlined,
                                            size: 24,
                                            color: AppTheme.textSecondary
                                                .withOpacity(0.5),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text('Cover',
                                              style: TextStyle(
                                                  color:
                                                      AppTheme.textSecondary,
                                                  fontSize: 10)),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Collection cover',
                                      style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  const Text(
                                      'Shown on the collections grid.',
                                      style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: _pickThumb,
                                        icon: const Icon(Icons.upload,
                                            size: 12),
                                        label: Text(
                                            _hasThumb ? 'Change' : 'Add',
                                            style: const TextStyle(
                                                fontSize: 11)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              AppTheme.textSecondary,
                                          side: const BorderSide(
                                              color: AppTheme.borderColor),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          minimumSize: Size.zero,
                                        ),
                                      ),
                                      if (_hasThumb) ...[
                                        const SizedBox(width: 6),
                                        OutlinedButton.icon(
                                          onPressed: () => setState(() {
                                            _removeThumbnail = true;
                                            _pickedThumb = null;
                                          }),
                                          icon: const Icon(
                                              Icons.delete_outline,
                                              size: 12,
                                              color: Colors.redAccent),
                                          label: const Text('Remove',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.redAccent)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                                color: Colors.redAccent,
                                                width: 0.5),
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5),
                                            minimumSize: Size.zero,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: AppTheme.borderColor, height: 1),
                        const SizedBox(height: 16),
                        // Name field
                        _fieldLabel('Collection name'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameCtrl,
                          autofocus: isCreate,
                          maxLength: 60,
                          decoration: const InputDecoration(
                            hintText: 'e.g. My CAST roster',
                            counterStyle: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 10),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Description field
                        _fieldLabel('Description'),
                        const Text('Optional',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _descCtrl,
                          maxLines: 2,
                          maxLength: 200,
                          decoration: const InputDecoration(
                            hintText: 'A short note about this collection…',
                            counterStyle: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 10),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Accent colour picker
                        Row(
                          children: [
                            _fieldLabel('Accent colour'),
                            const SizedBox(width: 8),
                            // Show current custom color swatch if not a preset
                            if (_accentVal != null &&
                                !_presets.any((p) =>
                                    p.toARGB32() == _accentVal)) ...[

                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Color(_accentVal!),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.borderColor),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Custom',
                                style: TextStyle(
                                    color: Color(_accentVal!),
                                    fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Quick presets row
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._presets.map((color) {
                              final isSelected = _accentVal ==
                                  color.toARGB32();
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _accentVal = isSelected
                                      ? null
                                      : color.toARGB32();
                                }),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 150),
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                                color: color.withOpacity(0.6),
                                                blurRadius: 6)
                                          ]
                                        : null,
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check,
                                          size: 14, color: Colors.white)
                                      : null,
                                ),
                              );
                            }),
                            // Custom colour wheel button
                            GestureDetector(
                              onTap: () async {
                                final current = _accentVal != null
                                    ? Color(_accentVal!)
                                    : AppTheme.accent;
                                final picked = await showColorPickerDialog(
                                  context,
                                  current,
                                  title: 'Collection colour',
                                );
                                if (picked != null) {
                                  setState(() =>
                                      _accentVal = picked.toARGB32());
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.borderColor),
                                  gradient: const SweepGradient(colors: [
                                    Colors.red,
                                    Colors.yellow,
                                    Colors.green,
                                    Colors.cyan,
                                    Colors.blue,
                                    Colors.purple,
                                    Colors.red,
                                  ]),
                                ),
                                child: const Icon(Icons.add,
                                    size: 13, color: Colors.white),
                              ),
                            ),
                            // Clear button
                            if (_accentVal != null)
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _accentVal = null),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.bgSurface,
                                    border: Border.all(
                                        color: AppTheme.borderColor),
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 13,
                                      color: AppTheme.textSecondary),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                            'Used for folder icon and label colour on the grid.',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 10)),
                      ],
                    ),
                  ),
                  // ── Characters tab ────────────────────────────
                  isCreate
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open_outlined,
                                  size: 40,
                                  color: AppTheme.textSecondary
                                      .withOpacity(0.3)),
                              const SizedBox(height: 12),
                              const Text(
                                'Create the collection first,',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13),
                              ),
                              const Text(
                                'then you can add characters to it.',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : _CharactersTab(
                          collection: widget.collection!,
                        ),
                ],
              ),
            ),
            // ── Footer ───────────────────────────────────────────
            const Divider(height: 1, color: AppTheme.borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.borderColor),
                      foregroundColor: AppTheme.textSecondary,
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _saving ? null : _handleSave,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.bgDark))
                        : Text(isCreate ? 'Create collection' : 'Save changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(text,
      style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.04));
}

// ── Characters tab content ─────────────────────────────────────────

class _CharactersTab extends StatelessWidget {
  final Collection collection;
  const _CharactersTab({required this.collection});

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        final chars =
            provider.getCharactersForCollection(collection.id);
        return Column(
          children: [
            Expanded(
              child: chars.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add_outlined,
                              size: 36,
                              color: AppTheme.textSecondary.withOpacity(0.3)),
                          const SizedBox(height: 10),
                          const Text('No characters yet',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13)),
                          const SizedBox(height: 4),
                          const Text(
                              'Edit a character and assign it to this collection',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: chars.length,
                      itemBuilder: (ctx, i) {
                        final c = chars[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSurface,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: AppTheme.borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: AppTheme.raceColor(c.race),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(c.name,
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 12)),
                              ),
                              Text('${c.race} · ${c.gender[0]}',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 10)),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () async {
                                  c.collectionIds = c.collectionIds
                                      .where((id) => id != collection.id)
                                      .toList();
                                  c.collectionId =
                                      c.collectionIds.isNotEmpty
                                          ? c.collectionIds.first
                                          : null;
                                  await provider.updateCharacter(c);
                                },
                                child: const Icon(Icons.close,
                                    size: 13,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Removing a character here only removes them from this collection — it does not delete them from your library.',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 10),
              ),
            ),
          ],
        );
      },
    );
  }
}
