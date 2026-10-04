import 'package:drift/drift.dart';

part 'database.g.dart';

/// Payments as this device knows them. `amountExact` and the original payee text
/// never leave the device; the server only gets a band.
@DataClassName('LocalTransaction')
class LocalTransactions extends Table {
  /// UUIDv5 of the source message; the idempotency key sent to the server.
  TextColumn get clientTxnId => text()();
  TextColumn get bank => text().withDefault(const Constant(''))();
  TextColumn get payeeName => text()();

  /// Null only for payments restored from the server after a reinstall.
  RealColumn get amountExact => real().nullable()();

  /// yyyy-MM-dd
  TextColumn get occurredOn => text()();
  DateTimeColumn get receivedAt => dateTime()();
  TextColumn get ref => text().withDefault(const Constant(''))();
  TextColumn get source => text().withDefault(const Constant('sms'))();

  /// pending, synced or failed.
  TextColumn get syncState => text().withDefault(const Constant('pending'))();
  TextColumn get serverId => text().nullable()();

  /// unknown, merchant or person.
  TextColumn get kind => text().withDefault(const Constant('unknown'))();

  /// JSON of the confirmed shop, when there is one.
  TextColumn get merchant => text().nullable()();

  /// JSON list of the tags the server holds.
  TextColumn get items => text().withDefault(const Constant('[]'))();

  /// What the server said to ask about: 'payee', 'items' or null.
  TextColumn get ask => text().nullable()();
  BoolColumn get notified => boolean().withDefault(const Constant(false))();

  // --- beyond the Phase 2 column list, each needed by a stated requirement ---

  /// Server id of the payee, for payees/{id}/resolve/.
  IntColumn get payeeId => integer().nullable()();

  /// Stored so restored rows (no exact amount) can still show a range.
  TextColumn get amountBand => text()();
  TextColumn get dayPart => text().withDefault(const Constant(''))();

  /// History-import rows never trigger a notification.
  BoolColumn get fromHistory => boolean().withDefault(const Constant(false))();

  /// Why the server refused the row, kept for display.
  TextColumn get error => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {clientTxnId};
}

/// Bank messages no template matched. Device only, newest 200 kept, shown (masked)
/// on the debug "Parser gaps" screen.
@DataClassName('UnparsedMessage')
class UnparsedMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sender => text()();
  DateTimeColumn get receivedAt => dateTime()();
  TextColumn get body => text()();
}

@DataClassName('CachedTemplate')
class ParserTemplates extends Table {
  IntColumn get id => integer()();
  TextColumn get json => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('Setting')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Answers given from a notification while offline, replayed on the next sync.
@DataClassName('PendingAction')
class PendingActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientTxnId => text()();

  /// 'person' or 'confirm_items'.
  TextColumn get type => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [LocalTransactions, UnparsedMessages, ParserTemplates, Settings, PendingActions])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
