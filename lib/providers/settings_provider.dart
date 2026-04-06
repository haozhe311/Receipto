import 'package:flutter/foundation.dart';
import 'package:receipto/services/secure_storage_service.dart';

/// Manages AI provider settings and API key state.
///
/// The API key is persisted in encrypted secure storage on-device.
/// The selected AI provider (gemini/openai) is also persisted.
class SettingsProvider extends ChangeNotifier {
  String? _apiKey;
  String _aiProvider = 'gemini';

  String? get apiKey => _apiKey;
  String get aiProvider => _aiProvider;
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Loads settings from secure storage. Call once at app startup.
  Future<void> loadSettings() async {
    _apiKey = await SecureStorageService.read(SecureStorageService.keyApiKey);
    _aiProvider = await SecureStorageService.read(
          SecureStorageService.keyAiProvider,
        ) ??
        'gemini';
    notifyListeners();
  }

  /// Saves the API key to secure storage.
  Future<void> setApiKey(String key) async {
    _apiKey = key;
    await SecureStorageService.write(SecureStorageService.keyApiKey, key);
    notifyListeners();
  }

  /// Switches the AI provider (gemini or openai) and persists the choice.
  Future<void> setAiProvider(String provider) async {
    _aiProvider = provider;
    await SecureStorageService.write(
      SecureStorageService.keyAiProvider,
      provider,
    );
    notifyListeners();
  }

  /// Clears the stored API key from secure storage.
  Future<void> clearApiKey() async {
    _apiKey = null;
    await SecureStorageService.delete(SecureStorageService.keyApiKey);
    notifyListeners();
  }
}
