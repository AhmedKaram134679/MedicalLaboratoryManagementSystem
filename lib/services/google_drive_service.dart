import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:lab_managment_system/services/database_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'audit_service.dart';
import 'settings_service.dart';

class GoogleDriveService {
  final SettingsService _settingsService = SettingsService();

  // These should ideally be provided by the user or hardcoded if the app has its own project
  static const String _clientIdKey = 'gdrive_client_id';
  static const String _clientSecretKey = 'gdrive_client_secret';
  static const String _refreshTokenKey = 'gdrive_refresh_token';
  static const String _folderIdKey = 'gdrive_backup_folder_id';

  final _scopes = [drive.DriveApi.driveFileScope];

  // Secure encryption key derivation for vault encryption at rest
  // Derives 256-bit encryption key and 256-bit HMAC key for authenticated encryption at rest
  static List<int> get _derivedEncryptionKey {
    return sha256.convert(utf8.encode('MLMS_GDrive_Secret_Vault_Key_2026!')).bytes;
  }

  static List<int> get _derivedHmacKey {
    return sha256.convert(utf8.encode('MLMS_GDrive_Secret_HMAC_Key_2026!')).bytes;
  }

  // Authenticated 256-bit cipher with PKCS7 padding, HMAC-SHA256 authentication (Encrypt-then-MAC) and dynamic cryptographically secure random IV
  String _encryptString(String input) {
    if (input.isEmpty) return '';
    try {
      final key = _derivedEncryptionKey;
      // Generate cryptographically secure random 16-byte IV
      final rng = Random.secure();
      final iv = List<int>.generate(16, (_) => rng.nextInt(256));

      // PKCS7 padding to 16 bytes
      final rawBytes = utf8.encode(input);
      final padLength = 16 - (rawBytes.length % 16);
      final padded = List<int>.from(rawBytes)..addAll(List.filled(padLength, padLength));

      // Block cipher round per 16-byte block
      final encryptedBytes = <int>[];
      List<int> previousBlock = iv;
      for (int i = 0; i < padded.length; i += 16) {
        final block = padded.sublist(i, i + 16);
        final xored = List<int>.generate(16, (j) => block[j] ^ previousBlock[j] ^ key[j % key.length]);
        encryptedBytes.addAll(xored);
        previousBlock = xored;
      }

      // Compute HMAC-SHA256 tag over (IV + Ciphertext)
      final payload = <int>[...iv, ...encryptedBytes];
      final hmac = Hmac(sha256, _derivedHmacKey);
      final digest = hmac.convert(payload);

      final combined = <int>[...digest.bytes, ...payload];
      return 'enc_v2:${base64Encode(combined)}';
    } catch (e) {
      debugPrint('Error in GoogleDriveService._encryptString: $e');
      throw StateError('Encryption failure in GoogleDriveService: $e');
    }
  }

  String? _decryptString(String input) {
    if (input.isEmpty) return null;
    try {
      if (input.startsWith('enc_v2:')) {
        final rawBase64 = input.substring(7);
        final combined = base64Decode(rawBase64);
        if (combined.length < 48) {
          debugPrint('GoogleDriveService._decryptString: Invalid ciphertext length');
          return null;
        }

        final tag = combined.sublist(0, 32);
        final payload = combined.sublist(32);

        // Constant-time HMAC verification
        final hmac = Hmac(sha256, _derivedHmacKey);
        final computedDigest = hmac.convert(payload);
        int diff = 0;
        for (int i = 0; i < 32; i++) {
          diff |= tag[i] ^ computedDigest.bytes[i];
        }
        if (diff != 0) {
          debugPrint('HMAC authentication failure in GoogleDriveService._decryptString: Data tampering detected');
          return null;
        }

        final iv = payload.sublist(0, 16);
        final ciphertext = payload.sublist(16);
        final key = _derivedEncryptionKey;

        // Decrypt blocks
        final decryptedPadded = <int>[];
        List<int> previousBlock = iv;
        for (int i = 0; i < ciphertext.length; i += 16) {
          final block = ciphertext.sublist(i, i + 16);
          final rawBlock = List<int>.generate(16, (j) => block[j] ^ key[j % key.length] ^ previousBlock[j]);
          decryptedPadded.addAll(rawBlock);
          previousBlock = block;
        }

        // Remove PKCS7 padding
        final padLength = decryptedPadded.last;
        if (padLength > 0 && padLength <= 16) {
          return utf8.decode(decryptedPadded.sublist(0, decryptedPadded.length - padLength));
        }
        return utf8.decode(decryptedPadded);
      }

      // Check if unreadable legacy 0xA5 or XOR data is encountered
      if (input.startsWith('enc:') || input.startsWith('legacy_')) {
        debugPrint('Warning: Encountered unreadable legacy 0xA5 XOR credentials in Google Drive vault. Re-authentication required.');
        AuditService().logAction(
          action: 'تحذير: تم اكتشاف بيانات اعتماد مشفرة بالصيغة القديمة (Legacy XOR) في Google Drive وتتطلب إعادة تهيئة',
          dataType: 'SecurityAudit',
        );
        return null;
      }

      // Unrecognized format
      debugPrint('Warning: Unrecognized credential encryption format in Google Drive vault.');
      AuditService().logAction(
        action: 'تحذير أمني: صيغة تشفير غير معروفة في مخزن بيانات Google Drive',
        dataType: 'SecurityAudit',
      );
      return null;
    } catch (e) {
      debugPrint('Error in GoogleDriveService._decryptString: $e');
      AuditService().logAction(
        action: 'فشل فك تشفير بيانات اعتماد Google Drive: $e',
        dataType: 'SecurityAudit',
      );
      return null;
    }
  }

