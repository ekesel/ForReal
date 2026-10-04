import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/data/secret_store.dart';
import 'package:sqlite3/sqlite3.dart';

/// The local database must really be encrypted: these checks run against the same
/// SQLite build the app bundles (selected in pubspec.yaml under hooks).
void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('forreal_db'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('the bundled SQLite is SQLCipher', () {
    final db = sqlite3.openInMemory();
    final version = db.select('PRAGMA cipher_version;');
    db.close();
    expect(version, isNotEmpty);
    expect(version.first.values.first, isNotEmpty);
  });

  test('a keyed database is unreadable on disk and without the key', () async {
    final key = await DatabaseKeyStore(MemorySecretStore()).key();
    final path = '${dir.path}/forreal.db';

    final db = sqlite3.open(path);
    db.execute("PRAGMA key = \"x'$key'\";");
    db.execute('CREATE TABLE local_transactions (payee_name TEXT, amount_exact REAL);');
    db.execute("INSERT INTO local_transactions VALUES ('RAMESH KUMAR', 300.0);");
    db.close();

    final bytes = File(path).readAsBytesSync();
    final text = String.fromCharCodes(bytes);
    expect(text.startsWith('SQLite format 3'), isFalse);
    expect(text.contains('RAMESH KUMAR'), isFalse);
    expect(text.contains('local_transactions'), isFalse);

    final noKey = sqlite3.open(path);
    expect(() => noKey.select('SELECT count(*) FROM sqlite_master;'), throwsA(isA<SqliteException>()));
    noKey.close();

    final wrongKey = sqlite3.open(path);
    wrongKey.execute("PRAGMA key = \"x'${'0' * 64}'\";");
    expect(() => wrongKey.select('SELECT count(*) FROM sqlite_master;'), throwsA(isA<SqliteException>()));
    wrongKey.close();

    final again = sqlite3.open(path);
    again.execute("PRAGMA key = \"x'$key'\";");
    expect(again.select('SELECT payee_name FROM local_transactions;').single['payee_name'], 'RAMESH KUMAR');
    again.close();
  });

  test('the database key is 32 random bytes, generated once', () async {
    final secrets = MemorySecretStore();
    final first = await DatabaseKeyStore(secrets).key();
    final second = await DatabaseKeyStore(secrets).key();
    expect(first, second);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(first), isTrue);
    expect(await DatabaseKeyStore(MemorySecretStore()).key(), isNot(first));
  });
}
