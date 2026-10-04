/// Dart mirror of the Kotlin SenderFilter: finds the bank sender code inside an SMS
/// sender id such as "AD-HDFCBK" or "VM-HDFCBK-S".
///
/// The operator prefix (two characters) and the regulatory suffix (one character)
/// are ignored; the remaining header must equal an allowed code exactly.
String? matchSenderCode(String? sender, Iterable<String> allowedCodes) {
  if (sender == null || sender.trim().isEmpty) return null;
  final allowed = {
    for (final c in allowedCodes)
      if (c.trim().isNotEmpty) c.trim().toUpperCase(),
  };
  if (allowed.isEmpty) return null;
  final upper = sender.trim().toUpperCase();
  var parts = upper.split('-').where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2 && parts.first.length == 2) parts = parts.sublist(1);
  if (parts.length >= 2 && parts.last.length == 1) parts = parts.sublist(0, parts.length - 1);
  if (parts.length != 1) return null;
  final header = parts.single;
  if (allowed.contains(header)) return header;
  // Older handsets show the operator prefix glued on: "ADHDFCBK".
  if (!upper.contains('-') && header.length > 2 && _isLetter(header[0]) && _isLetter(header[1])) {
    final rest = header.substring(2);
    if (allowed.contains(rest)) return rest;
  }
  return null;
}

bool _isLetter(String ch) => RegExp(r'^[A-Z]$').hasMatch(ch);
