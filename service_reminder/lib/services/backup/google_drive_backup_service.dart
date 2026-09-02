import 'dart:async';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../../data/local/database.dart';
import 'backup_service.dart';
import 'backup_snapshot.dart';

const _driveScopes = [drive.DriveApi.driveAppdataScope];

/// Real [BackupService], backed by `google_sign_in` + the Drive REST API
/// (`drive.appdata` scope only — the app can only see files it created
/// itself, never the user's other Drive content).
class GoogleDriveBackupService implements BackupService {
  GoogleDriveBackupService(this._db);

  final AppDatabase _db;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final _accountController = StreamController<SignedInAccount?>.broadcast();

  GoogleSignInAccount? _user;
  bool _initialized = false;
  bool _configured = true;

  @override
  Stream<SignedInAccount?> get accountChanges => _accountController.stream;

  @override
  SignedInAccount? get currentAccount => _toAccountInfo(_user);

  @override
  bool get isConfigured => _configured;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // No clientId/serverClientId is passed here: on Android, Google
      // Sign-In reads OAuth client config from
      // android/app/google-services.json, which needs a real Google
      // Cloud/Firebase project behind it (Drive API enabled, OAuth client
      // registered with this app's package name + signing SHA-1). Until
      // that file is added, this throws clientConfigurationError below and
      // the app falls back to `isConfigured == false`, which is expected.
      await _googleSignIn.initialize();
      _googleSignIn.authenticationEvents.listen(_handleAuthEvent, onError: (_) {});
      await _googleSignIn.attemptLightweightAuthentication();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        _configured = false;
      }
      // Any other exception here just means there was no previous session
      // to restore — the user simply isn't signed in yet, which is fine.
    } catch (_) {
      _configured = false;
    }
  }

  void _handleAuthEvent(GoogleSignInAuthenticationEvent event) {
    _user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };
    _accountController.add(_toAccountInfo(_user));
  }

  SignedInAccount? _toAccountInfo(GoogleSignInAccount? user) {
    if (user == null) return null;
    return SignedInAccount(email: user.email, displayName: user.displayName);
  }

  @override
  Future<void> signIn() async {
    if (!_configured) {
      throw StateError('Google Sign-In is not configured for this build.');
    }
    await _googleSignIn.authenticate();
  }

  @override
  Future<void> signOut() => _googleSignIn.signOut();

  /// Ensures drive.appdata authorization and returns a Drive client for it.
  /// [interactive] controls whether a consent prompt may be shown — must be
  /// false from a background isolate, where there's no UI to show it in.
  Future<drive.DriveApi> _driveApi({required bool interactive}) async {
    final user = _user;
    if (user == null) {
      throw StateError('Not signed in to Google.');
    }

    final headers = await user.authorizationClient.authorizationHeaders(
      _driveScopes,
      promptIfNecessary: interactive,
    );
    if (headers == null) {
      throw StateError('Google Drive access was not authorized.');
    }

    return drive.DriveApi(_AuthorizedHttpClient(user));
  }

  @override
  Future<BackupOutcome> backupNow({required bool interactive}) async {
    try {
      final api = await _driveApi(interactive: interactive);
      final customers = await _db.select(_db.customers).get();
      final serviceRecords = await _db.select(_db.serviceRecords).get();
      final snapshot = buildBackupSnapshot(customers: customers, serviceRecords: serviceRecords);
      final bytes = encodeBackupSnapshot(snapshot);

      final metadata = drive.File()
        ..name = backupFileName(snapshot.exportedAt)
        ..parents = ['appDataFolder'];

      await api.files.create(
        metadata,
        uploadMedia: drive.Media(Stream.value(bytes), bytes.length, contentType: 'application/json'),
      );

      return BackupSucceeded(snapshot.exportedAt);
    } catch (e) {
      return BackupFailed(e.toString());
    }
  }

  @override
  Future<List<DriveBackupFile>> listBackups() async {
    final api = await _driveApi(interactive: true);
    final result = await api.files.list(
      spaces: 'appDataFolder',
      orderBy: 'createdTime desc',
      pageSize: 50,
      $fields: 'files(id,name,createdTime)',
    );

    return [
      for (final file in result.files ?? const <drive.File>[])
        DriveBackupFile(
          id: file.id!,
          name: file.name ?? '',
          createdTime: file.createdTime ?? DateTime.now(),
        ),
    ];
  }

  @override
  Future<void> restore(String fileId) async {
    final api = await _driveApi(interactive: true);
    final media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = await _collectBytes(media.stream);
    final snapshot = decodeBackupSnapshot(bytes);
    await replaceLocalDataWithSnapshot(_db, snapshot);
  }

  Future<Uint8List> _collectBytes(Stream<List<int>> stream) async {
    final builder = BytesBuilder();
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.toBytes();
  }
}

/// Attaches a fresh Drive-scoped authorization header to every request.
/// google_sign_in caches/refreshes the underlying token internally, so
/// re-fetching headers per request is cheap and always current.
class _AuthorizedHttpClient extends http.BaseClient {
  _AuthorizedHttpClient(this._user);

  final GoogleSignInAccount _user;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = await _user.authorizationClient.authorizationHeaders(_driveScopes);
    if (headers != null) {
      request.headers.addAll(headers);
    }
    return _inner.send(request);
  }
}
