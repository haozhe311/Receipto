import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:receipto/services/database_helper.dart';

/// Handles Google Drive backup and restore of the local SQLite database.
///
/// Workflow:
///  - Sign in with google_sign_in using Drive file scope
///  - Export all transactions as JSON and upload to Drive
///  - List existing backups
///  - Download and restore a selected backup JSON
///
/// Pre-requisite: a Google Cloud OAuth 2.0 Android client ID must be
/// registered with the app's package name and debug/release SHA-1.
class BackupService {
  BackupService._();

  static const String _backupFilePrefix = 'receipto_backup_';
  static const String _backupMimeType = 'application/json';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  /// Signs in (if needed) and returns an authenticated Drive API instance.
  /// Returns null if the user cancels the sign-in flow.
  static Future<drive.DriveApi?> _getDriveApi() async {
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signIn();
    if (account == null) return null;

    final authHeaders = await account.authHeaders;
    final client = _GoogleAuthClient(authHeaders);
    return drive.DriveApi(client);
  }

  /// Returns the currently signed-in Google account email, or null.
  static String? get currentUserEmail => _googleSignIn.currentUser?.email;

  /// Signs the user out of Google.
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// Exports all transactions and uploads the JSON file to Google Drive.
  ///
  /// Returns true on success, false if the user cancelled sign-in.
  /// Throws on API errors.
  static Future<bool> backup() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return false;

    // Export all transactions as JSON
    final jsonString = await DatabaseHelper.instance.getAllTransactionsAsJson();
    final bytes = utf8.encode(jsonString);

    // Create file metadata
    final now = DateTime.now();
    final fileName =
        '$_backupFilePrefix${DateFormat('yyyy-MM-dd_HHmmss').format(now)}.json';

    final fileMetadata = drive.File()
      ..name = fileName
      ..mimeType = _backupMimeType;

    // Upload via streamed media
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: _backupMimeType,
    );

    await driveApi.files.create(fileMetadata, uploadMedia: media);

    // Save timestamp to settings
    await DatabaseHelper.instance
        .setSetting('last_backup_date', now.toIso8601String());

    return true;
  }

  /// Lists all Receipto backup files from Google Drive, newest first.
  static Future<List<drive.File>> listBackups() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return [];

    final result = await driveApi.files.list(
      q: "name contains '$_backupFilePrefix' and mimeType='$_backupMimeType' and trashed=false",
      orderBy: 'modifiedTime desc',
      $fields: 'files(id,name,modifiedTime,size)',
      spaces: 'drive',
    );

    return result.files ?? [];
  }

  /// Downloads a backup file from Drive and restores it to the local database.
  ///
  /// Throws on API or parsing errors. The import is atomic — if it fails,
  /// existing data is preserved.
  static Future<bool> restore(String fileId) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return false;

    // Download file content
    final media = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    // Collect bytes from the stream
    final bytesList = <int>[];
    await for (final chunk in media.stream) {
      bytesList.addAll(chunk);
    }
    final jsonString = utf8.decode(bytesList);

    // Atomic import
    await DatabaseHelper.instance.importTransactionsFromJson(jsonString);

    return true;
  }

  /// Deletes a backup file from Google Drive.
  static Future<void> deleteBackup(String fileId) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return;
    await driveApi.files.delete(fileId);
  }
}

/// An HTTP client that injects Google Sign-In auth headers into every request.
///
/// Bridges [GoogleSignIn]'s `authHeaders` map to the [http.Client] interface
/// required by the `googleapis` package.
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
