import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/secret_store.dart';

/// Secrets in the platform keystore (Android Keystore-backed encrypted storage).
class SecureSecretStore implements SecretStore {
  const SecureSecretStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
