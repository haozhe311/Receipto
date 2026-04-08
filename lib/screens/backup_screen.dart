import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/providers/transaction_provider.dart';
import 'package:receipto/services/backup_service.dart';
import 'package:receipto/services/database_helper.dart';

/// Screen for backing up and restoring transactions via Google Drive.
///
/// All actions are user-triggered — no automatic/scheduled sync.
/// Data is exported as a JSON file to the user's own Google Drive.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  DateTime? _lastBackupDate;

  @override
  void initState() {
    super.initState();
    _loadLastBackupDate();
  }

  Future<void> _loadLastBackupDate() async {
    final raw = await DatabaseHelper.instance.getSetting('last_backup_date');
    if (raw != null && mounted) {
      setState(() => _lastBackupDate = DateTime.tryParse(raw));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info card
          _InfoCard(),
          const SizedBox(height: 16),

          // Last backup status
          _LastBackupCard(lastBackupDate: _lastBackupDate),
          const SizedBox(height: 16),

          // Backup button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isBackingUp || _isRestoring ? null : _performBackup,
              icon: _isBackingUp
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(
                _isBackingUp ? 'Backing up...' : 'Backup to Google Drive',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Restore button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  _isBackingUp || _isRestoring ? null : _showRestoreDialog,
              icon: _isRestoring
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download),
              label: Text(
                _isRestoring ? 'Loading...' : 'Restore from Google Drive',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Signed in account
          if (BackupService.currentUserEmail != null)
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Signed in as'),
              subtitle: Text(BackupService.currentUserEmail!),
              trailing: TextButton(
                onPressed: () async {
                  await BackupService.signOut();
                  if (mounted) setState(() {});
                },
                child: const Text('Sign out'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _performBackup() async {
    setState(() => _isBackingUp = true);

    try {
      final success = await BackupService.backup();
      if (!mounted) return;

      if (success) {
        await _loadLastBackupDate();
        _showSnackBar('Backup successful!', Colors.green);
      } else {
        _showSnackBar('Backup cancelled', Colors.orange);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Backup failed: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _showRestoreDialog() async {
    setState(() => _isRestoring = true);

    try {
      final backups = await BackupService.listBackups();
      if (!mounted) return;

      if (backups.isEmpty) {
        _showSnackBar('No backup files found in your Google Drive', Colors.orange);
        return;
      }

      final selected = await showModalBottomSheet<drive.File>(
        context: context,
        builder: (ctx) => _BackupListSheet(backups: backups),
      );

      if (selected == null || !mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore Backup?'),
          content: Text(
            'This will REPLACE all ${context.read<TransactionProvider>().transactionCount} current transactions '
            'with the data from "${selected.name}".\n\nThis cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Restore'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      await BackupService.restore(selected.id!);
      if (!mounted) return;

      // Refresh the transaction list on the home screen
      await context.read<TransactionProvider>().loadTransactions();
      if (!mounted) return;

      _showSnackBar('Restore successful!', Colors.green);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Restore failed: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}

/// Informational card at the top of the backup screen.
class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppTheme.gold.withAlpha(200)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Backups are saved as JSON files to your own Google Drive. '
              'Your data never passes through any third-party server. '
              'All actions are manual — there is no automatic sync.',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the timestamp of the most recent backup.
class _LastBackupCard extends StatelessWidget {
  final DateTime? lastBackupDate;

  const _LastBackupCard({required this.lastBackupDate});

  @override
  Widget build(BuildContext context) {
    final formatted = lastBackupDate != null
        ? DateFormat('dd MMM yyyy, h:mm a').format(lastBackupDate!)
        : 'Never';

    return Card(
      child: ListTile(
        leading: Icon(
          Icons.history,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Last Backup'),
        subtitle: Text(formatted),
      ),
    );
  }
}

/// Bottom sheet listing available backup files for restoration.
class _BackupListSheet extends StatelessWidget {
  final List<drive.File> backups;

  const _BackupListSheet({required this.backups});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.cloud_download),
                const SizedBox(width: 8),
                Text(
                  'Select a backup to restore',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final file = backups[index];
                final modifiedAt = file.modifiedTime != null
                    ? DateFormat('dd MMM yyyy, h:mm a').format(
                        file.modifiedTime!.toLocal(),
                      )
                    : 'Unknown';

                return ListTile(
                  leading: const Icon(Icons.description),
                  title: Text(
                    file.name ?? 'Unnamed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(modifiedAt),
                  onTap: () => Navigator.of(context).pop(file),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
