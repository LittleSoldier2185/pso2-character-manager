import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/collection.dart';
import '../providers/character_provider.dart';
import '../services/file_service.dart';
import '../theme/app_theme.dart';
import '../widgets/character_card.dart';
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
    final nameCtrl = TextEditingController();
    String? pickedThumb;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('New collection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration:
                    const InputDecoration(hintText: 'Collection name'),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final r = await FilePicker.platform
                      .pickFiles(type: FileType.image);
                  if (r != null && r.files.single.path != null) {
                    setSt(() => pickedThumb = r.files.single.path);
                  }
                },
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: pickedThumb != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.file(File(pickedThumb!),
                              fit: BoxFit.cover, width: double.infinity))
                      : const Center(
                          child: Text(
                              'Tap to add collection thumbnail (optional)',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                String? thumbPath;
                if (pickedThumb != null) {
                  thumbPath =
                      await FileService.copyThumbnailFile(pickedThumb!);
                }
                if (ctx.mounted) {
                  await ctx
                      .read<CharacterProvider>()
                      .addCollection(name, thumbnailPath: thumbPath);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
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
    final ctrl = TextEditingController(text: collection.name);
    String? pickedThumb = collection.thumbnailPath;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('Edit collection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration:
                    const InputDecoration(hintText: 'Collection name'),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final r = await FilePicker.platform
                      .pickFiles(type: FileType.image);
                  if (r != null && r.files.single.path != null) {
                    final copied = await FileService.copyThumbnailFile(
                        r.files.single.path!);
                    setSt(() => pickedThumb = copied);
                  }
                },
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: pickedThumb != null &&
                          File(pickedThumb!).existsSync()
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.file(File(pickedThumb!),
                              fit: BoxFit.cover, width: double.infinity))
                      : const Center(
                          child: Text('Tap to change thumbnail',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = ctrl.text.trim();
                if (name.isEmpty) return;
                collection.name = name;
                collection.thumbnailPath = pickedThumb;
                if (ctx.mounted) {
                  await ctx
                      .read<CharacterProvider>()
                      .updateCollection(collection);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
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

    return GestureDetector(
      onTap: () => onOpen(collection),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      const Icon(Icons.folder_rounded,
                          size: 14, color: AppTheme.accentGold),
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
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('$count character${count == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11)),
                      const Spacer(),
                      // No const — accent is dynamic
                      Row(children: [
                        Text('Open',
                            style: TextStyle(
                                color: AppTheme.accent, fontSize: 10)),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_forward_rounded,
                            size: 10, color: AppTheme.accent),
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
