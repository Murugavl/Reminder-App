import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/backup_providers.dart';
import '../providers/database_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/settings_providers.dart';
import '../services/backup/backup_service.dart';
import '../services/reminders/overdue_reminder_checker.dart';
import 'restore_backup_screen.dart';

const _reminderIntervalChoices = [1, 2, 3, 6, 12];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isChecking = false;
  bool _isSigningIn = false;
  bool _isBackingUp = false;
  bool _isTogglingAutoBackup = false;

  static final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  Future<void> _setDefaultIntervalMonths(int months) async {
    await ref.read(reminderIntervalPreferencesProvider).setDefaultIntervalMonths(months);
    ref.invalidate(defaultReminderIntervalMonthsProvider);
  }

  Future<void> _setSoundAndVibrationEnabled(bool enabled) async {
    await ref.read(notificationPreferencesProvider).setSoundAndVibrationEnabled(enabled);
    ref.invalidate(soundAndVibrationEnabledProvider);
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    await ref.read(themePreferencesProvider).setThemeMode(mode);
    ref.invalidate(themeModeProvider);
  }

  Future<void> _signIn() async {
    setState(() => _isSigningIn = true);
    try {
      await ref.read(backupServiceProvider).signIn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(backupServiceProvider).signOut();
  }

  Future<void> _backupNow() async {
    setState(() => _isBackingUp = true);
    try {
      final outcome = await ref.read(backupServiceProvider).backupNow(interactive: true);
      if (!mounted) return;
      switch (outcome) {
        case BackupSucceeded(:final uploadedAt):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backup uploaded (${_dateFormat.format(uploadedAt)}).')),
          );
        case BackupFailed(:final message):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backup failed: $message')),
          );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _setAutoBackupEnabled(bool enabled) async {
    final backupService = ref.read(backupServiceProvider);
    final scheduler = ref.read(weeklyBackupSchedulerProvider);
    final preferences = ref.read(backupPreferencesProvider);

    setState(() => _isTogglingAutoBackup = true);
    try {
      if (enabled) {
        // Turning this on is a direct user interaction, so it's a valid
        // place to trigger sign-in/consent if we don't already have it.
        if (backupService.currentAccount == null) {
          await backupService.signIn();
        }
        final outcome = await backupService.backupNow(interactive: true);
        if (outcome is BackupFailed) {
          throw Exception(outcome.message);
        }
        await scheduler.enable();
        await preferences.setAutoBackupEnabled(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Automatic weekly backup turned on.')),
          );
        }
      } else {
        await scheduler.disable();
        await preferences.setAutoBackupEnabled(false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update automatic backup: $e')),
        );
      }
    } finally {
      ref.invalidate(autoBackupEnabledProvider);
      if (mounted) setState(() => _isTogglingAutoBackup = false);
    }
  }

  Future<void> _checkNow() async {
    setState(() => _isChecking = true);
    try {
      final soundAndVibrationEnabled = await ref.read(soundAndVibrationEnabledProvider.future);
      final overdueCount = await checkOverdueRemindersAndNotify(
        repository: ref.read(customerRepositoryProvider),
        notifications: ref.read(notificationServiceProvider),
        soundAndVibrationEnabled: soundAndVibrationEnabled,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              overdueCount == 0
                  ? 'Checked — no overdue customers right now.'
                  : 'Checked — $overdueCount customer${overdueCount == 1 ? '' : 's'} overdue, '
                      'notification${overdueCount == 1 ? '' : 's'} updated.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder check failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(signedInAccountProvider);
    final account = accountAsync.valueOrNull;
    final isConfigured = ref.read(backupServiceProvider).isConfigured;
    final autoBackupAsync = ref.watch(autoBackupEnabledProvider);
    final defaultIntervalAsync = ref.watch(defaultReminderIntervalMonthsProvider);
    final soundAndVibrationAsync = ref.watch(soundAndVibrationEnabledProvider);
    final themeModeAsync = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Reminders'),
          ListTile(
            leading: const Icon(Icons.event_repeat_outlined),
            title: const Text('Default reminder interval'),
            subtitle: const Text('Applies to any customer without their own custom interval'),
            trailing: DropdownButton<int>(
              value: defaultIntervalAsync.valueOrNull ?? 3,
              underline: const SizedBox.shrink(),
              items: [
                for (final months in _reminderIntervalChoices)
                  DropdownMenuItem(value: months, child: Text('$months mo')),
              ],
              onChanged: (months) => months == null ? null : _setDefaultIntervalMonths(months),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Notification sound & vibration'),
            subtitle: const Text('Turn off to receive silent reminder notifications'),
            value: soundAndVibrationAsync.valueOrNull ?? true,
            onChanged: _setSoundAndVibrationEnabled,
          ),
          const Divider(),
          const _SectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Theme'),
            trailing: DropdownButton<ThemeMode>(
              value: themeModeAsync.valueOrNull ?? ThemeMode.system,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (mode) => mode == null ? null : _setThemeMode(mode),
            ),
          ),
          const Divider(),
          const _SectionHeader('Google Drive Backup'),
          if (!isConfigured)
            const ListTile(
              leading: Icon(Icons.cloud_off_outlined),
              title: Text('Google Sign-In not set up'),
              subtitle: Text('This build has no Google OAuth client configured yet.'),
              enabled: false,
            )
          else if (account == null)
            ListTile(
              leading: _isSigningIn
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.login),
              title: const Text('Sign in with Google'),
              subtitle: const Text('Required before backing up or restoring'),
              enabled: !_isSigningIn,
              onTap: _isSigningIn ? null : _signIn,
            )
          else
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(account.displayName ?? account.email),
              subtitle: Text(account.email),
              trailing: TextButton(onPressed: _signOut, child: const Text('Sign out')),
            ),
          ListTile(
            leading: _isBackingUp
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.backup_outlined),
            title: const Text('Backup now'),
            subtitle: Text(account == null ? 'Sign in with Google to enable backups' : 'Uploads to Drive App Data'),
            enabled: account != null && !_isBackingUp,
            onTap: account != null && !_isBackingUp ? _backupNow : null,
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restore from backup'),
            subtitle: Text(
              account == null ? 'Sign in with Google to enable restore' : 'Choose a backup to restore from',
            ),
            enabled: account != null,
            onTap: account != null
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RestoreBackupScreen()),
                    )
                : null,
          ),
          SwitchListTile(
            secondary: _isTogglingAutoBackup
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.event_repeat_outlined),
            title: const Text('Automatic weekly backup'),
            subtitle: const Text('Backs up to Drive once a week in the background'),
            value: autoBackupAsync.valueOrNull ?? false,
            onChanged: (!isConfigured || _isTogglingAutoBackup) ? null : _setAutoBackupEnabled,
          ),
          const Divider(),
          const _SectionHeader('Debug'),
          ListTile(
            leading: _isChecking
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.notifications_active_outlined),
            title: const Text('Check reminders now'),
            subtitle: const Text(
              'Runs the overdue-customer check immediately, instead of waiting for the '
              'once-a-day background task',
            ),
            enabled: !_isChecking,
            onTap: _isChecking ? null : _checkNow,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
