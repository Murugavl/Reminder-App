/// Minimal, plugin-independent view of the signed-in Google account — kept
/// separate from `GoogleSignInAccount` so UI and tests don't need a real
/// plugin instance behind them.
class SignedInAccount {
  const SignedInAccount({required this.email, this.displayName});

  final String email;
  final String? displayName;
}

/// One backup file found in the user's Drive App Data folder.
class DriveBackupFile {
  const DriveBackupFile({required this.id, required this.name, required this.createdTime});

  final String id;
  final String name;
  final DateTime createdTime;
}

/// Result of a [BackupService.backupNow] attempt. Modeled as a value rather
/// than a thrown exception so the caller (background task or UI) can decide
/// how noisy to be about failure without a try/catch for routine cases like
/// "not signed in yet".
sealed class BackupOutcome {
  const BackupOutcome();
}

class BackupSucceeded extends BackupOutcome {
  const BackupSucceeded(this.uploadedAt);
  final DateTime uploadedAt;
}

class BackupFailed extends BackupOutcome {
  const BackupFailed(this.message);
  final String message;
}

/// Abstraction over Google Sign-In + Drive App Data backup/restore, so the
/// Settings screen and the weekly background task can be exercised in tests
/// without a real Google account or network behind them.
abstract class BackupService {
  /// Emits the current account whenever sign-in state changes (including
  /// `null` on sign-out). Safe to listen to before [initialize] resolves.
  Stream<SignedInAccount?> get accountChanges;

  SignedInAccount? get currentAccount;

  /// False when Google Sign-In has no OAuth client configured for this
  /// build (e.g. no `google-services.json` yet) — the UI should show this as
  /// "not set up" rather than a broken sign-in button.
  bool get isConfigured;

  /// Restores any previous session silently. Safe to call multiple times.
  Future<void> initialize();

  /// Interactive sign-in; must be called from a user-initiated action (e.g.
  /// a button's onPressed).
  Future<void> signIn();

  Future<void> signOut();

  /// Exports the local database and uploads it to Drive App Data.
  /// [interactive] must be true when called from a user-initiated action
  /// (allows a consent prompt); false from the background task, where a
  /// missing/expired authorization simply fails softly instead of prompting.
  Future<BackupOutcome> backupNow({required bool interactive});

  /// Lists available backups, most recent first.
  Future<List<DriveBackupFile>> listBackups();

  /// Downloads the given backup and replaces all local customers/service
  /// records with its contents. Callers must warn the user before calling
  /// this — it is destructive and cannot be undone.
  Future<void> restore(String fileId);
}
