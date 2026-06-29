import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/album_data.dart';
import '../models/character_data.dart';
import '../models/gallery_data.dart';
import '../providers/character_provider.dart';
import '../models/tag_data.dart';
import '../services/album_export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_title_bar.dart';
import '../widgets/tag_chip.dart';
import 'character_detail_screen.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  String _query = '';
  int _searchKey = 0;
  bool _filterOpen = false;
  final _filterLink = LayerLink();
  OverlayEntry? _filterEntry;
  final _filterSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _filterEntry?.remove();
    _filterSearchCtrl.dispose();
    super.dispose();
  }

  void _openFilter(CharacterProvider provider) {
    _filterEntry?.remove();
    _filterEntry = OverlayEntry(builder: (_) => _buildFilterOverlay(provider));
    Overlay.of(context).insert(_filterEntry!);
    setState(() => _filterOpen = true);
  }

  void _closeFilter() {
    _filterEntry?.remove();
    _filterEntry = null;
    _filterSearchCtrl.clear();
    setState(() => _filterOpen = false);
  }

  Widget _buildFilterOverlay(CharacterProvider provider) {
    final query = _filterSearchCtrl.text.toLowerCase();
    final tags = provider.allAlbumTags
        .where((t) => query.isEmpty || t.name.toLowerCase().contains(query))
        .toList();
    final active = provider.albumTagFilter;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closeFilter,
          ),
        ),
        CompositedTransformFollower(
          link: _filterLink,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 6),
          child: GestureDetector(
            onTap: () {},
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 220,
                constraints: const BoxConstraints(maxHeight: 320),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Text('Filter by tag',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      child: TextField(
                        controller: _filterSearchCtrl,
                        autofocus: true,
                        onChanged: (_) {
                          setState(() {});
                          _filterEntry?.markNeedsBuild();
                        },
                        style: TextStyle(
                            color: AppTheme.textPrimary, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search tags…',
                          hintStyle: TextStyle(
                              color: AppTheme.textSecondary
                                  .withValues(alpha: 0.4),
                              fontSize: 12),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 14, color: AppTheme.textSecondary),
                          suffixIcon: _filterSearchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear,
                                      size: 12,
                                      color: AppTheme.textSecondary),
                                  onPressed: () {
                                    _filterSearchCtrl.clear();
                                    setState(() {});
                                    _filterEntry?.markNeedsBuild();
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 7),
                          filled: true,
                          fillColor: AppTheme.bgSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: AppTheme.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: AppTheme.borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.accent),
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: AppTheme.borderColor),
                    if (tags.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text('No tags match.',
                            style: TextStyle(
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.5),
                                fontSize: 12)),
                      )
                    else
                    Flexible(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shrinkWrap: true,
                        itemCount: tags.length,
                        itemBuilder: (_, i) {
                          final tag = tags[i];
                          final on = active.contains(tag.id);
                          return InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              provider.toggleAlbumTagFilter(tag.id);
                              _filterEntry?.markNeedsBuild();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      color: tag.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(tag.name,
                                        style: TextStyle(
                                          color: on
                                              ? AppTheme.textPrimary
                                              : AppTheme.textSecondary,
                                          fontSize: 13,
                                          fontWeight: on
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                        )),
                                  ),
                                  if (on)
                                    Icon(Icons.check_rounded,
                                        size: 15, color: AppTheme.accent),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (active.isNotEmpty) ...[
                      Divider(height: 1, color: AppTheme.borderColor),
                      TextButton(
                        onPressed: () {
                          provider.clearAlbumTagFilter();
                          _filterEntry?.markNeedsBuild();
                        },
                        child: Text('Clear filters',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        final all = provider.sortedAlbums;
        final activeTagFilter = provider.albumTagFilter;
        var albums = _query.isEmpty
            ? all
            : all.where((a) =>
                a.name.toLowerCase().contains(_query.toLowerCase())).toList();
        if (activeTagFilter.isNotEmpty) {
          albums = albums
              .where((a) => activeTagFilter.every((tid) => a.tagIds.contains(tid)))
              .toList();
        }
        final allItems = provider.getAllGalleryItems();
        final albumTags = provider.allAlbumTags;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  Text(
                    all.isEmpty
                        ? 'Albums'
                        : '${albums.length}/${all.length} album${all.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      key: ValueKey(_searchKey),
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Search albums…',
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 15, color: AppTheme.textSecondary),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                onPressed: () => setState(() {
                                  _query = '';
                                  _searchKey++;
                                }),
                              )
                            : null,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == '__fav_top__') {
                        provider.setAlbumFavouritesOnTop(!provider.albumFavouritesOnTop);
                      } else {
                        provider.setAlbumSortOption(AlbumSortOption.values.byName(v));
                      }
                    },
                    color: AppTheme.bgCard,
                    tooltip: 'Sort albums',
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(
                        value: '__fav_top__',
                        child: Row(
                          children: [
                            Icon(
                              provider.albumFavouritesOnTop
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 14,
                              color: provider.albumFavouritesOnTop
                                  ? Colors.pinkAccent
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text('Favourites on top',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: provider.albumFavouritesOnTop
                                        ? Colors.pinkAccent
                                        : AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      ...AlbumSortOption.values.map((opt) =>
                        CheckedPopupMenuItem<String>(
                          value: opt.name,
                          checked: provider.albumSortOption == opt,
                          child: Row(
                            children: [
                              Icon(opt.icon, size: 14, color: AppTheme.textSecondary),
                              const SizedBox(width: 8),
                              Text(opt.label, style: TextStyle(
                                fontSize: 13, color: AppTheme.textPrimary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: provider.albumSortOption != AlbumSortOption.newestFirst
                            ? AppTheme.accent.withValues(alpha: 0.15)
                            : AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: provider.albumSortOption != AlbumSortOption.newestFirst
                              ? AppTheme.accent
                              : AppTheme.borderColor,
                          width: provider.albumSortOption != AlbumSortOption.newestFirst ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sort_rounded, size: 14,
                              color: provider.albumSortOption != AlbumSortOption.newestFirst
                                  ? AppTheme.accent : AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text('Sort', style: TextStyle(
                              fontSize: 12,
                              color: provider.albumSortOption != AlbumSortOption.newestFirst
                                  ? AppTheme.accent : AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (albumTags.isNotEmpty)
                    CompositedTransformTarget(
                      link: _filterLink,
                      child: GestureDetector(
                        onTap: () => _filterOpen
                            ? _closeFilter()
                            : _openFilter(provider),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: (_filterOpen ||
                                    activeTagFilter.isNotEmpty)
                                ? AppTheme.accent.withValues(alpha: 0.15)
                                : AppTheme.bgSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (_filterOpen ||
                                      activeTagFilter.isNotEmpty)
                                  ? AppTheme.accent
                                  : AppTheme.borderColor,
                              width: (_filterOpen ||
                                      activeTagFilter.isNotEmpty)
                                  ? 1.5
                                  : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.label_rounded,
                                  size: 14,
                                  color: (_filterOpen ||
                                          activeTagFilter.isNotEmpty)
                                      ? AppTheme.accent
                                      : AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Text('Filter',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: (_filterOpen ||
                                              activeTagFilter.isNotEmpty)
                                          ? AppTheme.accent
                                          : AppTheme.textSecondary)),
                              if (activeTagFilter.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 18, height: 18,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${activeTagFilter.length}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 4),
                              Icon(
                                _filterOpen
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                size: 14,
                                color: (_filterOpen ||
                                        activeTagFilter.isNotEmpty)
                                    ? AppTheme.accent
                                    : AppTheme.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _createAlbum(context, provider),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('New album'),
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
              child: all.isEmpty
                  ? _buildEmpty(context, provider)
                  : albums.isEmpty
                      ? Center(
                          child: Text('No albums match the current filter.',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 13)),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: albums.length,
                          itemBuilder: (_, i) => _AlbumCard(
                            album: albums[i],
                            allItems: allItems,
                            allCharacters: provider.allCharacters,
                            allAlbumTags: albumTags,
                            cardStyle: provider.albumCardStyle,
                            onTap: () => _openViewer(context, albums[i]),
                            onRename: () =>
                                _renameAlbum(context, provider, albums[i]),
                            onDelete: () =>
                                _deleteAlbum(context, provider, albums[i]),
                            onEditTags: () =>
                                _editAlbumTags(context, provider, albums[i]),
                            onToggleFavourite: () =>
                                provider.toggleAlbumFavourite(albums[i]),
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editAlbumTags(BuildContext context, CharacterProvider provider,
      AlbumData album) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AlbumTagsDialog(album: album, provider: provider),
    );
  }

  void _openViewer(BuildContext context, AlbumData album) {
    context.read<CharacterProvider>().touchAlbumViewed(album.id);
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (_) => _AlbumDetailDialog(album: album),
    );
  }

  Future<void> _createAlbum(
      BuildContext context, CharacterProvider provider) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('New album', style: TextStyle(fontSize: 15)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Album name…'),
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name != null && name.trim().isNotEmpty) {
      await provider.createAlbum(name.trim());
    }
  }

  Future<void> _renameAlbum(BuildContext context, CharacterProvider provider,
      AlbumData album) async {
    final ctrl = TextEditingController(text: album.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Rename album', style: TextStyle(fontSize: 15)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Album name…'),
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name != null && name.trim().isNotEmpty) {
      await provider.renameAlbum(album, name.trim());
    }
  }

  Future<void> _deleteAlbum(BuildContext context, CharacterProvider provider,
      AlbumData album) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Delete album?'),
        content: Text(
          'Removes "${album.name}". Images are not deleted.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await provider.deleteAlbum(album);
  }

  Widget _buildEmpty(BuildContext context, CharacterProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_album_outlined,
              size: 56,
              color: AppTheme.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No albums yet',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 8),
          Text('Right-click any gallery image and choose "Add to album".',
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _createAlbum(context, provider),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Create album'),
          ),
        ],
      ),
    );
  }
}

// ── Album card ────────────────────────────────────────────────────

class _AlbumCard extends StatefulWidget {
  final AlbumData album;
  final List<GalleryItemData> allItems;
  final List<CharacterData> allCharacters;
  final List<TagData> allAlbumTags;
  final String cardStyle;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onEditTags;
  final VoidCallback onToggleFavourite;

  const _AlbumCard({
    required this.album,
    required this.allItems,
    required this.allCharacters,
    required this.allAlbumTags,
    required this.cardStyle,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    required this.onEditTags,
    required this.onToggleFavourite,
  });

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> {
  bool _hovered = false;

  GalleryItemData? get _cover {
    final id = widget.album.coverId;
    if (id == null) return null;
    return widget.allItems.where((i) => i.id == id).firstOrNull;
  }

  CharacterData? _char(GalleryItemData item) =>
      widget.allCharacters.where((c) => c.id == item.characterId).firstOrNull;

  void _showCtxMenu(BuildContext context, Offset pos) async {
    final size = MediaQuery.of(context).size;
    final result = await showMenu<String>(
      context: context,
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      position: RelativeRect.fromLTRB(
          pos.dx, pos.dy, size.width - pos.dx, size.height - pos.dy),
      items: [
        PopupMenuItem(
            value: 'favourite',
            child: _menuRow(
                widget.album.isFavourite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                widget.album.isFavourite ? 'Unfavourite' : 'Favourite')),
        PopupMenuItem(
            value: 'rename',
            child: _menuRow(
                Icons.drive_file_rename_outline_rounded, 'Rename')),
        if (widget.allAlbumTags.isNotEmpty)
          PopupMenuItem(
              value: 'tags',
              child: _menuRow(Icons.label_outline_rounded, 'Edit tags')),
        PopupMenuItem(
            value: 'delete',
            child: _menuRow(Icons.delete_outline_rounded, 'Delete')),
      ],
    );
    if (result == 'favourite') widget.onToggleFavourite();
    if (result == 'rename') widget.onRename();
    if (result == 'tags') widget.onEditTags();
    if (result == 'delete') widget.onDelete();
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

  // ── Shared helpers ────────────────────────────────────────────────

  Widget _imageContent(bool hasImage, String path) {
    if (!hasImage) {
      return Container(
        color: AppTheme.bgCard,
        child: Center(
          child: Icon(Icons.photo_album_outlined,
              size: 32,
              color: AppTheme.textSecondary.withValues(alpha: 0.3)),
        ),
      );
    }
    if (_cover!.isBlurred) {
      return ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Image.file(File(path), fit: BoxFit.cover, gaplessPlayback: true),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Image.file(File(path), fit: BoxFit.cover, gaplessPlayback: true),
        ),
        Image.file(File(path), fit: BoxFit.contain, gaplessPlayback: true),
      ],
    );
  }

  Widget _heartBtn() => Positioned(
        top: 6,
        right: 6,
        child: GestureDetector(
          onTap: widget.onToggleFavourite,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: widget.album.isFavourite ? 1.0 : (_hovered ? 0.7 : 0.0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.album.isFavourite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 14,
                color:
                    widget.album.isFavourite ? Colors.pinkAccent : Colors.white,
              ),
            ),
          ),
        ),
      );

  Widget _infoBar(int count, {BorderRadiusGeometry? borderRadius}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: borderRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.album.name,
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('$count image${count == 1 ? '' : 's'}',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ],
        ),
      );

  // ── Style builders ────────────────────────────────────────────────

  Widget _buildDefault(bool hasImage, String path, int count) =>
      AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _hovered
                ? AppTheme.accent.withValues(alpha: 0.5)
                : AppTheme.borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(7)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _imageContent(hasImage, path),
                    if (widget.album.isFavourite || _hovered) _heartBtn(),
                  ],
                ),
              ),
            ),
            _infoBar(count,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(7))),
          ],
        ),
      );

  Widget _buildBook(bool hasImage, String path, int count) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0, top: 6, right: -8, bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8)),
                border: Border.all(
                    color: AppTheme.borderColor.withValues(alpha: 0.4)),
              ),
            ),
          ),
          Positioned(
            left: 0, top: 3, right: -4, bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8)),
                border: Border.all(
                    color: AppTheme.borderColor.withValues(alpha: 0.65)),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8)),
              border: Border.all(
                color: _hovered
                    ? AppTheme.accent.withValues(alpha: 0.5)
                    : AppTheme.borderColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  offset: const Offset(2, 6),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(7)),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _imageContent(hasImage, path),
                              if (widget.album.isFavourite || _hovered)
                                _heartBtn(),
                            ],
                          ),
                        ),
                      ),
                      _infoBar(count,
                          borderRadius: const BorderRadius.only(
                              bottomRight: Radius.circular(7))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildPolaroid(bool hasImage, String path, int count) =>
      AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: _hovered
              ? Border.all(color: AppTheme.accent.withValues(alpha: 0.6))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(7, 7, 7, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _imageContent(hasImage, path),
                      if (widget.album.isFavourite || _hovered) _heartBtn(),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 38,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.album.name,
                        style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('$count image${count == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: Color(0xFF666666), fontSize: 9)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildMagazine(bool hasImage, String path, int count) =>
      AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _hovered
                ? AppTheme.accent.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              hasImage
                  ? (_cover!.isBlurred
                      ? ImageFiltered(
                          imageFilter:
                              ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Image.file(File(path),
                              fit: BoxFit.cover, gaplessPlayback: true))
                      : Image.file(File(path),
                          fit: BoxFit.cover, gaplessPlayback: true))
                  : Container(
                      color: AppTheme.bgCard,
                      child: Center(
                        child: Icon(Icons.photo_album_outlined,
                            size: 32,
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.3)),
                      ),
                    ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.82),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.album.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('$count image${count == 1 ? '' : 's'}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10)),
                    ],
                  ),
                ),
              ),
              if (widget.album.isFavourite || _hovered) _heartBtn(),
            ],
          ),
        ),
      );

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cover = _cover;
    final char = cover != null ? _char(cover) : null;
    final path =
        cover != null && char != null ? cover.filePath(char.folderPath) : '';
    final hasImage = path.isNotEmpty && File(path).existsSync();
    final count = widget.album.itemIds.length;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: (d) => _showCtxMenu(context, d.globalPosition),
        child: switch (widget.cardStyle) {
          'book'     => _buildBook(hasImage, path, count),
          'polaroid' => _buildPolaroid(hasImage, path, count),
          'magazine' => _buildMagazine(hasImage, path, count),
          _          => _buildDefault(hasImage, path, count),
        },
      ),
    );
  }
}

