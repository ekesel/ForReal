import 'dart:convert';

/// Typed views of the backend's JSON. Field names follow the serializers in
/// backend/apps/*/serializers.py.

Map<String, dynamic> asMap(Object? value) => Map<String, dynamic>.from(value as Map);

class User {
  const User({required this.id, required this.phone, required this.displayName});
  final String id;
  final String phone;
  final String displayName;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        phone: json['phone'] as String,
        displayName: json['display_name'] as String? ?? '',
      );
}

class OtpRequestResult {
  const OtpRequestResult({required this.expiresIn, this.debugCode});
  final int expiresIn;

  /// Present only when the backend runs with OTP_ECHO_IN_RESPONSE (development).
  final String? debugCode;

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) => OtpRequestResult(
        expiresIn: (json['expires_in'] as num?)?.toInt() ?? 300,
        debugCode: json['debug_code'] as String?,
      );
}

class AuthSession {
  const AuthSession({required this.access, required this.refresh, required this.isNewUser, required this.user});
  final String access;
  final String refresh;
  final bool isNewUser;
  final User user;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        access: json['access'] as String,
        refresh: json['refresh'] as String,
        isNewUser: json['is_new_user'] as bool? ?? false,
        user: User.fromJson(asMap(json['user'])),
      );
}

/// The five consent purposes, named as the backend names them.
enum Purpose {
  privateAnalytics('private_analytics'),
  communityRankings('community_rankings'),
  showName('show_name'),
  location('location'),
  merchantInsights('merchant_insights');

  const Purpose(this.wire);
  final String wire;

  /// The purpose that must be granted first, as enforced by the server.
  Purpose? get requires => switch (this) {
        Purpose.privateAnalytics => null,
        Purpose.communityRankings => Purpose.privateAnalytics,
        Purpose.location => Purpose.privateAnalytics,
        Purpose.showName => Purpose.communityRankings,
        Purpose.merchantInsights => Purpose.communityRankings,
      };
}

class ConsentState {
  const ConsentState(this._granted);
  const ConsentState.none() : _granted = const {};

  final Map<String, bool> _granted;

  bool has(Purpose purpose) => _granted[purpose.wire] ?? false;

  factory ConsentState.fromJson(Map<String, dynamic> json) =>
      ConsentState({for (final e in json.entries) e.key: e.value == true});

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_granted);

  String encode() => jsonEncode(toJson());
  static ConsentState decode(String? text) {
    if (text == null || text.isEmpty) return const ConsentState.none();
    try {
      return ConsentState.fromJson(asMap(jsonDecode(text)));
    } catch (_) {
      return const ConsentState.none();
    }
  }
}

class LatLng {
  const LatLng(this.lat, this.lng);
  final double lat;
  final double lng;

  /// The backend rounds to 3 decimals (about 110 m). Round here as well, so a
  /// precise position never leaves the device.
  LatLng get coarse => LatLng(_round3(lat), _round3(lng));

  static double _round3(double v) => (v * 1000).roundToDouble() / 1000;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class Category {
  const Category({required this.slug, required this.name});
  final String slug;
  final String name;

  factory Category.fromJson(Map<String, dynamic> json) =>
      Category(slug: json['slug'] as String, name: json['name'] as String);
}

class Merchant {
  const Merchant({required this.id, required this.name, required this.category, required this.isOnline});
  final String id;
  final String name;
  final String category;
  final bool isOnline;

  factory Merchant.fromJson(Map<String, dynamic> json) => Merchant(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String? ?? '',
        isOnline: json['is_online'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'category': category, 'is_online': isOnline};

  static Merchant? decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      return Merchant.fromJson(asMap(jsonDecode(text)));
    } catch (_) {
      return null;
    }
  }
}

class Item {
  const Item({required this.id, required this.name, this.category});
  final int id;
  final String name;
  final String? category;

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        category: json['category'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'category': category};
}

/// One thing bought in a payment, as the server holds it.
class TaggedItem {
  const TaggedItem({
    required this.item,
    required this.quantity,
    required this.origin,
    required this.confidence,
    required this.inferred,
  });

  final Item item;
  final int quantity;
  final String origin;
  final double confidence;

  /// True while it is the app's guess and not the user's own answer.
  final bool inferred;

  factory TaggedItem.fromJson(Map<String, dynamic> json) {
    final origin = json['origin'] as String? ?? 'user';
    return TaggedItem(
      item: Item.fromJson(asMap(json['item'])),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      origin: origin,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      inferred: json['inferred'] as bool? ?? origin != 'user',
    );
  }

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        'quantity': quantity,
        'origin': origin,
        'confidence': confidence,
        'inferred': inferred,
      };

  static List<TaggedItem> decodeList(String? text) {
    if (text == null || text.isEmpty) return const [];
    try {
      return [for (final e in jsonDecode(text) as List) TaggedItem.fromJson(asMap(e))];
    } catch (_) {
      return const [];
    }
  }

  static String encodeList(List<TaggedItem> items) => jsonEncode([for (final i in items) i.toJson()]);
}

class PayeeRef {
  const PayeeRef({required this.id, required this.name});
  final int id;
  final String name;

  factory PayeeRef.fromJson(Map<String, dynamic> json) =>
      PayeeRef(id: (json['id'] as num).toInt(), name: json['name'] as String);
}

