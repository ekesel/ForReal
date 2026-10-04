import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../secret_store.dart';
import 'database.dart';

/// Opens the encrypted local database.
///
/// The file is SQLCipher-encrypted with a random key generated on first run and kept
/// in the platform keystore. Several isolates open it at once (the UI, background
/// capture, notification actions), so it runs in WAL mode with a busy timeout.
AppDatabase openAppDatabase(DatabaseKeyStore keys) {
  return AppDatabase(
    LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'forreal.db'));
      final key = await keys.key();
      return NativeDatabase(
        file,
        setup: (raw) {
          // Refuse to run on a build without SQLCipher: it would write plain text.
          final cipher = raw.select('PRAGMA cipher_version;');
          if (cipher.isEmpty) {
            throw StateError('SQLCipher is not available; refusing to open an unencrypted database.');
          }
          raw.execute("PRAGMA key = \"x'$key'\";");
          raw.execute('PRAGMA journal_mode = WAL;');
          raw.execute('PRAGMA busy_timeout = 5000;');
          // Fails here, loudly, if the key does not match the file.
          raw.select('SELECT count(*) FROM sqlite_master;');
        },
      );
    }),
  );
}
