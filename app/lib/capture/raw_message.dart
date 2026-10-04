/// A bank message exactly as the platform delivered it. Lives only on the device
/// and only until it is parsed.
class RawMessage {
  const RawMessage({
    required this.sender,
    required this.receivedAt,
    required this.body,
    this.queueId,
  });

  final String sender;
  final DateTime receivedAt;
  final String body;

  /// Position in the native queue, when the message came from it. Used to
  /// acknowledge the message once it is safely stored.
  final int? queueId;

  factory RawMessage.fromPlatform(Map<Object?, Object?> map) {
    final id = (map['id'] as num?)?.toInt();
    return RawMessage(
      sender: map['sender']! as String,
      receivedAt: DateTime.fromMillisecondsSinceEpoch((map['receivedAt']! as num).toInt()),
      body: map['body']! as String,
      queueId: id == null || id < 0 ? null : id,
    );
  }
}
