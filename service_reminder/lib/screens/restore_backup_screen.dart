import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/backup_providers.dart';
import '../providers/customer_providers.dart';
import '../services/backup/backup_service.dart';

class RestoreBackupScreen extends ConsumerStatefulWidget {
  const RestoreBackupScreen({super.key});

  @override
  ConsumerState<RestoreBackupScreen> createState() => _RestoreBackupScreenState();
}

class _RestoreBackupScreenState extends ConsumerState<RestoreBackupScreen> {
  late Future<List<DriveBackupFile>> _backupsFuture;
  bool _isRestoring = false;

  static final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    _backupsFuture = ref.read(backupServiceProvider).listBackups();
  }

  Future<void> _confirmAndRestore(DriveBackupFile backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'This will replace every customer and service record currently on this device with '
          'the contents of the backup from ${_dateFormat.format(backup.createdTime)}.\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRestoring = true);
    try {
      await ref.read(backupServiceProvider).restore(backup.id);
      ref.invalidate(customersListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restore from Backup')),
      body: FutureBuilder<List<DriveBackupFile>>(
        future: _backupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load backups: ${snapshot.error}'));
          }

          final backups = snapshot.data!;
          if (backups.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No backups yet. Use "Backup now" in Settings first.', textAlign: TextAlign.center),
              ),
            );
          }

          return AbsorbPointer(
            absorbing: _isRestoring,
            child: ListView.separated(
              itemCount: backups.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final backup = backups[index];
                return ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(_dateFormat.format(backup.createdTime)),
                  subtitle: Text(backup.name),
                  trailing: _isRestoring
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isRestoring ? null : () => _confirmAndRestore(backup),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
