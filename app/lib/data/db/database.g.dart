// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LocalTransactionsTable extends LocalTransactions
    with TableInfo<$LocalTransactionsTable, LocalTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientTxnIdMeta = const VerificationMeta(
    'clientTxnId',
  );
  @override
  late final GeneratedColumn<String> clientTxnId = GeneratedColumn<String>(
    'client_txn_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bankMeta = const VerificationMeta('bank');
  @override
  late final GeneratedColumn<String> bank = GeneratedColumn<String>(
    'bank',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _payeeNameMeta = const VerificationMeta(
    'payeeName',
  );
  @override
  late final GeneratedColumn<String> payeeName = GeneratedColumn<String>(
    'payee_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountExactMeta = const VerificationMeta(
    'amountExact',
  );
  @override
  late final GeneratedColumn<double> amountExact = GeneratedColumn<double>(
    'amount_exact',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredOnMeta = const VerificationMeta(
    'occurredOn',
  );
  @override
  late final GeneratedColumn<String> occurredOn = GeneratedColumn<String>(
    'occurred_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
    'received_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refMeta = const VerificationMeta('ref');
  @override
  late final GeneratedColumn<String> ref = GeneratedColumn<String>(
    'ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('sms'),
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  static const VerificationMeta _merchantMeta = const VerificationMeta(
    'merchant',
  );
  @override
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
    'merchant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemsMeta = const VerificationMeta('items');
  @override
  late final GeneratedColumn<String> items = GeneratedColumn<String>(
    'items',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _askMeta = const VerificationMeta('ask');
  @override
  late final GeneratedColumn<String> ask = GeneratedColumn<String>(
    'ask',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notifiedMeta = const VerificationMeta(
    'notified',
  );
  @override
  late final GeneratedColumn<bool> notified = GeneratedColumn<bool>(
    'notified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _payeeIdMeta = const VerificationMeta(
    'payeeId',
  );
  @override
  late final GeneratedColumn<int> payeeId = GeneratedColumn<int>(
    'payee_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountBandMeta = const VerificationMeta(
    'amountBand',
  );
  @override
  late final GeneratedColumn<String> amountBand = GeneratedColumn<String>(
    'amount_band',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayPartMeta = const VerificationMeta(
    'dayPart',
  );
  @override
  late final GeneratedColumn<String> dayPart = GeneratedColumn<String>(
    'day_part',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _fromHistoryMeta = const VerificationMeta(
    'fromHistory',
  );
  @override
  late final GeneratedColumn<bool> fromHistory = GeneratedColumn<bool>(
    'from_history',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("from_history" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    clientTxnId,
    bank,
    payeeName,
    amountExact,
    occurredOn,
    receivedAt,
    ref,
    source,
    syncState,
    serverId,
    kind,
    merchant,
    items,
    ask,
    notified,
    payeeId,
    amountBand,
    dayPart,
    fromHistory,
    error,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_txn_id')) {
      context.handle(
        _clientTxnIdMeta,
        clientTxnId.isAcceptableOrUnknown(
          data['client_txn_id']!,
          _clientTxnIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientTxnIdMeta);
    }
    if (data.containsKey('bank')) {
      context.handle(
        _bankMeta,
        bank.isAcceptableOrUnknown(data['bank']!, _bankMeta),
      );
    }
    if (data.containsKey('payee_name')) {
      context.handle(
        _payeeNameMeta,
        payeeName.isAcceptableOrUnknown(data['payee_name']!, _payeeNameMeta),
      );
    } else if (isInserting) {
      context.missing(_payeeNameMeta);
    }
    if (data.containsKey('amount_exact')) {
      context.handle(
        _amountExactMeta,
        amountExact.isAcceptableOrUnknown(
          data['amount_exact']!,
          _amountExactMeta,
        ),
      );
    }
    if (data.containsKey('occurred_on')) {
      context.handle(
        _occurredOnMeta,
        occurredOn.isAcceptableOrUnknown(data['occurred_on']!, _occurredOnMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredOnMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('ref')) {
      context.handle(
        _refMeta,
        ref.isAcceptableOrUnknown(data['ref']!, _refMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('merchant')) {
      context.handle(
        _merchantMeta,
        merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta),
      );
    }
    if (data.containsKey('items')) {
      context.handle(
        _itemsMeta,
        items.isAcceptableOrUnknown(data['items']!, _itemsMeta),
      );
    }
    if (data.containsKey('ask')) {
      context.handle(
        _askMeta,
        ask.isAcceptableOrUnknown(data['ask']!, _askMeta),
      );
    }
    if (data.containsKey('notified')) {
      context.handle(
        _notifiedMeta,
        notified.isAcceptableOrUnknown(data['notified']!, _notifiedMeta),
      );
    }
    if (data.containsKey('payee_id')) {
      context.handle(
        _payeeIdMeta,
        payeeId.isAcceptableOrUnknown(data['payee_id']!, _payeeIdMeta),
      );
    }
    if (data.containsKey('amount_band')) {
      context.handle(
        _amountBandMeta,
        amountBand.isAcceptableOrUnknown(data['amount_band']!, _amountBandMeta),
      );
    } else if (isInserting) {
      context.missing(_amountBandMeta);
    }
    if (data.containsKey('day_part')) {
      context.handle(
        _dayPartMeta,
        dayPart.isAcceptableOrUnknown(data['day_part']!, _dayPartMeta),
      );
    }
    if (data.containsKey('from_history')) {
      context.handle(
        _fromHistoryMeta,
        fromHistory.isAcceptableOrUnknown(
          data['from_history']!,
          _fromHistoryMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientTxnId};
  @override
  LocalTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTransaction(
      clientTxnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_txn_id'],
      )!,
      bank: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank'],
      )!,
      payeeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee_name'],
      )!,
      amountExact: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount_exact'],
      ),
      occurredOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurred_on'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
      ref: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      merchant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant'],
      ),
      items: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items'],
      )!,
      ask: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ask'],
      ),
      notified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notified'],
      )!,
      payeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payee_id'],
      ),
      amountBand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount_band'],
      )!,
      dayPart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_part'],
      )!,
      fromHistory: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}from_history'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
    );
  }

  @override
  $LocalTransactionsTable createAlias(String alias) {
    return $LocalTransactionsTable(attachedDatabase, alias);
  }
}

class LocalTransaction extends DataClass
    implements Insertable<LocalTransaction> {
  /// UUIDv5 of the source message; the idempotency key sent to the server.
  final String clientTxnId;
  final String bank;
  final String payeeName;

  /// Null only for payments restored from the server after a reinstall.
  final double? amountExact;

  /// yyyy-MM-dd
  final String occurredOn;
  final DateTime receivedAt;
  final String ref;
  final String source;

  /// pending, synced or failed.
  final String syncState;
  final String? serverId;

  /// unknown, merchant or person.
  final String kind;

  /// JSON of the confirmed shop, when there is one.
  final String? merchant;

  /// JSON list of the tags the server holds.
  final String items;

  /// What the server said to ask about: 'payee', 'items' or null.
  final String? ask;
  final bool notified;

  /// Server id of the payee, for payees/{id}/resolve/.
  final int? payeeId;

  /// Stored so restored rows (no exact amount) can still show a range.
  final String amountBand;
  final String dayPart;

  /// History-import rows never trigger a notification.
  final bool fromHistory;

  /// Why the server refused the row, kept for display.
  final String? error;
  const LocalTransaction({
    required this.clientTxnId,
    required this.bank,
    required this.payeeName,
    this.amountExact,
    required this.occurredOn,
    required this.receivedAt,
    required this.ref,
    required this.source,
    required this.syncState,
    this.serverId,
    required this.kind,
    this.merchant,
    required this.items,
    this.ask,
    required this.notified,
    this.payeeId,
    required this.amountBand,
    required this.dayPart,
    required this.fromHistory,
    this.error,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_txn_id'] = Variable<String>(clientTxnId);
    map['bank'] = Variable<String>(bank);
    map['payee_name'] = Variable<String>(payeeName);
    if (!nullToAbsent || amountExact != null) {
      map['amount_exact'] = Variable<double>(amountExact);
    }
    map['occurred_on'] = Variable<String>(occurredOn);
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['ref'] = Variable<String>(ref);
    map['source'] = Variable<String>(source);
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || merchant != null) {
      map['merchant'] = Variable<String>(merchant);
    }
    map['items'] = Variable<String>(items);
    if (!nullToAbsent || ask != null) {
      map['ask'] = Variable<String>(ask);
    }
    map['notified'] = Variable<bool>(notified);
    if (!nullToAbsent || payeeId != null) {
      map['payee_id'] = Variable<int>(payeeId);
    }
    map['amount_band'] = Variable<String>(amountBand);
    map['day_part'] = Variable<String>(dayPart);
    map['from_history'] = Variable<bool>(fromHistory);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    return map;
  }

  LocalTransactionsCompanion toCompanion(bool nullToAbsent) {
    return LocalTransactionsCompanion(
      clientTxnId: Value(clientTxnId),
      bank: Value(bank),
      payeeName: Value(payeeName),
      amountExact: amountExact == null && nullToAbsent
          ? const Value.absent()
          : Value(amountExact),
      occurredOn: Value(occurredOn),
      receivedAt: Value(receivedAt),
      ref: Value(ref),
      source: Value(source),
      syncState: Value(syncState),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      kind: Value(kind),
      merchant: merchant == null && nullToAbsent
          ? const Value.absent()
          : Value(merchant),
      items: Value(items),
      ask: ask == null && nullToAbsent ? const Value.absent() : Value(ask),
      notified: Value(notified),
      payeeId: payeeId == null && nullToAbsent
          ? const Value.absent()
          : Value(payeeId),
      amountBand: Value(amountBand),
      dayPart: Value(dayPart),
      fromHistory: Value(fromHistory),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
    );
  }

  factory LocalTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTransaction(
      clientTxnId: serializer.fromJson<String>(json['clientTxnId']),
      bank: serializer.fromJson<String>(json['bank']),
      payeeName: serializer.fromJson<String>(json['payeeName']),
      amountExact: serializer.fromJson<double?>(json['amountExact']),
      occurredOn: serializer.fromJson<String>(json['occurredOn']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      ref: serializer.fromJson<String>(json['ref']),
      source: serializer.fromJson<String>(json['source']),
      syncState: serializer.fromJson<String>(json['syncState']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      kind: serializer.fromJson<String>(json['kind']),
      merchant: serializer.fromJson<String?>(json['merchant']),
      items: serializer.fromJson<String>(json['items']),
      ask: serializer.fromJson<String?>(json['ask']),
      notified: serializer.fromJson<bool>(json['notified']),
      payeeId: serializer.fromJson<int?>(json['payeeId']),
      amountBand: serializer.fromJson<String>(json['amountBand']),
      dayPart: serializer.fromJson<String>(json['dayPart']),
      fromHistory: serializer.fromJson<bool>(json['fromHistory']),
      error: serializer.fromJson<String?>(json['error']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientTxnId': serializer.toJson<String>(clientTxnId),
      'bank': serializer.toJson<String>(bank),
      'payeeName': serializer.toJson<String>(payeeName),
      'amountExact': serializer.toJson<double?>(amountExact),
      'occurredOn': serializer.toJson<String>(occurredOn),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'ref': serializer.toJson<String>(ref),
      'source': serializer.toJson<String>(source),
      'syncState': serializer.toJson<String>(syncState),
      'serverId': serializer.toJson<String?>(serverId),
      'kind': serializer.toJson<String>(kind),
      'merchant': serializer.toJson<String?>(merchant),
      'items': serializer.toJson<String>(items),
      'ask': serializer.toJson<String?>(ask),
      'notified': serializer.toJson<bool>(notified),
      'payeeId': serializer.toJson<int?>(payeeId),
      'amountBand': serializer.toJson<String>(amountBand),
      'dayPart': serializer.toJson<String>(dayPart),
      'fromHistory': serializer.toJson<bool>(fromHistory),
      'error': serializer.toJson<String?>(error),
    };
  }

  LocalTransaction copyWith({
    String? clientTxnId,
    String? bank,
    String? payeeName,
    Value<double?> amountExact = const Value.absent(),
    String? occurredOn,
    DateTime? receivedAt,
    String? ref,
    String? source,
    String? syncState,
    Value<String?> serverId = const Value.absent(),
    String? kind,
    Value<String?> merchant = const Value.absent(),
    String? items,
    Value<String?> ask = const Value.absent(),
    bool? notified,
    Value<int?> payeeId = const Value.absent(),
    String? amountBand,
    String? dayPart,
    bool? fromHistory,
    Value<String?> error = const Value.absent(),
  }) => LocalTransaction(
    clientTxnId: clientTxnId ?? this.clientTxnId,
    bank: bank ?? this.bank,
    payeeName: payeeName ?? this.payeeName,
    amountExact: amountExact.present ? amountExact.value : this.amountExact,
    occurredOn: occurredOn ?? this.occurredOn,
    receivedAt: receivedAt ?? this.receivedAt,
    ref: ref ?? this.ref,
    source: source ?? this.source,
    syncState: syncState ?? this.syncState,
    serverId: serverId.present ? serverId.value : this.serverId,
    kind: kind ?? this.kind,
    merchant: merchant.present ? merchant.value : this.merchant,
    items: items ?? this.items,
    ask: ask.present ? ask.value : this.ask,
    notified: notified ?? this.notified,
    payeeId: payeeId.present ? payeeId.value : this.payeeId,
    amountBand: amountBand ?? this.amountBand,
    dayPart: dayPart ?? this.dayPart,
    fromHistory: fromHistory ?? this.fromHistory,
    error: error.present ? error.value : this.error,
  );
  LocalTransaction copyWithCompanion(LocalTransactionsCompanion data) {
    return LocalTransaction(
      clientTxnId: data.clientTxnId.present
          ? data.clientTxnId.value
          : this.clientTxnId,
      bank: data.bank.present ? data.bank.value : this.bank,
      payeeName: data.payeeName.present ? data.payeeName.value : this.payeeName,
      amountExact: data.amountExact.present
          ? data.amountExact.value
          : this.amountExact,
      occurredOn: data.occurredOn.present
          ? data.occurredOn.value
          : this.occurredOn,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
      ref: data.ref.present ? data.ref.value : this.ref,
      source: data.source.present ? data.source.value : this.source,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      kind: data.kind.present ? data.kind.value : this.kind,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      items: data.items.present ? data.items.value : this.items,
      ask: data.ask.present ? data.ask.value : this.ask,
      notified: data.notified.present ? data.notified.value : this.notified,
      payeeId: data.payeeId.present ? data.payeeId.value : this.payeeId,
      amountBand: data.amountBand.present
          ? data.amountBand.value
          : this.amountBand,
      dayPart: data.dayPart.present ? data.dayPart.value : this.dayPart,
      fromHistory: data.fromHistory.present
          ? data.fromHistory.value
          : this.fromHistory,
      error: data.error.present ? data.error.value : this.error,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransaction(')
          ..write('clientTxnId: $clientTxnId, ')
          ..write('bank: $bank, ')
          ..write('payeeName: $payeeName, ')
          ..write('amountExact: $amountExact, ')
          ..write('occurredOn: $occurredOn, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('ref: $ref, ')
          ..write('source: $source, ')
          ..write('syncState: $syncState, ')
          ..write('serverId: $serverId, ')
          ..write('kind: $kind, ')
          ..write('merchant: $merchant, ')
          ..write('items: $items, ')
          ..write('ask: $ask, ')
          ..write('notified: $notified, ')
          ..write('payeeId: $payeeId, ')
          ..write('amountBand: $amountBand, ')
          ..write('dayPart: $dayPart, ')
          ..write('fromHistory: $fromHistory, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    clientTxnId,
    bank,
    payeeName,
    amountExact,
    occurredOn,
    receivedAt,
    ref,
    source,
    syncState,
    serverId,
    kind,
    merchant,
    items,
    ask,
    notified,
    payeeId,
    amountBand,
    dayPart,
    fromHistory,
    error,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTransaction &&
          other.clientTxnId == this.clientTxnId &&
          other.bank == this.bank &&
          other.payeeName == this.payeeName &&
          other.amountExact == this.amountExact &&
          other.occurredOn == this.occurredOn &&
          other.receivedAt == this.receivedAt &&
          other.ref == this.ref &&
          other.source == this.source &&
          other.syncState == this.syncState &&
          other.serverId == this.serverId &&
          other.kind == this.kind &&
          other.merchant == this.merchant &&
          other.items == this.items &&
          other.ask == this.ask &&
          other.notified == this.notified &&
          other.payeeId == this.payeeId &&
          other.amountBand == this.amountBand &&
          other.dayPart == this.dayPart &&
          other.fromHistory == this.fromHistory &&
          other.error == this.error);
}

class LocalTransactionsCompanion extends UpdateCompanion<LocalTransaction> {
  final Value<String> clientTxnId;
  final Value<String> bank;
  final Value<String> payeeName;
  final Value<double?> amountExact;
  final Value<String> occurredOn;
  final Value<DateTime> receivedAt;
  final Value<String> ref;
  final Value<String> source;
  final Value<String> syncState;
  final Value<String?> serverId;
  final Value<String> kind;
  final Value<String?> merchant;
  final Value<String> items;
  final Value<String?> ask;
  final Value<bool> notified;
  final Value<int?> payeeId;
  final Value<String> amountBand;
  final Value<String> dayPart;
  final Value<bool> fromHistory;
  final Value<String?> error;
  final Value<int> rowid;
  const LocalTransactionsCompanion({
    this.clientTxnId = const Value.absent(),
    this.bank = const Value.absent(),
    this.payeeName = const Value.absent(),
    this.amountExact = const Value.absent(),
    this.occurredOn = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.ref = const Value.absent(),
    this.source = const Value.absent(),
    this.syncState = const Value.absent(),
    this.serverId = const Value.absent(),
    this.kind = const Value.absent(),
    this.merchant = const Value.absent(),
    this.items = const Value.absent(),
    this.ask = const Value.absent(),
    this.notified = const Value.absent(),
    this.payeeId = const Value.absent(),
    this.amountBand = const Value.absent(),
    this.dayPart = const Value.absent(),
    this.fromHistory = const Value.absent(),
    this.error = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTransactionsCompanion.insert({
    required String clientTxnId,
    this.bank = const Value.absent(),
    required String payeeName,
    this.amountExact = const Value.absent(),
    required String occurredOn,
    required DateTime receivedAt,
    this.ref = const Value.absent(),
    this.source = const Value.absent(),
    this.syncState = const Value.absent(),
    this.serverId = const Value.absent(),
    this.kind = const Value.absent(),
    this.merchant = const Value.absent(),
    this.items = const Value.absent(),
    this.ask = const Value.absent(),
    this.notified = const Value.absent(),
    this.payeeId = const Value.absent(),
    required String amountBand,
    this.dayPart = const Value.absent(),
    this.fromHistory = const Value.absent(),
    this.error = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : clientTxnId = Value(clientTxnId),
       payeeName = Value(payeeName),
       occurredOn = Value(occurredOn),
       receivedAt = Value(receivedAt),
       amountBand = Value(amountBand);
  static Insertable<LocalTransaction> custom({
    Expression<String>? clientTxnId,
    Expression<String>? bank,
    Expression<String>? payeeName,
    Expression<double>? amountExact,
    Expression<String>? occurredOn,
    Expression<DateTime>? receivedAt,
    Expression<String>? ref,
    Expression<String>? source,
    Expression<String>? syncState,
    Expression<String>? serverId,
    Expression<String>? kind,
    Expression<String>? merchant,
    Expression<String>? items,
    Expression<String>? ask,
    Expression<bool>? notified,
    Expression<int>? payeeId,
    Expression<String>? amountBand,
    Expression<String>? dayPart,
    Expression<bool>? fromHistory,
    Expression<String>? error,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientTxnId != null) 'client_txn_id': clientTxnId,
      if (bank != null) 'bank': bank,
      if (payeeName != null) 'payee_name': payeeName,
      if (amountExact != null) 'amount_exact': amountExact,
      if (occurredOn != null) 'occurred_on': occurredOn,
      if (receivedAt != null) 'received_at': receivedAt,
      if (ref != null) 'ref': ref,
      if (source != null) 'source': source,
      if (syncState != null) 'sync_state': syncState,
      if (serverId != null) 'server_id': serverId,
      if (kind != null) 'kind': kind,
      if (merchant != null) 'merchant': merchant,
      if (items != null) 'items': items,
      if (ask != null) 'ask': ask,
      if (notified != null) 'notified': notified,
      if (payeeId != null) 'payee_id': payeeId,
      if (amountBand != null) 'amount_band': amountBand,
      if (dayPart != null) 'day_part': dayPart,
      if (fromHistory != null) 'from_history': fromHistory,
      if (error != null) 'error': error,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTransactionsCompanion copyWith({
    Value<String>? clientTxnId,
    Value<String>? bank,
    Value<String>? payeeName,
    Value<double?>? amountExact,
    Value<String>? occurredOn,
    Value<DateTime>? receivedAt,
    Value<String>? ref,
    Value<String>? source,
    Value<String>? syncState,
    Value<String?>? serverId,
    Value<String>? kind,
    Value<String?>? merchant,
    Value<String>? items,
    Value<String?>? ask,
    Value<bool>? notified,
    Value<int?>? payeeId,
    Value<String>? amountBand,
    Value<String>? dayPart,
    Value<bool>? fromHistory,
    Value<String?>? error,
    Value<int>? rowid,
  }) {
    return LocalTransactionsCompanion(
      clientTxnId: clientTxnId ?? this.clientTxnId,
      bank: bank ?? this.bank,
      payeeName: payeeName ?? this.payeeName,
      amountExact: amountExact ?? this.amountExact,
      occurredOn: occurredOn ?? this.occurredOn,
      receivedAt: receivedAt ?? this.receivedAt,
      ref: ref ?? this.ref,
      source: source ?? this.source,
      syncState: syncState ?? this.syncState,
      serverId: serverId ?? this.serverId,
      kind: kind ?? this.kind,
      merchant: merchant ?? this.merchant,
      items: items ?? this.items,
      ask: ask ?? this.ask,
      notified: notified ?? this.notified,
      payeeId: payeeId ?? this.payeeId,
      amountBand: amountBand ?? this.amountBand,
      dayPart: dayPart ?? this.dayPart,
      fromHistory: fromHistory ?? this.fromHistory,
      error: error ?? this.error,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientTxnId.present) {
      map['client_txn_id'] = Variable<String>(clientTxnId.value);
    }
    if (bank.present) {
      map['bank'] = Variable<String>(bank.value);
    }
    if (payeeName.present) {
      map['payee_name'] = Variable<String>(payeeName.value);
    }
    if (amountExact.present) {
      map['amount_exact'] = Variable<double>(amountExact.value);
    }
    if (occurredOn.present) {
      map['occurred_on'] = Variable<String>(occurredOn.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (ref.present) {
      map['ref'] = Variable<String>(ref.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (items.present) {
      map['items'] = Variable<String>(items.value);
    }
    if (ask.present) {
      map['ask'] = Variable<String>(ask.value);
    }
    if (notified.present) {
      map['notified'] = Variable<bool>(notified.value);
    }
    if (payeeId.present) {
      map['payee_id'] = Variable<int>(payeeId.value);
    }
    if (amountBand.present) {
      map['amount_band'] = Variable<String>(amountBand.value);
    }
    if (dayPart.present) {
      map['day_part'] = Variable<String>(dayPart.value);
    }
    if (fromHistory.present) {
      map['from_history'] = Variable<bool>(fromHistory.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransactionsCompanion(')
          ..write('clientTxnId: $clientTxnId, ')
          ..write('bank: $bank, ')
          ..write('payeeName: $payeeName, ')
          ..write('amountExact: $amountExact, ')
          ..write('occurredOn: $occurredOn, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('ref: $ref, ')
          ..write('source: $source, ')
          ..write('syncState: $syncState, ')
          ..write('serverId: $serverId, ')
          ..write('kind: $kind, ')
          ..write('merchant: $merchant, ')
          ..write('items: $items, ')
          ..write('ask: $ask, ')
          ..write('notified: $notified, ')
          ..write('payeeId: $payeeId, ')
          ..write('amountBand: $amountBand, ')
          ..write('dayPart: $dayPart, ')
          ..write('fromHistory: $fromHistory, ')
          ..write('error: $error, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UnparsedMessagesTable extends UnparsedMessages
    with TableInfo<$UnparsedMessagesTable, UnparsedMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UnparsedMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _senderMeta = const VerificationMeta('sender');
  @override
  late final GeneratedColumn<String> sender = GeneratedColumn<String>(
    'sender',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
    'received_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sender, receivedAt, body];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'unparsed_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<UnparsedMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sender')) {
      context.handle(
        _senderMeta,
        sender.isAcceptableOrUnknown(data['sender']!, _senderMeta),
      );
    } else if (isInserting) {
      context.missing(_senderMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UnparsedMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UnparsedMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
    );
  }

  @override
  $UnparsedMessagesTable createAlias(String alias) {
    return $UnparsedMessagesTable(attachedDatabase, alias);
  }
}

class UnparsedMessage extends DataClass implements Insertable<UnparsedMessage> {
  final int id;
  final String sender;
  final DateTime receivedAt;
  final String body;
  const UnparsedMessage({
    required this.id,
    required this.sender,
    required this.receivedAt,
    required this.body,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sender'] = Variable<String>(sender);
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['body'] = Variable<String>(body);
    return map;
  }

  UnparsedMessagesCompanion toCompanion(bool nullToAbsent) {
    return UnparsedMessagesCompanion(
      id: Value(id),
      sender: Value(sender),
      receivedAt: Value(receivedAt),
      body: Value(body),
    );
  }

  factory UnparsedMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UnparsedMessage(
      id: serializer.fromJson<int>(json['id']),
      sender: serializer.fromJson<String>(json['sender']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      body: serializer.fromJson<String>(json['body']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sender': serializer.toJson<String>(sender),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'body': serializer.toJson<String>(body),
    };
  }

  UnparsedMessage copyWith({
    int? id,
    String? sender,
    DateTime? receivedAt,
    String? body,
  }) => UnparsedMessage(
    id: id ?? this.id,
    sender: sender ?? this.sender,
    receivedAt: receivedAt ?? this.receivedAt,
    body: body ?? this.body,
  );
  UnparsedMessage copyWithCompanion(UnparsedMessagesCompanion data) {
    return UnparsedMessage(
      id: data.id.present ? data.id.value : this.id,
      sender: data.sender.present ? data.sender.value : this.sender,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
      body: data.body.present ? data.body.value : this.body,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UnparsedMessage(')
          ..write('id: $id, ')
          ..write('sender: $sender, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('body: $body')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sender, receivedAt, body);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnparsedMessage &&
          other.id == this.id &&
          other.sender == this.sender &&
          other.receivedAt == this.receivedAt &&
          other.body == this.body);
}

class UnparsedMessagesCompanion extends UpdateCompanion<UnparsedMessage> {
  final Value<int> id;
  final Value<String> sender;
  final Value<DateTime> receivedAt;
  final Value<String> body;
  const UnparsedMessagesCompanion({
    this.id = const Value.absent(),
    this.sender = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.body = const Value.absent(),
  });
  UnparsedMessagesCompanion.insert({
    this.id = const Value.absent(),
    required String sender,
    required DateTime receivedAt,
    required String body,
  }) : sender = Value(sender),
       receivedAt = Value(receivedAt),
       body = Value(body);
  static Insertable<UnparsedMessage> custom({
    Expression<int>? id,
    Expression<String>? sender,
    Expression<DateTime>? receivedAt,
    Expression<String>? body,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sender != null) 'sender': sender,
      if (receivedAt != null) 'received_at': receivedAt,
      if (body != null) 'body': body,
    });
  }

  UnparsedMessagesCompanion copyWith({
    Value<int>? id,
    Value<String>? sender,
    Value<DateTime>? receivedAt,
    Value<String>? body,
  }) {
    return UnparsedMessagesCompanion(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      receivedAt: receivedAt ?? this.receivedAt,
      body: body ?? this.body,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UnparsedMessagesCompanion(')
          ..write('id: $id, ')
          ..write('sender: $sender, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('body: $body')
          ..write(')'))
        .toString();
  }
}

class $ParserTemplatesTable extends ParserTemplates
    with TableInfo<$ParserTemplatesTable, CachedTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParserTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parser_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $ParserTemplatesTable createAlias(String alias) {
    return $ParserTemplatesTable(attachedDatabase, alias);
  }
}

class CachedTemplate extends DataClass implements Insertable<CachedTemplate> {
  final int id;
  final String json;
  const CachedTemplate({required this.id, required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['json'] = Variable<String>(json);
    return map;
  }

  ParserTemplatesCompanion toCompanion(bool nullToAbsent) {
    return ParserTemplatesCompanion(id: Value(id), json: Value(json));
  }

  factory CachedTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedTemplate(
      id: serializer.fromJson<int>(json['id']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'json': serializer.toJson<String>(json),
    };
  }

  CachedTemplate copyWith({int? id, String? json}) =>
      CachedTemplate(id: id ?? this.id, json: json ?? this.json);
  CachedTemplate copyWithCompanion(ParserTemplatesCompanion data) {
    return CachedTemplate(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedTemplate(')
          ..write('id: $id, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedTemplate &&
          other.id == this.id &&
          other.json == this.json);
}

class ParserTemplatesCompanion extends UpdateCompanion<CachedTemplate> {
  final Value<int> id;
  final Value<String> json;
  const ParserTemplatesCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
  });
  ParserTemplatesCompanion.insert({
    this.id = const Value.absent(),
    required String json,
  }) : json = Value(json);
  static Insertable<CachedTemplate> custom({
    Expression<int>? id,
    Expression<String>? json,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
    });
  }

  ParserTemplatesCompanion copyWith({Value<int>? id, Value<String>? json}) {
    return ParserTemplatesCompanion(id: id ?? this.id, json: json ?? this.json);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParserTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingActionsTable extends PendingActions
    with TableInfo<$PendingActionsTable, PendingAction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingActionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clientTxnIdMeta = const VerificationMeta(
    'clientTxnId',
  );
  @override
  late final GeneratedColumn<String> clientTxnId = GeneratedColumn<String>(
    'client_txn_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, clientTxnId, type, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_actions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingAction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_txn_id')) {
      context.handle(
        _clientTxnIdMeta,
        clientTxnId.isAcceptableOrUnknown(
          data['client_txn_id']!,
          _clientTxnIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientTxnIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingAction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingAction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientTxnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_txn_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingActionsTable createAlias(String alias) {
    return $PendingActionsTable(attachedDatabase, alias);
  }
}

class PendingAction extends DataClass implements Insertable<PendingAction> {
  final int id;
  final String clientTxnId;

  /// 'person' or 'confirm_items'.
  final String type;
  final DateTime createdAt;
  const PendingAction({
    required this.id,
    required this.clientTxnId,
    required this.type,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_txn_id'] = Variable<String>(clientTxnId);
    map['type'] = Variable<String>(type);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingActionsCompanion toCompanion(bool nullToAbsent) {
    return PendingActionsCompanion(
      id: Value(id),
      clientTxnId: Value(clientTxnId),
      type: Value(type),
      createdAt: Value(createdAt),
    );
  }

  factory PendingAction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingAction(
      id: serializer.fromJson<int>(json['id']),
      clientTxnId: serializer.fromJson<String>(json['clientTxnId']),
      type: serializer.fromJson<String>(json['type']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientTxnId': serializer.toJson<String>(clientTxnId),
      'type': serializer.toJson<String>(type),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingAction copyWith({
    int? id,
    String? clientTxnId,
    String? type,
    DateTime? createdAt,
  }) => PendingAction(
    id: id ?? this.id,
    clientTxnId: clientTxnId ?? this.clientTxnId,
    type: type ?? this.type,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingAction copyWithCompanion(PendingActionsCompanion data) {
    return PendingAction(
      id: data.id.present ? data.id.value : this.id,
      clientTxnId: data.clientTxnId.present
          ? data.clientTxnId.value
          : this.clientTxnId,
      type: data.type.present ? data.type.value : this.type,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingAction(')
          ..write('id: $id, ')
          ..write('clientTxnId: $clientTxnId, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, clientTxnId, type, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingAction &&
          other.id == this.id &&
          other.clientTxnId == this.clientTxnId &&
          other.type == this.type &&
          other.createdAt == this.createdAt);
}

class PendingActionsCompanion extends UpdateCompanion<PendingAction> {
  final Value<int> id;
  final Value<String> clientTxnId;
  final Value<String> type;
  final Value<DateTime> createdAt;
  const PendingActionsCompanion({
    this.id = const Value.absent(),
    this.clientTxnId = const Value.absent(),
    this.type = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PendingActionsCompanion.insert({
    this.id = const Value.absent(),
    required String clientTxnId,
    required String type,
    required DateTime createdAt,
  }) : clientTxnId = Value(clientTxnId),
       type = Value(type),
       createdAt = Value(createdAt);
  static Insertable<PendingAction> custom({
    Expression<int>? id,
    Expression<String>? clientTxnId,
    Expression<String>? type,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientTxnId != null) 'client_txn_id': clientTxnId,
      if (type != null) 'type': type,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PendingActionsCompanion copyWith({
    Value<int>? id,
    Value<String>? clientTxnId,
    Value<String>? type,
    Value<DateTime>? createdAt,
  }) {
    return PendingActionsCompanion(
      id: id ?? this.id,
      clientTxnId: clientTxnId ?? this.clientTxnId,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientTxnId.present) {
      map['client_txn_id'] = Variable<String>(clientTxnId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingActionsCompanion(')
          ..write('id: $id, ')
          ..write('clientTxnId: $clientTxnId, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalTransactionsTable localTransactions =
      $LocalTransactionsTable(this);
  late final $UnparsedMessagesTable unparsedMessages = $UnparsedMessagesTable(
    this,
  );
  late final $ParserTemplatesTable parserTemplates = $ParserTemplatesTable(
    this,
  );
  late final $SettingsTable settings = $SettingsTable(this);
  late final $PendingActionsTable pendingActions = $PendingActionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localTransactions,
    unparsedMessages,
    parserTemplates,
    settings,
    pendingActions,
  ];
}

typedef $$LocalTransactionsTableCreateCompanionBuilder =
    LocalTransactionsCompanion Function({
      required String clientTxnId,
      Value<String> bank,
      required String payeeName,
      Value<double?> amountExact,
      required String occurredOn,
      required DateTime receivedAt,
      Value<String> ref,
      Value<String> source,
      Value<String> syncState,
      Value<String?> serverId,
      Value<String> kind,
      Value<String?> merchant,
      Value<String> items,
      Value<String?> ask,
      Value<bool> notified,
      Value<int?> payeeId,
      required String amountBand,
      Value<String> dayPart,
      Value<bool> fromHistory,
      Value<String?> error,
      Value<int> rowid,
    });
typedef $$LocalTransactionsTableUpdateCompanionBuilder =
    LocalTransactionsCompanion Function({
      Value<String> clientTxnId,
      Value<String> bank,
      Value<String> payeeName,
      Value<double?> amountExact,
      Value<String> occurredOn,
      Value<DateTime> receivedAt,
      Value<String> ref,
      Value<String> source,
      Value<String> syncState,
      Value<String?> serverId,
      Value<String> kind,
      Value<String?> merchant,
      Value<String> items,
      Value<String?> ask,
      Value<bool> notified,
      Value<int?> payeeId,
      Value<String> amountBand,
      Value<String> dayPart,
      Value<bool> fromHistory,
      Value<String?> error,
      Value<int> rowid,
    });

class $$LocalTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientTxnId => $composableBuilder(
    column: $table.clientTxnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bank => $composableBuilder(
    column: $table.bank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payeeName => $composableBuilder(
    column: $table.payeeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amountExact => $composableBuilder(
    column: $table.amountExact,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurredOn => $composableBuilder(
    column: $table.occurredOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ref => $composableBuilder(
    column: $table.ref,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get items => $composableBuilder(
    column: $table.items,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ask => $composableBuilder(
    column: $table.ask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notified => $composableBuilder(
    column: $table.notified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get payeeId => $composableBuilder(
    column: $table.payeeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amountBand => $composableBuilder(
    column: $table.amountBand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayPart => $composableBuilder(
    column: $table.dayPart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fromHistory => $composableBuilder(
    column: $table.fromHistory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientTxnId => $composableBuilder(
    column: $table.clientTxnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bank => $composableBuilder(
    column: $table.bank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payeeName => $composableBuilder(
    column: $table.payeeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amountExact => $composableBuilder(
    column: $table.amountExact,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurredOn => $composableBuilder(
    column: $table.occurredOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ref => $composableBuilder(
    column: $table.ref,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get items => $composableBuilder(
    column: $table.items,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ask => $composableBuilder(
    column: $table.ask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notified => $composableBuilder(
    column: $table.notified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get payeeId => $composableBuilder(
    column: $table.payeeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amountBand => $composableBuilder(
    column: $table.amountBand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayPart => $composableBuilder(
    column: $table.dayPart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fromHistory => $composableBuilder(
    column: $table.fromHistory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientTxnId => $composableBuilder(
    column: $table.clientTxnId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bank =>
      $composableBuilder(column: $table.bank, builder: (column) => column);

  GeneratedColumn<String> get payeeName =>
      $composableBuilder(column: $table.payeeName, builder: (column) => column);

  GeneratedColumn<double> get amountExact => $composableBuilder(
    column: $table.amountExact,
    builder: (column) => column,
  );

  GeneratedColumn<String> get occurredOn => $composableBuilder(
    column: $table.occurredOn,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ref =>
      $composableBuilder(column: $table.ref, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumn<String> get items =>
      $composableBuilder(column: $table.items, builder: (column) => column);

  GeneratedColumn<String> get ask =>
      $composableBuilder(column: $table.ask, builder: (column) => column);

  GeneratedColumn<bool> get notified =>
      $composableBuilder(column: $table.notified, builder: (column) => column);

  GeneratedColumn<int> get payeeId =>
      $composableBuilder(column: $table.payeeId, builder: (column) => column);

  GeneratedColumn<String> get amountBand => $composableBuilder(
    column: $table.amountBand,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dayPart =>
      $composableBuilder(column: $table.dayPart, builder: (column) => column);

  GeneratedColumn<bool> get fromHistory => $composableBuilder(
    column: $table.fromHistory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);
}

class $$LocalTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalTransactionsTable,
          LocalTransaction,
          $$LocalTransactionsTableFilterComposer,
          $$LocalTransactionsTableOrderingComposer,
          $$LocalTransactionsTableAnnotationComposer,
          $$LocalTransactionsTableCreateCompanionBuilder,
          $$LocalTransactionsTableUpdateCompanionBuilder,
          (
            LocalTransaction,
            BaseReferences<
              _$AppDatabase,
              $LocalTransactionsTable,
              LocalTransaction
            >,
          ),
          LocalTransaction,
          PrefetchHooks Function()
        > {
  $$LocalTransactionsTableTableManager(
    _$AppDatabase db,
    $LocalTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> clientTxnId = const Value.absent(),
                Value<String> bank = const Value.absent(),
                Value<String> payeeName = const Value.absent(),
                Value<double?> amountExact = const Value.absent(),
                Value<String> occurredOn = const Value.absent(),
                Value<DateTime> receivedAt = const Value.absent(),
                Value<String> ref = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> merchant = const Value.absent(),
                Value<String> items = const Value.absent(),
                Value<String?> ask = const Value.absent(),
                Value<bool> notified = const Value.absent(),
                Value<int?> payeeId = const Value.absent(),
                Value<String> amountBand = const Value.absent(),
                Value<String> dayPart = const Value.absent(),
                Value<bool> fromHistory = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTransactionsCompanion(
                clientTxnId: clientTxnId,
                bank: bank,
                payeeName: payeeName,
                amountExact: amountExact,
                occurredOn: occurredOn,
                receivedAt: receivedAt,
                ref: ref,
                source: source,
                syncState: syncState,
                serverId: serverId,
                kind: kind,
                merchant: merchant,
                items: items,
                ask: ask,
                notified: notified,
                payeeId: payeeId,
                amountBand: amountBand,
                dayPart: dayPart,
                fromHistory: fromHistory,
                error: error,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String clientTxnId,
                Value<String> bank = const Value.absent(),
                required String payeeName,
                Value<double?> amountExact = const Value.absent(),
                required String occurredOn,
                required DateTime receivedAt,
                Value<String> ref = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> merchant = const Value.absent(),
                Value<String> items = const Value.absent(),
                Value<String?> ask = const Value.absent(),
                Value<bool> notified = const Value.absent(),
                Value<int?> payeeId = const Value.absent(),
                required String amountBand,
                Value<String> dayPart = const Value.absent(),
                Value<bool> fromHistory = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTransactionsCompanion.insert(
                clientTxnId: clientTxnId,
                bank: bank,
                payeeName: payeeName,
                amountExact: amountExact,
                occurredOn: occurredOn,
                receivedAt: receivedAt,
                ref: ref,
                source: source,
                syncState: syncState,
                serverId: serverId,
                kind: kind,
                merchant: merchant,
                items: items,
                ask: ask,
                notified: notified,
                payeeId: payeeId,
                amountBand: amountBand,
                dayPart: dayPart,
                fromHistory: fromHistory,
                error: error,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalTransactionsTable, LocalTransaction>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalTransactionsTable,
                    LocalTransaction
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalTransactionsTable,
      LocalTransaction,
      $$LocalTransactionsTableFilterComposer,
      $$LocalTransactionsTableOrderingComposer,
      $$LocalTransactionsTableAnnotationComposer,
      $$LocalTransactionsTableCreateCompanionBuilder,
      $$LocalTransactionsTableUpdateCompanionBuilder,
      (
        LocalTransaction,
        BaseReferences<
          _$AppDatabase,
          $LocalTransactionsTable,
          LocalTransaction
        >,
      ),
      LocalTransaction,
      PrefetchHooks Function()
    >;
typedef $$UnparsedMessagesTableCreateCompanionBuilder =
    UnparsedMessagesCompanion Function({
      Value<int> id,
      required String sender,
      required DateTime receivedAt,
      required String body,
    });
typedef $$UnparsedMessagesTableUpdateCompanionBuilder =
    UnparsedMessagesCompanion Function({
      Value<int> id,
      Value<String> sender,
      Value<DateTime> receivedAt,
      Value<String> body,
    });

class $$UnparsedMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $UnparsedMessagesTable> {
  $$UnparsedMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UnparsedMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $UnparsedMessagesTable> {
  $$UnparsedMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UnparsedMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UnparsedMessagesTable> {
  $$UnparsedMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sender =>
      $composableBuilder(column: $table.sender, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);
}

class $$UnparsedMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UnparsedMessagesTable,
          UnparsedMessage,
          $$UnparsedMessagesTableFilterComposer,
          $$UnparsedMessagesTableOrderingComposer,
          $$UnparsedMessagesTableAnnotationComposer,
          $$UnparsedMessagesTableCreateCompanionBuilder,
          $$UnparsedMessagesTableUpdateCompanionBuilder,
          (
            UnparsedMessage,
            BaseReferences<
              _$AppDatabase,
              $UnparsedMessagesTable,
              UnparsedMessage
            >,
          ),
          UnparsedMessage,
          PrefetchHooks Function()
        > {
  $$UnparsedMessagesTableTableManager(
    _$AppDatabase db,
    $UnparsedMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UnparsedMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UnparsedMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UnparsedMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sender = const Value.absent(),
                Value<DateTime> receivedAt = const Value.absent(),
                Value<String> body = const Value.absent(),
              }) => UnparsedMessagesCompanion(
                id: id,
                sender: sender,
                receivedAt: receivedAt,
                body: body,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sender,
                required DateTime receivedAt,
                required String body,
              }) => UnparsedMessagesCompanion.insert(
                id: id,
                sender: sender,
                receivedAt: receivedAt,
                body: body,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UnparsedMessagesTable, UnparsedMessage>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $UnparsedMessagesTable,
                    UnparsedMessage
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UnparsedMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UnparsedMessagesTable,
      UnparsedMessage,
      $$UnparsedMessagesTableFilterComposer,
      $$UnparsedMessagesTableOrderingComposer,
      $$UnparsedMessagesTableAnnotationComposer,
      $$UnparsedMessagesTableCreateCompanionBuilder,
      $$UnparsedMessagesTableUpdateCompanionBuilder,
      (
        UnparsedMessage,
        BaseReferences<_$AppDatabase, $UnparsedMessagesTable, UnparsedMessage>,
      ),
      UnparsedMessage,
      PrefetchHooks Function()
    >;
typedef $$ParserTemplatesTableCreateCompanionBuilder =
    ParserTemplatesCompanion Function({Value<int> id, required String json});
typedef $$ParserTemplatesTableUpdateCompanionBuilder =
    ParserTemplatesCompanion Function({Value<int> id, Value<String> json});

class $$ParserTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $ParserTemplatesTable> {
  $$ParserTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ParserTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $ParserTemplatesTable> {
  $$ParserTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ParserTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParserTemplatesTable> {
  $$ParserTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$ParserTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ParserTemplatesTable,
          CachedTemplate,
          $$ParserTemplatesTableFilterComposer,
          $$ParserTemplatesTableOrderingComposer,
          $$ParserTemplatesTableAnnotationComposer,
          $$ParserTemplatesTableCreateCompanionBuilder,
          $$ParserTemplatesTableUpdateCompanionBuilder,
          (
            CachedTemplate,
            BaseReferences<
              _$AppDatabase,
              $ParserTemplatesTable,
              CachedTemplate
            >,
          ),
          CachedTemplate,
          PrefetchHooks Function()
        > {
  $$ParserTemplatesTableTableManager(
    _$AppDatabase db,
    $ParserTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParserTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParserTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParserTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> json = const Value.absent(),
              }) => ParserTemplatesCompanion(id: id, json: json),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String json}) =>
                  ParserTemplatesCompanion.insert(id: id, json: json),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ParserTemplatesTable, CachedTemplate>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ParserTemplatesTable,
                    CachedTemplate
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ParserTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ParserTemplatesTable,
      CachedTemplate,
      $$ParserTemplatesTableFilterComposer,
      $$ParserTemplatesTableOrderingComposer,
      $$ParserTemplatesTableAnnotationComposer,
      $$ParserTemplatesTableCreateCompanionBuilder,
      $$ParserTemplatesTableUpdateCompanionBuilder,
      (
        CachedTemplate,
        BaseReferences<_$AppDatabase, $ParserTemplatesTable, CachedTemplate>,
      ),
      CachedTemplate,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, Setting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$PendingActionsTableCreateCompanionBuilder =
    PendingActionsCompanion Function({
      Value<int> id,
      required String clientTxnId,
      required String type,
      required DateTime createdAt,
    });
typedef $$PendingActionsTableUpdateCompanionBuilder =
    PendingActionsCompanion Function({
      Value<int> id,
      Value<String> clientTxnId,
      Value<String> type,
      Value<DateTime> createdAt,
    });

class $$PendingActionsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientTxnId => $composableBuilder(
    column: $table.clientTxnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingActionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientTxnId => $composableBuilder(
    column: $table.clientTxnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingActionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientTxnId => $composableBuilder(
    column: $table.clientTxnId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingActionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingActionsTable,
          PendingAction,
          $$PendingActionsTableFilterComposer,
          $$PendingActionsTableOrderingComposer,
          $$PendingActionsTableAnnotationComposer,
          $$PendingActionsTableCreateCompanionBuilder,
          $$PendingActionsTableUpdateCompanionBuilder,
          (
            PendingAction,
            BaseReferences<_$AppDatabase, $PendingActionsTable, PendingAction>,
          ),
          PendingAction,
          PrefetchHooks Function()
        > {
  $$PendingActionsTableTableManager(
    _$AppDatabase db,
    $PendingActionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingActionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingActionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientTxnId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PendingActionsCompanion(
                id: id,
                clientTxnId: clientTxnId,
                type: type,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientTxnId,
                required String type,
                required DateTime createdAt,
              }) => PendingActionsCompanion.insert(
                id: id,
                clientTxnId: clientTxnId,
                type: type,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingActionsTable, PendingAction>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PendingActionsTable,
                    PendingAction
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingActionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingActionsTable,
      PendingAction,
      $$PendingActionsTableFilterComposer,
      $$PendingActionsTableOrderingComposer,
      $$PendingActionsTableAnnotationComposer,
      $$PendingActionsTableCreateCompanionBuilder,
      $$PendingActionsTableUpdateCompanionBuilder,
      (
        PendingAction,
        BaseReferences<_$AppDatabase, $PendingActionsTable, PendingAction>,
      ),
      PendingAction,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalTransactionsTableTableManager get localTransactions =>
      $$LocalTransactionsTableTableManager(_db, _db.localTransactions);
  $$UnparsedMessagesTableTableManager get unparsedMessages =>
      $$UnparsedMessagesTableTableManager(_db, _db.unparsedMessages);
  $$ParserTemplatesTableTableManager get parserTemplates =>
      $$ParserTemplatesTableTableManager(_db, _db.parserTemplates);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$PendingActionsTableTableManager get pendingActions =>
      $$PendingActionsTableTableManager(_db, _db.pendingActions);
}