// ── Album detail dialog ───────────────────────────────────────────

class _AlbumDetailDialog extends StatefulWidget {
  final AlbumData album;
  const _AlbumDetailDialog({required this.album});

  @override
  State<_AlbumDetailDialog> createState() => _AlbumDetailDialogState();
}

enum _ReaderMode { horizontal, vertical, book }

class _AlbumDetailDialogState extends State<_AlbumDetailDialog> {
  bool _readMode = false;
  bool _manageMode = false;
  _ReaderMode _readerMode = _ReaderMode.horizontal;
  int _currentPage = 0;
  late PageController _pageCtrl;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  Set<String> _pendingTagIds = {};
  bool _manageGrid = false;
  final _tagSearchCtrl = TextEditingController();
  bool _tagPickerOpen = false;
  final _tagPickerLink = LayerLink();
  OverlayEntry? _tagPickerEntry;
  int? _gridDragIndex;
  int? _gridDropIndex;
  double _zoomLevel = 1.0;
  final _transformCtrl = TransformationController();
  Size _readerSize = Size.zero;
  bool _autoPlay = false;
  int _autoPlaySeconds = 3;
  Timer? _autoPlayTimer;
  int _autoPlayTotalPages = 0;
  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _nameCtrl.text = widget.album.name;
    _descCtrl.text = widget.album.description;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final layout = context.read<CharacterProvider>().defaultReaderLayout;
      final mode = switch (layout) {
        'vertical' => _ReaderMode.vertical,
        'book'     => _ReaderMode.book,
        _          => _ReaderMode.horizontal,
      };
      if (mode != _readerMode) setState(() => _readerMode = mode);
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _tagSearchCtrl.dispose();
    _tagPickerEntry?.remove();
    _transformCtrl.dispose();
    super.dispose();
  }

  void _setZoom(double scale) {
    final w = _readerSize.width;
    final h = _readerSize.height;
    _transformCtrl.value = Matrix4.identity()
      ..translateByDouble(w / 2 * (1 - scale), h / 2 * (1 - scale), 0, 1)
      ..scaleByDouble(scale, scale, 1.0, 1.0);
    setState(() => _zoomLevel = scale);
  }

  void _zoomAtCursor(Offset cursor, double newScale) {
    final v = newScale.clamp(1.0, 5.0);
    if (v == _zoomLevel) return;
    if (v == 1.0) { _resetZoom(); setState(() {}); return; }
    final change = v / _zoomLevel;
    final pivot = Matrix4.identity()
      ..translate(cursor.dx, cursor.dy, 0.0)
      ..scale(change, change, 1.0)
      ..translate(-cursor.dx, -cursor.dy, 0.0);
    pivot.multiply(_transformCtrl.value);
    _transformCtrl.value = pivot;
    setState(() => _zoomLevel = v);
  }

  void _resetZoom() {
    _transformCtrl.value = Matrix4.identity();
    _zoomLevel = 1.0;
  }

  void _enterManageMode(AlbumData album) {
    _nameCtrl.text = album.name;
    _descCtrl.text = album.description;
    _pendingTagIds = Set.from(album.tagIds);
    _closeTagPicker();
    setState(() => _manageMode = true);
  }

  void _setReaderMode(_ReaderMode mode) {
    if (mode == _readerMode) return;
    final imgIdx =
        _readerMode == _ReaderMode.book ? _currentPage * 2 : _currentPage;
    final newPage = mode == _ReaderMode.book ? imgIdx ~/ 2 : imgIdx;
    _pageCtrl.dispose();
    _pageCtrl = PageController(initialPage: newPage);
    _resetZoom();
    setState(() {
      _readerMode = mode;
      _currentPage = newPage;
    });
  }

  int _pageCount(int itemCount) =>
      _readerMode == _ReaderMode.book ? (itemCount + 1) ~/ 2 : itemCount;

  Future<void> _exportAlbum(BuildContext context, CharacterProvider p,
      AlbumData album, List<GalleryItemData> items) async {
    final paths = items
        .map((i) => _path(p, i))
        .where((s) => s.isNotEmpty && File(s).existsSync())
        .toList();
    if (paths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No images to export')));
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Export album', style: TextStyle(fontSize: 15)),
        content: Text(
          'Export "${album.name}" (${paths.length} image${paths.length == 1 ? '' : 's'}) as:',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, 'zip'),
              child: const Text('ZIP')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, 'pdf'),
              child: const Text('PDF')),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;

    final error = choice == 'zip'
        ? await AlbumExportService.exportZip(album, paths)
        : await AlbumExportService.exportPdf(album, paths);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Exported as ${choice.toUpperCase()}'),
    ));
  }

  void _prevPage() => _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  void _nextPage() => _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 200), curve: Curves.easeOut);

  void _startAutoPlay(int totalPages) {
    _autoPlayTotalPages = totalPages;
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(Duration(seconds: _autoPlaySeconds), (_) {
      if (_currentPage < _autoPlayTotalPages - 1) {
        _nextPage();
      } else {
        _stopAutoPlay();
      }
    });
    setState(() => _autoPlay = true);
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
    if (mounted) setState(() => _autoPlay = false);
  }

  Future<void> _showDelayDialog() async {
    final ctrl = TextEditingController(text: _autoPlaySeconds.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Auto-play delay', style: TextStyle(fontSize: 14)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            suffixText: 'sec',
            isDense: true,
            hintText: '1 – 60',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
          onSubmitted: (v) {
            final n = int.tryParse(v);
            if (n != null && n > 0) Navigator.pop(context, n);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text);
              if (n != null && n > 0) Navigator.pop(context, n);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) {
      setState(() => _autoPlaySeconds = result.clamp(1, 60));
      if (_autoPlay) _startAutoPlay(_autoPlayTotalPages);
    }
  }

  CharacterData? _char(CharacterProvider p, GalleryItemData item) =>
      p.allCharacters.where((c) => c.id == item.characterId).firstOrNull;

  String _path(CharacterProvider p, GalleryItemData item) {
    final ch = _char(p, item);
    return ch != null ? item.filePath(ch.folderPath) : '';
  }

  List<GalleryItemData> _resolveItems(CharacterProvider p, AlbumData album) =>
      album.itemIds
          .map((id) => p.getAllGalleryItems().where((i) => i.id == id).firstOrNull)
          .whereType<GalleryItemData>()
          .toList();

  static String _fmtDate(DateTime dt) =>
      '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)}';

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (ctx, p, _) {
        final album = p.allAlbums.where((a) => a.id == widget.album.id).firstOrNull
            ?? widget.album;
        final items = _resolveItems(p, album);
        final chars = items
            .map((i) => _char(p, i))
            .whereType<CharacterData>()
            .toSet()
            .toList();

        return Dialog(
          backgroundColor: AppTheme.bgDark,
          insetPadding: EdgeInsets.zero,
          child: Focus(
            autofocus: true,
            onKeyEvent: (_, e) {
              if (e is! KeyDownEvent) return KeyEventResult.ignored;
              final k = e.logicalKey;
              if (k == LogicalKeyboardKey.escape) {
                if (_readMode || _manageMode) {
                  _stopAutoPlay();
                  setState(() { _readMode = false; _manageMode = false; });
                } else {
                  Navigator.pop(context);
                }
                return KeyEventResult.handled;
              }
              if (_readMode && k == LogicalKeyboardKey.space) {
                if (_autoPlay) _stopAutoPlay();
                else _startAutoPlay(_pageCount(items.length));
                return KeyEventResult.handled;
              }
              if (_readMode) {
                final count = _pageCount(items.length);
                final isVert = _readerMode == _ReaderMode.vertical;
                final prevKey = isVert
                    ? LogicalKeyboardKey.arrowUp
                    : LogicalKeyboardKey.arrowLeft;
                final nextKey = isVert
                    ? LogicalKeyboardKey.arrowDown
                    : LogicalKeyboardKey.arrowRight;
                if (k == prevKey && _currentPage > 0) {
                  _prevPage(); return KeyEventResult.handled;
                }
                if (k == nextKey && _currentPage < count - 1) {
                  _nextPage(); return KeyEventResult.handled;
                }
                if (k == LogicalKeyboardKey.numpadAdd) {
                  _setZoom((_zoomLevel + 0.5).clamp(1.0, 5.0));
                  return KeyEventResult.handled;
                }
                if (k == LogicalKeyboardKey.numpadSubtract) {
                  _setZoom((_zoomLevel - 0.5).clamp(1.0, 5.0));
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: Column(
              children: [
                const AppTitleBar(),
                Expanded(
                  child: _readMode
                      ? _buildReader(context, p, album, items)
                      : _manageMode
                          ? _buildManage(context, p, album, items)
                          : _buildDetail(ctx, p, album, items, chars),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Gallery detail view ───────────────────────────────────────────

  Widget _buildDetail(BuildContext ctx, CharacterProvider p, AlbumData album,
      List<GalleryItemData> items, List<CharacterData> chars) {
    return Column(
      children: [
        // ── Title bar ───────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            border: Border(
                bottom: BorderSide(color: AppTheme.accent, width: 2)),
          ),
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    size: 18, color: AppTheme.accent),
                tooltip: 'Back to albums',
                onPressed: () => Navigator.pop(context),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              Icon(Icons.photo_album_rounded,
                  color: AppTheme.accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(album.name,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        _buildInfoPanel(p, album, items, chars),
        Divider(height: 1, thickness: 1, color: AppTheme.borderColor),
        Expanded(child: _buildThumbnailGrid(p, items)),
      ],
    );
  }

  Widget _buildInfoPanel(CharacterProvider p, AlbumData album,
      List<GalleryItemData> items, List<CharacterData> chars) {
    final coverPath = items.isNotEmpty ? _path(p, items.first) : '';
    final coverExists = coverPath.isNotEmpty && File(coverPath).existsSync();

    return Container(
      color: AppTheme.bgCard,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left: cover + action buttons ───────────────────────────
          SizedBox(
            width: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: coverExists
                      ? ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 285),
                          child: Image.file(File(coverPath),
                              width: 160,
                              fit: BoxFit.contain,
                              gaplessPlayback: true),
                        )
                      : AspectRatio(
                          aspectRatio: 9 / 16,
                          child: Container(
                              color: AppTheme.bgSurface,
                              child: Icon(Icons.photo_album_outlined,
                                  color: AppTheme.textSecondary
                                      .withValues(alpha: 0.3),
                                  size: 48)),
                        ),
                ),
                const SizedBox(height: 8),
                _DetailBtn(
                  label: 'View',
                  icon: Icons.import_contacts_rounded,
                  onTap: () => setState(() => _readMode = true),
                ),
                const SizedBox(height: 4),
                _DetailBtn(
                  label: 'Manage',
                  icon: Icons.tune_rounded,
                  dim: true,
                  onTap: () => _enterManageMode(album),
                ),
                const SizedBox(height: 4),
                _DetailBtn(
                  label: 'Export',
                  icon: Icons.ios_share,
                  dim: true,
                  onTap: () => _exportAlbum(context, p, album, items),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // ── Right: metadata ────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetaRow(label: 'Name', value: album.name),
                _MetaRow(
                    label: 'Description',
                    value: album.description.isNotEmpty
                        ? album.description
                        : '—'),
                if (chars.isNotEmpty)
                  _MetaRowWidget(
                    label: 'Character',
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: chars.map((c) => _CharBadge(
                        char: c,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => CharacterDetailScreen(character: c))),
                      )).toList(),
                    ),
                  )
                else
                  _MetaRow(label: 'Character', value: '—'),
                _MetaRow(label: 'Created at', value: _fmtDate(album.createdAt)),
                _MetaRow(label: 'Last edit', value: _fmtDate(album.updatedAt ?? album.createdAt)),
                _MetaRowWidget(
                  label: 'Tags',
                  child: () {
                    final tags = p.allAlbumTags
                        .where((t) => album.tagIds.contains(t.id))
                        .toList();
                    return tags.isEmpty
                        ? Text('—',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12))
                        : Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: tags
                                .map((t) => TagChip(tag: t, selected: true))
                                .toList(),
                          );
                  }(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailGrid(CharacterProvider p, List<GalleryItemData> items) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_album_outlined, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text('No images in this album',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
            SizedBox(height: 6),
            Text('Right-click gallery images to add them.',
                style: TextStyle(color: Colors.white30, fontSize: 11)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(6),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final path = _path(p, items[i]);
        final exists = path.isNotEmpty && File(path).existsSync();
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              final targetPage =
                  _readerMode == _ReaderMode.book ? i ~/ 2 : i;
              setState(() {
                _readMode = true;
                _currentPage = targetPage;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(targetPage);
              });
            },
            child: exists
                ? Image.file(File(path), fit: BoxFit.cover, gaplessPlayback: true)
                : Container(
                    color: Colors.white10,
                    child: const Icon(Icons.broken_image_outlined,
                        color: Colors.white24, size: 24)),
          ),
        );
      },
    );
  }

  // ── Comic reader ──────────────────────────────────────────────────

  Widget _buildReader(BuildContext context, CharacterProvider p,
      AlbumData album, List<GalleryItemData> items) {
    final pageCount = _pageCount(items.length);

    return Column(
      children: [
        // Title bar with mode toggles
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            border: Border(
                bottom: BorderSide(
                    color: AppTheme.accent.withValues(alpha: 0.35))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: AppTheme.accent, size: 20),
                tooltip: 'Back to gallery',
                onPressed: () {
                  _stopAutoPlay();
                  setState(() => _readMode = false);
                },
              ),
              Expanded(
                child: Text(album.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
              // Page counter
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${_currentPage + 1} / $pageCount',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ),
              // Auto-play controls
              GestureDetector(
                onTap: _showDelayDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_autoPlaySeconds}s',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _autoPlay ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 20,
                  color: _autoPlay ? AppTheme.accent : Colors.white54,
                ),
                tooltip: _autoPlay ? 'Pause' : 'Auto-play',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: () => _autoPlay
                    ? _stopAutoPlay()
                    : _startAutoPlay(pageCount),
              ),
              const SizedBox(width: 4),
              // Mode buttons
              _ReaderModeBtn(
                icon: Icons.swap_horiz_rounded,
                tooltip: 'Left to right',
                active: _readerMode == _ReaderMode.horizontal,
                onTap: () => _setReaderMode(_ReaderMode.horizontal),
              ),
              _ReaderModeBtn(
                icon: Icons.swap_vert_rounded,
                tooltip: 'Top to bottom',
                active: _readerMode == _ReaderMode.vertical,
                onTap: () => _setReaderMode(_ReaderMode.vertical),
              ),
              _ReaderModeBtn(
                icon: Icons.menu_book_rounded,
                tooltip: '2-page spread',
                active: _readerMode == _ReaderMode.book,
                onTap: () => _setReaderMode(_ReaderMode.book),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: Colors.white54,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (_, constraints) {
              _readerSize = constraints.biggest;
              return Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    final newZoom = (_zoomLevel - event.scrollDelta.dy * 0.005)
                        .clamp(1.0, 5.0);
                    _zoomAtCursor(event.localPosition, newZoom);
                  }
                },
                child: Stack(
                  children: [
                  // Content
                  if (_readerMode == _ReaderMode.vertical)
                    _buildVerticalReader(p, items)
                  else if (_readerMode == _ReaderMode.book)
                    _buildBookReader(p, items)
                  else
                    _buildHorizontalReader(p, items),
                  // ── Nav arrows ──────────────────────────────────
                  // Left arrow (horizontal / book)
                  if (_readerMode != _ReaderMode.vertical &&
                      _currentPage > 0)
                    Positioned(
                      left: 8, top: 0, bottom: 0,
                      child: Center(
                        child: _NavBtn(
                            icon: Icons.chevron_left_rounded,
                            onTap: _prevPage),
                      ),
                    ),
                  // Right arrow
                  if (_readerMode != _ReaderMode.vertical &&
                      _currentPage < pageCount - 1)
                    Positioned(
                      right: 8, top: 0, bottom: 0,
                      child: Center(
                        child: _NavBtn(
                            icon: Icons.chevron_right_rounded,
                            onTap: _nextPage),
                      ),
                    ),
                  // Up / down arrows for vertical mode — bottom-right
                  if (_readerMode == _ReaderMode.vertical)
                    Positioned(
                      right: 8, bottom: 8,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_currentPage > 0)
                            _NavBtn(
                                icon: Icons.expand_less_rounded,
                                onTap: _prevPage),
                          if (_currentPage > 0 && _currentPage < pageCount - 1)
                            const SizedBox(height: 4),
                          if (_currentPage < pageCount - 1)
                            _NavBtn(
                                icon: Icons.expand_more_rounded,
                                onTap: _nextPage),
                        ],
                      ),
                    ),
                  // ── Zoom panel ───────────────────────────────────
                  if (_readerMode == _ReaderMode.horizontal)
                    Positioned(
                      right: 8, bottom: 8,
                      child: _buildZoomPanel(),
                    ),
                  if (_readerMode == _ReaderMode.vertical)
                    Positioned(
                      right: 8, top: 0, bottom: 0,
                      child: Center(child: _buildZoomPanelVertical()),
                    ),
                ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildZoomPanel() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.zoom_out_rounded,
                color: AppTheme.textSecondary, size: 15),
            SizedBox(
              width: 180,
              child: Slider(
                value: _zoomLevel,
                min: 1.0,
                max: 5.0,
                activeColor: AppTheme.accent,
                inactiveColor: Colors.white24,
                onChanged: _setZoom,
              ),
            ),
            Icon(Icons.zoom_in_rounded,
                color: AppTheme.textSecondary, size: 15),
            const SizedBox(width: 6),
            Text(
              '${_zoomLevel.toStringAsFixed(1)}×',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
            ),
          ],
        ),
      );

  Widget _buildZoomPanelVertical() => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.zoom_in_rounded,
                color: AppTheme.textSecondary, size: 15),
            const SizedBox(height: 4),
            SizedBox(
              height: 160,
              width: 28,
              child: RotatedBox(
                quarterTurns: -1,
                child: Slider(
                  value: _zoomLevel,
                  min: 1.0,
                  max: 5.0,
                  activeColor: AppTheme.accent,
                  inactiveColor: Colors.white24,
                  onChanged: _setZoom,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Icon(Icons.zoom_out_rounded,
                color: AppTheme.textSecondary, size: 15),
            const SizedBox(height: 6),
            Text(
              '${_zoomLevel.toStringAsFixed(1)}×',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
            ),
          ],
        ),
      );

  Widget _buildHorizontalReader(
      CharacterProvider p, List<GalleryItemData> items) {
    return PageView.builder(
      controller: _pageCtrl,
      physics: _zoomLevel > 1.0
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      itemCount: items.length,
      onPageChanged: (i) {
        _resetZoom();
        setState(() => _currentPage = i);
      },
      itemBuilder: (_, i) {
        final item = items[i];
        final path = _path(p, item);
        final exists = path.isNotEmpty && File(path).existsSync();
        return Stack(
          children: [
            Positioned.fill(
              child: exists
                  ? InteractiveViewer(
                      transformationController: _transformCtrl,
                      scaleEnabled: false,
                      panEnabled: _zoomLevel > 1.0,
                      child: Image.file(File(path),
                          fit: BoxFit.contain, gaplessPlayback: true),
                    )
                  : const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white24, size: 48)),
            ),
            if (item.caption?.isNotEmpty ?? false)
              Positioned(
                bottom: 52, left: 24, right: 24,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(item.caption!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildVerticalReader(
      CharacterProvider p, List<GalleryItemData> items) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (_zoomLevel > 1.0) return;
        final v = details.primaryVelocity ?? 0;
        if (v < -300 && _currentPage < items.length - 1) {
          _nextPage();
        } else if (v > 300 && _currentPage > 0) {
          _prevPage();
        }
      },
      child: PageView.builder(
      controller: _pageCtrl,
      scrollDirection: Axis.vertical,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      onPageChanged: (i) {
        _resetZoom();
        setState(() => _currentPage = i);
      },
      itemBuilder: (_, i) {
        final item = items[i];
        final path = _path(p, item);
        final exists = path.isNotEmpty && File(path).existsSync();
        return Stack(
          children: [
            Positioned.fill(
              child: exists
                  ? InteractiveViewer(
                      transformationController: _transformCtrl,
                      scaleEnabled: false,
                      panEnabled: _zoomLevel > 1.0,
                      child: Image.file(File(path),
                          fit: BoxFit.contain, gaplessPlayback: true),
                    )
                  : const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white24, size: 48)),
            ),
            if (item.caption?.isNotEmpty ?? false)
              Positioned(
                bottom: 52, left: 24, right: 24,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(item.caption!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center),
                  ),
                ),
              ),
          ],
        );
      },
      ),
    );
  }

  Widget _buildBookReader(CharacterProvider p, List<GalleryItemData> items) {
    final spreadCount = (items.length + 1) ~/ 2;
    return PageView.builder(
      controller: _pageCtrl,
      itemCount: spreadCount,
      onPageChanged: (i) => setState(() => _currentPage = i),
      itemBuilder: (_, spread) {
        final li = spread * 2;
        final ri = li + 1;
        return Row(
          children: [
            Expanded(
                child: _buildSpreadHalf(
                    p, li < items.length ? items[li] : null)),
            Container(width: 1, color: Colors.white12),
            Expanded(
                child: _buildSpreadHalf(
                    p, ri < items.length ? items[ri] : null)),
          ],
        );
      },
    );
  }

  Widget _buildSpreadHalf(CharacterProvider p, GalleryItemData? item) {
    if (item == null) return const ColoredBox(color: Colors.black);
    final path = _path(p, item);
    final exists = path.isNotEmpty && File(path).existsSync();
    return Stack(
      fit: StackFit.expand,
      children: [
        exists
            ? Image.file(File(path), fit: BoxFit.contain, gaplessPlayback: true)
            : const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: Colors.white24, size: 32)),
        if (item.caption?.isNotEmpty ?? false)
          Positioned(
            bottom: 8, left: 8, right: 8,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(item.caption!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
      ],
    );
  }

  // ── Manage ────────────────────────────────────────────────────────

  Widget _buildManage(BuildContext context, CharacterProvider p,
      AlbumData album, List<GalleryItemData> items) {
    return Column(
      children: [
        _buildSubBar(
          context,
          title: 'Manage — ${album.name}',
          onBack: () => setState(() => _manageMode = false),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left panel ───────────────────────────────
              SizedBox(
                width: 240,
                child: _buildManageLeftPanel(p, album, items),
              ),
              // Vertical separator
              VerticalDivider(
                  width: 1, thickness: 1, color: AppTheme.borderColor),
              // ── Right panel ──────────────────────────────
              Expanded(
                child: Column(
                  children: [
                    // Toggle bar
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        border: Border(
                            bottom: BorderSide(color: AppTheme.borderColor)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${items.length} image${items.length == 1 ? '' : 's'}',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          const Spacer(),
                          Text(
                            _manageGrid
                                ? 'Long-press to reorder'
                                : 'Drag to reorder',
                            style: TextStyle(
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.5),
                                fontSize: 11),
                          ),
                          const SizedBox(width: 8),
                          _ToggleBtn(
                            icon: Icons.view_list_rounded,
                            active: !_manageGrid,
                            tooltip: 'List view',
                            onTap: () => setState(() => _manageGrid = false),
                          ),
                          const SizedBox(width: 4),
                          _ToggleBtn(
                            icon: Icons.grid_view_rounded,
                            active: _manageGrid,
                            tooltip: 'Grid view',
                            onTap: () => setState(() => _manageGrid = true),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Text('No images yet.',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14)))
                          : _manageGrid
                              ? _buildManageGrid(p, album, items)
                              : _buildManageList(p, album, items),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editDescription(BuildContext context) async {
    final tmp = TextEditingController(text: _descCtrl.text);
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Description',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: tmp,
            maxLines: 10,
            autofocus: true,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Optional description…',
              hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  fontSize: 13),
              filled: true,
              fillColor: AppTheme.bgSurface,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.accent),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, tmp.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent),
            child: const Text('Save',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    tmp.dispose();
    if (saved != null) setState(() => _descCtrl.text = saved);
  }

  void _openTagPicker(CharacterProvider p) {
    _tagPickerEntry?.remove();
    _tagPickerEntry = OverlayEntry(builder: (_) => _buildTagPickerOverlay(p));
    Overlay.of(context).insert(_tagPickerEntry!);
    setState(() => _tagPickerOpen = true);
  }

  void _closeTagPicker() {
    _tagPickerEntry?.remove();
    _tagPickerEntry = null;
    _tagSearchCtrl.clear();
    setState(() => _tagPickerOpen = false);
  }

  Widget _buildTagPickerOverlay(CharacterProvider p) {
    final query = _tagSearchCtrl.text.toLowerCase();
    final filtered = p.allAlbumTags
        .where((t) => query.isEmpty || t.name.toLowerCase().contains(query))
        .toList();

    return Stack(
      children: [
        // Barrier — dismiss on tap outside
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closeTagPicker,
          ),
        ),
        CompositedTransformFollower(
          link: _tagPickerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: GestureDetector(
            onTap: () {}, // absorb taps so barrier doesn't dismiss
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 210,
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                      child: TextField(
                        controller: _tagSearchCtrl,
                        autofocus: true,
                        onChanged: (_) {
                          setState(() {});
                          _tagPickerEntry?.markNeedsBuild();
                        },
                        style: TextStyle(
                            color: AppTheme.textPrimary, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search tags…',
                          hintStyle: TextStyle(
                              color: AppTheme.textSecondary
                                  .withValues(alpha: 0.4),
                              fontSize: 12),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 14, color: AppTheme.textSecondary),
                          suffixIcon: _tagSearchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear,
                                      size: 12,
                                      color: AppTheme.textSecondary),
                                  onPressed: () {
                                    _tagSearchCtrl.clear();
                                    setState(() {});
                                    _tagPickerEntry?.markNeedsBuild();
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 7),
                          filled: true,
                          fillColor: AppTheme.bgSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: AppTheme.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: AppTheme.borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.accent),
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: AppTheme.borderColor),
                    // Tag list
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'No tags match.',
                          style: TextStyle(
                              color: AppTheme.textSecondary
                                  .withValues(alpha: 0.5),
                              fontSize: 12),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final tag = filtered[i];
                            final on = _pendingTagIds.contains(tag.id);
                            return InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                setState(() {
                                  if (on)
                                    _pendingTagIds.remove(tag.id);
                                  else
                                    _pendingTagIds.add(tag.id);
                                });
                                _tagPickerEntry?.markNeedsBuild();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(
                                        color: tag.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        tag.name,
                                        style: TextStyle(
                                          color: on
                                              ? AppTheme.textPrimary
                                              : AppTheme.textSecondary,
                                          fontSize: 12,
                                          fontWeight: on
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (on)
                                      Icon(Icons.check_rounded,
                                          size: 14, color: AppTheme.accent),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManageLeftPanel(CharacterProvider p, AlbumData album,
      List<GalleryItemData> items) {
    final coverPath = items.isNotEmpty ? _path(p, items.first) : '';
    final hasCover = coverPath.isNotEmpty && File(coverPath).existsSync();

    final chars = items
        .map((item) => _char(p, item))
        .whereType<CharacterData>()
        .toSet()
        .toList();

    void doSave() {
      _closeTagPicker();
      final name = _nameCtrl.text.trim();
      if (name.isNotEmpty) p.renameAlbum(album, name);
      p.updateAlbumDescription(album, _descCtrl.text.trim());
      p.setAlbumTags(album, _pendingTagIds.toList());
      setState(() => _manageMode = false);
    }

    void doCancel() {
      _closeTagPicker();
      setState(() => _manageMode = false);
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cover ───────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: hasCover
                ? ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 380),
                    child: Image.file(File(coverPath),
                        width: double.infinity,
                        fit: BoxFit.contain,
                        gaplessPlayback: true),
                  )
                : AspectRatio(
                    aspectRatio: 9 / 16,
                    child: Container(
                      color: AppTheme.bgSurface,
                      child: Center(
                        child: Icon(Icons.photo_album_outlined,
                            size: 40,
                            color: AppTheme.textSecondary
                                .withValues(alpha: 0.25)),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // ── Name ────────────────────────────────────────
          _FieldLabel('Name'),
          const SizedBox(height: 4),
          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              filled: true,
              fillColor: AppTheme.bgSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.accent),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Description ─────────────────────────────────
          Row(
            children: [
              _FieldLabel('Description'),
              const Spacer(),
              GestureDetector(
                onTap: () => _editDescription(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded,
                          size: 11, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text('Edit',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _editDescription(context),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Text(
                _descCtrl.text.isEmpty ? 'Tap Edit to add a description…' : _descCtrl.text,
                style: TextStyle(
                  color: _descCtrl.text.isEmpty
                      ? AppTheme.textSecondary.withValues(alpha: 0.4)
                      : AppTheme.textPrimary,
                  fontSize: 12,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ── Tags ────────────────────────────────────────
          _FieldLabel('Tags'),
          const SizedBox(height: 8),
          if (p.allAlbumTags.isEmpty)
            Text('No album tags yet — create some in Album Tags.',
                style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.45),
                    fontSize: 11))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Assigned tag chips
                ...p.allAlbumTags
                    .where((t) => _pendingTagIds.contains(t.id))
                    .map((tag) => TagChip(
                          tag: tag,
                          selected: true,
                          onDeleted: () =>
                              setState(() => _pendingTagIds.remove(tag.id)),
                        )),
                // "+" chip anchored for the overlay
                CompositedTransformTarget(
                  link: _tagPickerLink,
                  child: GestureDetector(
                    onTap: () => _tagPickerOpen
                        ? _closeTagPicker()
                        : _openTagPicker(p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: _tagPickerOpen
                            ? AppTheme.accent.withValues(alpha: 0.15)
                            : AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _tagPickerOpen
                              ? AppTheme.accent
                              : AppTheme.borderColor,
                          width: _tagPickerOpen ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _tagPickerOpen
                                ? Icons.close_rounded
                                : Icons.add_rounded,
                            size: 13,
                            color: _tagPickerOpen
                                ? AppTheme.accent
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _tagPickerOpen ? 'Close' : 'Tag',
                            style: TextStyle(
                              fontSize: 12,
                              color: _tagPickerOpen
                                  ? AppTheme.accent
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

          // ── Characters ──────────────────────────────────
          if (chars.isNotEmpty) ...[
            const SizedBox(height: 20),
            _FieldLabel('Characters'),
            const SizedBox(height: 8),
            ...chars.map((char) {
              final charItem = items
                  .where((item) => item.characterId == char.id)
                  .firstOrNull;
              final avatarPath =
                  charItem != null ? _path(p, charItem) : '';
              final hasAvatar =
                  avatarPath.isNotEmpty && File(avatarPath).existsSync();
              final imgCount =
                  items.where((i) => i.characterId == char.id).length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: hasAvatar
                          ? Image.file(File(avatarPath),
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              gaplessPlayback: true)
                          : Container(
                              width: 40, height: 40,
                              color: AppTheme.bgSurface,
                              child: Icon(Icons.person_outline,
                                  size: 20,
                                  color: AppTheme.textSecondary)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(char.name,
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 1),
                          Text(
                            '$imgCount image${imgCount == 1 ? '' : 's'}',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
        ),
        ),
        // ── Save / Cancel ────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            border: Border(top: BorderSide(color: AppTheme.borderColor)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: doCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(color: AppTheme.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: doSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManageList(CharacterProvider p, AlbumData album,
      List<GalleryItemData> items) {
    return Theme(
      data: ThemeData.dark(),
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        onReorder: (oldIdx, newIdx) {
          if (newIdx > oldIdx) newIdx--;
          p.reorderAlbumItems(album, oldIdx, newIdx);
        },
        itemBuilder: (_, i) {
          final item = items[i];
          final char = _char(p, item);
          final path = char != null ? item.filePath(char.folderPath) : '';
          final exists = path.isNotEmpty && File(path).existsSync();
          return ListTile(
            key: ValueKey(item.id),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: exists
                      ? Image.file(File(path),
                          width: 56, height: 56,
                          fit: BoxFit.cover, gaplessPlayback: true)
                      : Container(
                          width: 56, height: 56,
                          color: Colors.white10,
                          child: const Icon(Icons.broken_image_outlined,
                              size: 20, color: Colors.white30)),
                ),
                Positioned(
                  top: 2, left: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            title: Text(char?.name ?? 'Unknown',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
            subtitle: item.caption?.isNotEmpty == true
                ? Text(item.caption!,
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (i == 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Cover',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w500)),
                  ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      size: 18, color: Colors.redAccent),
                  onPressed: () => p.removeItemFromAlbum(album, item.id),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                ReorderableDragStartListener(
                  index: i,
                  child: Icon(Icons.drag_handle_rounded,
                      size: 20, color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildManageGrid(CharacterProvider p, AlbumData album,
      List<GalleryItemData> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final char = _char(p, item);
        final path = char != null ? item.filePath(char.folderPath) : '';
        final exists = path.isNotEmpty && File(path).existsSync();
        final isDragging = _gridDragIndex == i;
        final isDropTarget = _gridDropIndex == i && _gridDragIndex != i;

        Widget card = Stack(
          fit: StackFit.expand,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDropTarget
                      ? AppTheme.accent
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: exists
                          ? Image.file(File(path),
                              fit: BoxFit.cover, gaplessPlayback: true)
                          : Container(
                              color: Colors.white10,
                              child: const Icon(Icons.broken_image_outlined,
                                  size: 28, color: Colors.white30)),
                    ),
                    Container(
                      color: AppTheme.bgCard,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Text(
                        char?.name ?? 'Unknown',
                        style: TextStyle(
                            color: AppTheme.textPrimary, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Order badge
            Positioned(
              top: 5, left: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            // Cover badge
            if (i == 0)
              Positioned(
                top: 5, right: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Cover',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            // Drag handle hint (top-right when not cover)
            if (i != 0)
              Positioned(
                top: 5, right: 5,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.drag_indicator_rounded,
                      size: 13, color: Colors.white70),
                ),
              ),
            // Remove button
            Positioned(
              bottom: 28, right: 4,
              child: GestureDetector(
                onTap: () => p.removeItemFromAlbum(album, item.id),
                child: Container(
                  width: 24, height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: Colors.redAccent),
                ),
              ),
            ),
          ],
        );

        return LongPressDraggable<int>(
          data: i,
          delay: const Duration(milliseconds: 200),
          onDragStarted: () => setState(() => _gridDragIndex = i),
          onDragEnd: (_) => setState(() {
            _gridDragIndex = null;
            _gridDropIndex = null;
          }),
          feedback: SizedBox(
            width: 120, height: 120,
            child: Opacity(
              opacity: 0.85,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: exists
                      ? Image.file(File(path),
                          fit: BoxFit.cover, gaplessPlayback: true)
                      : Container(color: Colors.white10),
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: card),
          child: DragTarget<int>(
            onWillAcceptWithDetails: (d) {
              if (d.data != i) setState(() => _gridDropIndex = i);
              return d.data != i;
            },
            onLeave: (_) => setState(() => _gridDropIndex = null),
            onAcceptWithDetails: (d) {
              setState(() {
                _gridDragIndex = null;
                _gridDropIndex = null;
              });
              p.reorderAlbumItems(album, d.data, i);
            },
            builder: (_, __, ___) => AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: isDragging ? 0.25 : 1.0,
              child: card,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubBar(BuildContext context,
      {required String title, required VoidCallback onBack}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(
            bottom: BorderSide(
                color: AppTheme.accent.withValues(alpha: 0.35))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: AppTheme.accent, size: 20),
            tooltip: 'Back',
            onPressed: onBack,
          ),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────

class _ReaderModeBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _ReaderModeBtn(
      {required this.icon,
      required this.tooltip,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.accent.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: active
                    ? AppTheme.accent.withValues(alpha: 0.6)
                    : Colors.transparent,
              ),
            ),
            child: Icon(icon,
                size: 18,
                color: active ? AppTheme.accent : Colors.white54),
          ),
        ),
      );
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      );
}

class _DetailBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool dim;

  const _DetailBtn(
      {required this.label,
      required this.icon,
      required this.onTap,
      this.dim = false});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: dim
                  ? AppTheme.borderColor
                  : AppTheme.accent.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 13,
                  color: dim ? AppTheme.textSecondary : AppTheme.accent),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color:
                          dim ? AppTheme.textSecondary : AppTheme.accent,
                      fontSize: 12)),
            ],
          ),
        ),
      );
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text(value,
                  style:
                      TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
            ),
          ],
        ),
      );
}

class _MetaRowWidget extends StatelessWidget {
  final String label;
  final Widget child;

  const _MetaRowWidget({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(label,
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      );
}

class _CharBadge extends StatelessWidget {
  final CharacterData char;
  final VoidCallback? onTap;

  const _CharBadge({required this.char, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
          child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppTheme.raceColor(char.race).withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AppTheme.raceColor(char.race),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(char.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
        ),
      );
}

// ── Field label helper ────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      );
}

// ── Toggle button helper ──────────────────────────────────────────

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.accent.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: active ? AppTheme.accent.withValues(alpha: 0.4) : Colors.transparent,
              ),
            ),
            child: Icon(icon,
                size: 15,
                color: active ? AppTheme.accent : AppTheme.textSecondary),
          ),
        ),
      );
}

// ── Album tag assignment dialog ────────────────────────────────────

class _AlbumTagsDialog extends StatefulWidget {
  final AlbumData album;
  final CharacterProvider provider;
  const _AlbumTagsDialog({required this.album, required this.provider});

  @override
  State<_AlbumTagsDialog> createState() => _AlbumTagsDialogState();
}

class _AlbumTagsDialogState extends State<_AlbumTagsDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.album.tagIds);
  }

  @override
  Widget build(BuildContext context) {
    final tags = widget.provider.allAlbumTags;
    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      title: Text('Tags for "${widget.album.name}"',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
      content: SizedBox(
        width: 320,
        child: tags.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No album tags exist yet. Create some in Album Tags.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((tag) {
                  final on = _selected.contains(tag.id);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (on) _selected.remove(tag.id);
                      else _selected.add(tag.id);
                    }),
                    child: TagChip(tag: tag, selected: on),
                  );
                }).toList(),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            await widget.provider.setAlbumTags(widget.album, _selected.toList());
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
