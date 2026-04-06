import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper around [FlutterSecureStorage] for encrypted key-value storage.
///
/// Used to store sensitive data like API keys on-device.
/// Data is encrypted using platform-specific mechanisms (Android Keystore).
class SecureStorageService {
  SecureStorageService._();

  static const _storage = FlutterSecureStorage();

  // Storage keys
  static const String keyApiKey = 'ai_api_key';
  static const String keyAiProvider = 'ai_provider';

  /// Writes a value to secure storage.
  static Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Reads a value from secure storage. Returns null if the key doesn't exist.
  static Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// Deletes a value from secure storage.
  static Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}
