import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/character_provider.dart';
import '../theme/app_theme.dart';

class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('New Collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Collection name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await context.read<CharacterProvider>().addCollection(name);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Delete Collection?'),
        content: Text(
            'Delete "$name"? Characters in this collection will not be deleted — '
            'they will just lose their collection assignment.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await context.read<CharacterProvider>().deleteCollection(id);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        final collections = provider.allCollections;
        return Scaffold(
          appBar: AppBar(title: const Text('Collections')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddDialog(context),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('New Collection'),
          ),
          body: collections.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_outlined,
                          size: 64,
                          color: AppTheme.textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text('No collections yet',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    final col = collections[index];
                    final count =
                        provider.getCharacterCountForCollection(col.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.folder,
                              color: AppTheme.accent, size: 24),
                        ),
                        title: Text(col.name),
                        subtitle: Text(
                            '$count character${count == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: AppTheme.textSecondary)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppTheme.textSecondary),
                          onPressed: () =>
                              _confirmDelete(context, col.id, col.name),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
