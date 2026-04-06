import 'package:flutter/foundation.dart';

/// Manages AI provider settings and API key state.
///
/// Stub implementation for now — fully implemented in Step 6
/// when SecureStorageService is created.
class SettingsProvider extends ChangeNotifier {
  String? _apiKey;
  String _aiProvider = 'gemini';

  String? get apiKey => _apiKey;
  String get aiProvider => _aiProvider;
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Loads settings from secure storage. Fully implemented in Step 6.
  Future<void> loadSettings() async {
    // TODO: Load from SecureStorageService
    notifyListeners();
  }

  /// Saves the API key. Fully implemented in Step 6.
  Future<void> setApiKey(String key) async {
    _apiKey = key;
    // TODO: Persist to SecureStorageService
    notifyListeners();
  }

  /// Switches the AI provider (gemini or openai).
  Future<void> setAiProvider(String provider) async {
    _aiProvider = provider;
    // TODO: Persist to SecureStorageService
    notifyListeners();
  }

  /// Clears the stored API key.
  Future<void> clearApiKey() async {
    _apiKey = null;
    // TODO: Delete from SecureStorageService
    notifyListeners();
  }
}