class ServerTransaction {
  const ServerTransaction({
    required this.id,
    required this.clientTxnId,
    required this.payee,
    required this.merchant,
    required this.kind,
    required this.occurredOn,
    required this.dayPart,
    required this.amountBand,
    required this.sources,
    required this.hasLocation,
    required this.items,
    required this.createdAt,
  });

  final String id;
  final String clientTxnId;
  final PayeeRef payee;
  final Merchant? merchant;

  /// unknown, merchant or person.
  final String kind;
  final String occurredOn;
  final String dayPart;
  final String amountBand;
  final List<String> sources;
  final bool hasLocation;
  final List<TaggedItem> items;
  final DateTime createdAt;

  factory ServerTransaction.fromJson(Map<String, dynamic> json) => ServerTransaction(
        id: json['id'] as String,
        clientTxnId: json['client_txn_id'] as String,
        payee: PayeeRef.fromJson(asMap(json['payee'])),
        merchant: json['merchant'] == null ? null : Merchant.fromJson(asMap(json['merchant'])),
        kind: json['kind'] as String? ?? 'unknown',
        occurredOn: json['occurred_on'] as String,
        dayPart: json['day_part'] as String? ?? '',
        amountBand: json['amount_band'] as String,
        sources: [for (final s in json['sources'] as List? ?? const []) s as String],
        hasLocation: json['location'] != null,
        items: [for (final i in json['items'] as List? ?? const []) TaggedItem.fromJson(asMap(i))],
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// One row of POST transactions/batch/. Only what the server may hold: no amount,
/// no message text, no account digits, no VPA.
class IngestRow {
  const IngestRow({
    required this.clientTxnId,
    required this.payeeName,
    required this.occurredOn,
    required this.dayPart,
    required this.amountBand,
    this.source = 'sms',
    this.ref = '',
    this.location,
  });

  final String clientTxnId;
  final String payeeName;
  final String occurredOn;
  final String dayPart;
  final String amountBand;
  final String source;
  final String ref;
  final LatLng? location;

  Map<String, dynamic> toJson() => {
        'client_txn_id': clientTxnId,
        'payee_name': payeeName,
        'occurred_on': occurredOn,
        if (dayPart.isNotEmpty) 'day_part': dayPart,
        'amount_band': amountBand,
        'source': source,
        if (ref.isNotEmpty) 'ref': ref,
        if (location != null) ...location!.coarse.toJson(),
      };
}

class IngestResult {
  const IngestResult({required this.status, required this.transaction, required this.ask, required this.payeeSuggestions});

  /// created, duplicate or merged. All three mean the payment is on the server.
  final String status;
  final ServerTransaction transaction;

  /// What to ask the user: 'payee', 'items' or null.
  final String? ask;
  final List<Merchant> payeeSuggestions;

  factory IngestResult.fromJson(Map<String, dynamic> json) => IngestResult(
        status: json['status'] as String,
        transaction: ServerTransaction.fromJson(asMap(json['transaction'])),
        ask: json['ask'] as String?,
        payeeSuggestions: [
          for (final m in json['payee_suggestions'] as List? ?? const []) Merchant.fromJson(asMap(m)),
        ],
      );
}

class TransactionPage {
  const TransactionPage({required this.results, required this.next});
  final List<ServerTransaction> results;

  /// Absolute URL of the next page, or null on the last one.
  final String? next;
}

class ItemSuggestion {
  const ItemSuggestion({required this.item, required this.quantity, required this.origin});
  final Item item;
  final int quantity;
  final String origin;

  factory ItemSuggestion.fromJson(Map<String, dynamic> json) => ItemSuggestion(
        item: Item.fromJson(asMap(json['item'])),
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        origin: json['origin'] as String? ?? '',
      );
}

class ItemSuggestions {
  const ItemSuggestions({required this.suggestions, required this.shouldPrompt});
  final List<ItemSuggestion> suggestions;
  final bool shouldPrompt;
}

/// What the user picked on the item screen: a catalogue item or free text.
class ItemEntry {
  const ItemEntry.catalogue(int this.itemId, this.quantity) : name = null;
  const ItemEntry.named(String this.name, this.quantity) : itemId = null;

  final int? itemId;
  final String? name;
  final int quantity;

  Map<String, dynamic> toJson() => {
        if (itemId != null) 'item_id': itemId,
        if (name != null) 'name': name,
        'quantity': quantity,
      };
}

class NewMerchant {
  const NewMerchant({required this.name, required this.category, this.isOnline = false});
  final String name;
  final String category;
  final bool isOnline;

  Map<String, dynamic> toJson() => {'name': name, 'category': category, 'is_online': isOnline};
}

class ResolveResult {
  const ResolveResult({required this.payee, required this.kind, required this.merchant});
  final PayeeRef payee;
  final String kind;
  final Merchant? merchant;

  factory ResolveResult.fromJson(Map<String, dynamic> json) => ResolveResult(
        payee: PayeeRef.fromJson(asMap(json['payee'])),
        kind: json['kind'] as String,
        merchant: json['merchant'] == null ? null : Merchant.fromJson(asMap(json['merchant'])),
      );
}

class TemplatesResponse {
  const TemplatesResponse({required this.version, required this.changed, required this.templates});
  final int version;
  final bool changed;

  /// Raw template maps; parsed by the capture layer. Empty when [changed] is false.
  final List<Map<String, dynamic>> templates;
}
