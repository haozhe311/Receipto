import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/providers/account_provider.dart';
import 'package:receipto/providers/budget_provider.dart';
import 'package:receipto/providers/category_provider.dart';
import 'package:receipto/providers/goal_provider.dart';
import 'package:receipto/providers/recurring_provider.dart';
import 'package:receipto/providers/transaction_provider.dart';
import 'package:receipto/services/backup_service.dart';
import 'package:receipto/services/database_helper.dart';

/// Screen for backing up and restoring transactions via Google Drive.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isExporting = false;
  bool _isImporting = false;
  DateTime? _lastBackupDate;
  DateTime? _lastAutoBackupDate;
  bool _autoBackupEnabled = true;

  /// True while any backup/restore/import/export operation is in flight, so all
  /// action buttons are disabled together.
  bool get _busy => _isBackingUp || _isRestoring || _isExporting || _isImporting;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = DatabaseHelper.instance;
    final backupRaw  = await db.getSetting('last_backup_date');
    final autoRaw    = await db.getSetting(BackupService.settingLastTimestamp);
    final enabledRaw = await db.getSetting(BackupService.settingAutoEnabled);

    if (mounted) {
      setState(() {
        _lastBackupDate     = backupRaw != null ? DateTime.tryParse(backupRaw) : null;
        _lastAutoBackupDate = autoRaw   != null ? DateTime.tryParse(autoRaw)   : null;
        _autoBackupEnabled  = enabledRaw != 'false';
      });
    }
  }

  Future<void> _setAutoBackup(bool value) async {
    await DatabaseHelper.instance.setSetting(
      BackupService.settingAutoEnabled,
      value.toString(),
    );
    if (mounted) setState(() => _autoBackupEnabled = value);
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

          // Auto-backup toggle
          Container(
            decoration: BoxDecoration(
              color: AppTheme.glassRowFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.glassBorderSoft),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _autoBackupEnabled,
                  onChanged: _setAutoBackup,
                  activeColor: AppTheme.gold,
                  title: const Text(
                    'Auto-backup (every 24 hours)',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    _lastAutoBackupDate != null
                        ? 'Last auto-backup: ${DateFormat('dd MMM yyyy, h:mm a').format(_lastAutoBackupDate!)}'
                        : 'Auto-backup: never run yet',
                    style: const TextStyle(
                      color: Color(0xFF8888AA),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Last manual backup status
          _LastBackupCard(lastBackupDate: _lastBackupDate),
          const SizedBox(height: 16),

          // Backup button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _performBackup,
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
                  _busy ? null : _showRestoreDialog,
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

          // ── Local file (works offline; no Google account needed) ──────────
          Row(
            children: [
              const Expanded(child: Divider(color: AppTheme.glassBorderSoft)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR USE A FILE ON THIS DEVICE',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: AppTheme.glassBorderSoft)),
            ],
          ),
          const SizedBox(height: 16),

          // Export to file
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _exportToFile,
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt),
              label: Text(_isExporting ? 'Exporting...' : 'Export to file'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Import from file
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _importFromFile,
              icon: _isImporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_open),
              label: Text(_isImporting ? 'Importing...' : 'Import from file'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Import replaces all current data with the file\'s contents. '
            'Use this to load a backup that isn\'t in your Drive.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),

          // Signed-in account
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
        await _loadSettings();
        _showSnackBar('Backup successful!', Colors.green);
      } else {
        _showSnackBar('Backup cancelled', Colors.orange);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Backup failed: $e', Colors.red);
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
        _showSnackBar(
          'No backup files found in your Google Drive',
          Colors.orange,
        );
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
            'This will REPLACE your current data (transactions, categories, '
            'budgets, goals, recurring transactions, and accounts) with the '
            'data from "${selected.name}".\n\nThis cannot be undone.',
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

      await _refreshAllProviders();
      if (!mounted) return;

      _showSnackBar('Restore successful!', Colors.green);
    } catch (e) {
      if (mounted) _showSnackBar('Restore failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  /// Reloads every provider whose data a restore/import may have replaced.
  Future<void> _refreshAllProviders() async {
    if (!mounted) return;
    await Future.wait([
      context.read<TransactionProvider>().loadTransactions(),
      context.read<CategoryProvider>().loadCategories(),
      context.read<BudgetProvider>().loadBudgets(),
      context.read<GoalProvider>().loadGoals(),
      context.read<RecurringProvider>().loadRecurring(),
      context.read<AccountProvider>().loadAccounts(),
    ]);
  }

  /// Exports all data to a JSON file the user saves anywhere on the device
  /// (Downloads, etc.) via the system "Save as" dialog. Same format as the
  /// Google Drive backup, so it can be re-imported here.
  Future<void> _exportToFile() async {
    setState(() => _isExporting = true);
    try {
      final jsonString = await DatabaseHelper.instance.getAllDataAsJson();
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      final fileName =
          'receipto_backup_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.json';

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Receipto backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      if (!mounted) return;
      _showSnackBar(
        savedPath == null ? 'Export cancelled' : 'Backup saved to file',
        savedPath == null ? Colors.orange : Colors.green,
      );
    } catch (e) {
      if (mounted) _showSnackBar('Export failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Lets the user pick a Receipto JSON backup from device storage and restores
  /// it, replacing all current data. Works offline with no Google account.
  Future<void> _importFromFile() async {
    // Pick before touching state, so cancelling is a clean no-op.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final picked = result.files.single;
    String jsonString;
    try {
      if (picked.bytes != null) {
        jsonString = utf8.decode(picked.bytes!);
      } else if (picked.path != null) {
        jsonString = await File(picked.path!).readAsString();
      } else {
        _showSnackBar('Could not read the selected file', Colors.red);
        return;
      }
    } catch (e) {
      if (mounted) _showSnackBar('Could not read the file: $e', Colors.red);
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import & Replace Data?'),
        content: Text(
          'This will REPLACE your current data (transactions, categories, '
          'budgets, goals, recurring transactions, and accounts) with the '
          'contents of "${picked.name}".\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isImporting = true);
    try {
      await DatabaseHelper.instance.importAllDataFromJson(jsonString);
      if (!mounted) return;
      await _refreshAllProviders();
      if (!mounted) return;
      _showSnackBar('Import successful!', Colors.green);
    } catch (e) {
      if (mounted) _showSnackBar('Import failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}

// ── Static widgets ─────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glassRowFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppTheme.gold.withAlpha(200)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Backups are saved as JSON files to your own Google Drive. '
              'Your data never passes through any third-party server.',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

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