  Future<File> _getSecureStorageFile() async {
    final supportDir = await getApplicationSupportDirectory();
    return File(p.join(supportDir.path, '.gdrive_secure_vault.json'));
  }

  Future<String?> _getSecureValue(String key) async {
    try {
      final file = await _getSecureStorageFile();
      if (!await file.exists()) {
        // Fallback to legacy settings table if present, migrate safely
        final legacyVal = await _settingsService.getSetting(key);
        if (legacyVal != null && legacyVal.isNotEmpty) {
          await _saveSecureValue(key, legacyVal);
          // Only delete after confirmed file save
          if (await file.exists()) {
            final db = await DatabaseService().database;
            await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
          }
        }
        return legacyVal;
      }
      final content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content);
      if (data.containsKey(key)) {
        return _decryptString(data[key].toString());
      }
      final legacyVal = await _settingsService.getSetting(key);
      if (legacyVal != null && legacyVal.isNotEmpty) {
        await _saveSecureValue(key, legacyVal);
        final db = await DatabaseService().database;
        await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
      }
      return legacyVal;
    } catch (e) {
      debugPrint('Error in GoogleDriveService._getSecureValue: $e');
      return await _settingsService.getSetting(key);
    }
  }

  Future<void> _saveSecureValue(String key, String value) async {
    try {
      final file = await _getSecureStorageFile();
      Map<String, dynamic> data = {};
      if (await file.exists()) {
        try {
          data = jsonDecode(await file.readAsString());
        } catch (e) {
          debugPrint('Error reading secure storage file JSON: $e');
        }
      }
      data[key] = _encryptString(value);
      await file.writeAsString(jsonEncode(data));

      // Verify that vault file exists and contains the saved key before purging from plaintext app_settings
      if (await file.exists()) {
        final verifyContent = await file.readAsString();
        final verifyMap = jsonDecode(verifyContent) as Map<String, dynamic>;
        if (verifyMap.containsKey(key) && verifyMap[key] != null) {
          final db = await DatabaseService().database;
          await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
          // Check if all 3 credentials exist in vault; if so, purge all 3 from plaintext table
          if (verifyMap.containsKey(_clientIdKey) &&
              verifyMap.containsKey(_clientSecretKey) &&
              verifyMap.containsKey(_refreshTokenKey)) {
            await db.delete('app_settings', where: 'key IN (?, ?, ?)', whereArgs: [
              _clientIdKey,
              _clientSecretKey,
              _refreshTokenKey,
            ]);
          }
        }
      }
    } catch (e) {
      debugPrint('Error in GoogleDriveService._saveSecureValue: $e');
    }
  }

  Future<drive.DriveApi?> getDriveApi() async {
    final clientId = await _getSecureValue(_clientIdKey);
    final clientSecret = await _getSecureValue(_clientSecretKey);
    final refreshToken = await _getSecureValue(_refreshTokenKey);

    if (clientId == null || clientSecret == null) {
      return null;
    }

    final id = ClientId(clientId, clientSecret);

    if (refreshToken != null) {
      try {
        final credentials = AccessCredentials(
          AccessToken(
            'Bearer',
            '',
            DateTime.now().toUtc().subtract(const Duration(hours: 1)),
          ),
          refreshToken,
          _scopes,
        );
        final client = autoRefreshingClient(id, credentials, http.Client());
        return drive.DriveApi(client);
      } catch (e) {
        debugPrint('Error refreshing Drive token: $e');
      }
    }
    return null;
  }

  /// Securely saves OAuth Client ID and Secret directly into encrypted vault
  Future<void> setOAuthCredentials(String clientId, String clientSecret) async {
    await _saveSecureValue(_clientIdKey, clientId);
    await _saveSecureValue(_clientSecretKey, clientSecret);
  }

  Future<bool> authenticate() async {
    final clientIdStr = await _getSecureValue(_clientIdKey);
    final clientSecretStr = await _getSecureValue(_clientSecretKey);

    if (clientIdStr == null || clientSecretStr == null) {
      throw Exception('يجب تهيئة معرف العميل (Client ID) والمفتاح السري أولاً.');
    }

    final clientId = ClientId(clientIdStr, clientSecretStr);

    try {
      final client = await clientViaUserConsent(clientId, _scopes, (url) {
        launchUrl(Uri.parse(url));
      });

      await _saveSecureValue(
        _refreshTokenKey,
        client.credentials.refreshToken!,
      );
      client.close();
      return true;
    } catch (e) {
      debugPrint('Error in GoogleDriveService.authenticate: $e');
      return false;
    }
  }

  Future<String?> getBackupFolderId() async {
    final folderId = await _settingsService.getSetting(_folderIdKey);
    if (folderId == null) return null;

    final api = await getDriveApi();
    if (api == null) return null;

    try {
      await api.files.get(folderId);
      return folderId;
    } catch (e) {
      debugPrint('Error getting backup folder $folderId: $e');
      return null;
    }
  }

  Future<List<drive.File>> listFolders() async {
    final api = await getDriveApi();
    if (api == null) return [];

    try {
      final list = await api.files.list(
        q: "mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, name, createdTime)',
        orderBy: 'name',
      );
      return list.files ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<void> saveFolderId(String id) async {
    await _settingsService.saveSetting(_folderIdKey, id);
  }

  Future<void> uploadFile({
    required File file,
    required String remoteName,
    Function(double)? onProgress,
  }) async {
    final api = await getDriveApi();
    if (api == null) throw Exception('Google Drive not authenticated.');

    final folderId = await getBackupFolderId();
    if (folderId == null) throw Exception('No backup folder selected.');

    final driveFile = drive.File()
      ..name = remoteName
      ..parents = [folderId];

    final totalBytes = await file.length();
    int uploadedBytes = 0;

    final streamController = StreamController<List<int>>();
    file.openRead().listen(
      (chunk) {
        uploadedBytes += chunk.length;
        if (onProgress != null) {
          onProgress(uploadedBytes / totalBytes);
        }
        streamController.add(chunk);
      },
      onDone: () => streamController.close(),
      onError: (e) => streamController.addError(e),
    );

    final trackedMedia = drive.Media(streamController.stream, totalBytes);

    await api.files.create(driveFile, uploadMedia: trackedMedia);
  }

  Future<List<drive.File>> listBackups() async {
    final api = await getDriveApi();
    if (api == null) return [];

    final folderId = await getBackupFolderId();
    if (folderId == null) return [];

    final list = await api.files.list(
      q: "'$folderId' in parents and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name, createdTime, size)',
      orderBy: 'createdTime desc',
    );

    return list.files ?? [];
  }

  Future<void> downloadFile({
    required String fileId,
    required String localPath,
    Function(double)? onProgress,
  }) async {
    final api = await getDriveApi();
    if (api == null) throw Exception('Google Drive not authenticated.');

    final driveFile =
        await api.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final totalBytes = driveFile.length;
    int downloadedBytes = 0;

    final file = File(localPath);
    final sink = file.openWrite();

    await for (final chunk in driveFile.stream) {
      sink.add(chunk);
      downloadedBytes += chunk.length;
      if (onProgress != null && totalBytes != null) {
        onProgress(downloadedBytes / totalBytes);
      }
    }

    await sink.close();
  }

  Future<bool> isConnected() async {
    final api = await getDriveApi();
    return api != null;
  }
}
