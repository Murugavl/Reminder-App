import 'dart:async';

import 'package:service_reminder/services/backup/backup_service.dart';

/// Records calls and lets tests script responses, instead of touching a real
/// Google account or network.
class FakeBackupService implements BackupService {
  FakeBackupService({SignedInAccount? initialAccount}) : _account = initialAccount;

  SignedInAccount? _account;
  bool configured = true;
  bool initializeCalled = false;
  int signInCallCount = 0;
  int signOutCallCount = 0;
  final List<bool> backupNowInteractiveCalls = [];
  int listBackupsCallCount = 0;
  final List<String> restoreCalls = [];

  /// Scripted responses/behavior for tests to control.
  BackupOutcome nextBackupOutcome = BackupSucceeded(DateTime(2026, 1, 1));
  List<DriveBackupFile> backupsToReturn = const [];
  Object? signInError;
  Object? restoreError;

  final _controller = StreamController<SignedInAccount?>.broadcast();

  @override
  Stream<SignedInAccount?> get accountChanges => _controller.stream;

  @override
  SignedInAccount? get currentAccount => _account;

  @override
  bool get isConfigured => configured;

  @override
  Future<void> initialize() async {
    initializeCalled = true;
  }

  @override
  Future<void> signIn() async {
    signInCallCount++;
    if (signInError != null) throw signInError!;
    _account = const SignedInAccount(email: 'test@example.com', displayName: 'Test User');
    _controller.add(_account);
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    _account = null;
    _controller.add(null);
  }

  @override
  Future<BackupOutcome> backupNow({required bool interactive}) async {
    backupNowInteractiveCalls.add(interactive);
    return nextBackupOutcome;
  }

  @override
  Future<List<DriveBackupFile>> listBackups() async {
    listBackupsCallCount++;
    return backupsToReturn;
  }

  @override
  Future<void> restore(String fileId) async {
    restoreCalls.add(fileId);
    if (restoreError != null) throw restoreError!;
  }
}
