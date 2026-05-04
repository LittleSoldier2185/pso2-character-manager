import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/character_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/character_card.dart';
import 'character_detail_screen.dart';

class AppliedScreen extends StatelessWidget {
  const AppliedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        final applied = provider.appliedCharacters;

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
                  // No const — accent is dynamic
                  Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text(
                    '${applied.length} of 50 slots used',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: applied.length / 50,
                        backgroundColor: AppTheme.bgSurface,
                        valueColor: AlwaysStoppedAnimation(
                          applied.length > 45
                              ? Colors.orange
                              : AppTheme.accent,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _GameFolderStatus(provider: provider),
                ],
              ),
            ),
            Expanded(
              child: applied.isEmpty
                  ? _buildEmpty()
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        childAspectRatio: 0.70,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: applied.length,
                      itemBuilder: (context, index) {
                        final c = applied[index];
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No characters applied yet',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Click the + button on any character card to apply it',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _GameFolderStatus extends StatelessWidget {
  final CharacterProvider provider;
  const _GameFolderStatus({required this.provider});

  @override
  Widget build(BuildContext context) {
    final hasFolder = provider.gameFolderPath != null;
    return GestureDetector(
      onTap: () => _showFolderDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: hasFolder
              ? AppTheme.accent.withOpacity(0.1)
              : AppTheme.accentGold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: hasFolder
                ? AppTheme.accent.withOpacity(0.4)
                : AppTheme.accentGold.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFolder ? Icons.folder_rounded : Icons.folder_off_outlined,
              size: 13,
              color: hasFolder ? AppTheme.accent : AppTheme.accentGold,
            ),
            const SizedBox(width: 5),
            Text(
              hasFolder ? 'Game folder set' : 'Set game folder',
              style: TextStyle(
                fontSize: 11,
                color: hasFolder ? AppTheme.accent : AppTheme.accentGold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFolderDialog(BuildContext context) {
    final controller =
        TextEditingController(text: provider.gameFolderPath ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('PSO2 game folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set the path to your PSO2 character data folder.\n\n'
              'Example: C:\\PSO2\\pso2_bin\\data\\win32',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'C:\\PSO2\\pso2_bin\\data\\win32',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final path = controller.text.trim();
              if (path.isNotEmpty) {
                await provider.setGameFolderPath(path);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
