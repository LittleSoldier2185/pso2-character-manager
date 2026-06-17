import 'package:flutter/material.dart';
import '../services/migration_service.dart';
import '../theme/app_theme.dart';

class MigrationScreen extends StatefulWidget {
  final Future<void> Function() onComplete;
  const MigrationScreen({super.key, required this.onComplete});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  String _status = 'Preparing migration…';
  int _done = 0;
  int _total = 0;
  bool _finished = false;
  MigrationResult? _result;

  @override
  void initState() {
    super.initState();
    _runMigration();
  }

  Future<void> _runMigration() async {
    final result = await MigrationService.run(
      onProgress: (message, done, total) {
        if (mounted) {
          setState(() {
            _status = message;
            _done = done;
            _total = total;
          });
        }
      },
    );
    if (mounted) {
      setState(() {
        _result = result;
        _finished = true;
        _status = result.hasErrors
            ? 'Migration completed with ${result.failed.length} error(s).'
            : 'Migration complete! ${result.succeeded} characters migrated.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data Migration',
                style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Migrating your character data to the new format.\nPlease do not close the app.',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              if (!_finished) ...[
                LinearProgressIndicator(
                  value: _total > 0 ? _done / _total : null,
                  backgroundColor: AppTheme.bgSurface,
                  color: AppTheme.accent,
                ),
                const SizedBox(height: 12),
                Text(
                  _status,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ] else ...[
                Icon(
                  _result!.hasErrors
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  color: _result!.hasErrors
                      ? AppTheme.accentGold
                      : Colors.green,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  _status,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13),
                ),
                if (_result!.hasErrors) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Failed: ${_result!.failed.join(', ')}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onComplete,
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
