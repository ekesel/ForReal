import 'dart:convert';
import 'dart:math';

/// Small secrets kept in the platform keystore: the JWTs and the database key.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class AuthTokens {
  const AuthTokens({required this.access, required this.refresh});
  final String access;
  final String refresh;
}

class TokenStore {
  TokenStore(this._store);

  final SecretStore _store;
  static const _access = 'jwt_access';
  static const _refresh = 'jwt_refresh';

  /// Always reads through to storage: a background isolate may have rotated the tokens.
  Future<AuthTokens?> load() async {
    final access = await _store.read(_access);
    final refresh = await _store.read(_refresh);
    if (access == null || refresh == null) return null;
    return AuthTokens(access: access, refresh: refresh);
  }

  Future<void> save(AuthTokens tokens) async {
    await _store.write(_access, tokens.access);
    await _store.write(_refresh, tokens.refresh);
  }

  Future<void> clear() async {
    await _store.delete(_access);
    await _store.delete(_refresh);
  }
}

/// The SQLCipher key: 32 random bytes, generated on first run.
class DatabaseKeyStore {
  DatabaseKeyStore(this._store, {Random? random}) : _random = random ?? Random.secure();

  final SecretStore _store;
  final Random _random;
  static const _key = 'db_key_v1';

  /// 64 hex characters.
  Future<String> key() async {
    final existing = await _store.read(_key);
    if (existing != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(existing)) return existing;
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _store.write(_key, hex);
    return hex;
  }
}

/// Install id sent with PUT me/device/. Random, not derived from any hardware id.
class InstallIdStore {
  InstallIdStore(this._store, {Random? random}) : _random = random ?? Random.secure();

  final SecretStore _store;
  final Random _random;
  static const _key = 'install_id';

  Future<String> id() async {
    final existing = await _store.read(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    final value = base64Url.encode(bytes).replaceAll('=', '');
    await _store.write(_key, value);
    return value;
  }
}
