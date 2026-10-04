import '../../data/models.dart';

/// Approximate position of the user, only while the app is on screen.
///
/// The app asks for coarse location only and never in the background. Every
/// position is rounded to about 110 m before it leaves this class.
abstract class LocationService {
  /// A fix taken no longer than [maxAge] ago, or null. Never triggers a new fix.
  LatLng? recentFix({Duration maxAge = const Duration(minutes: 2)});

  /// Takes a fix now if the location consent and the OS permission are both
  /// granted and the app is in the foreground. Null otherwise.
  Future<LatLng?> currentFix();

  /// Whether the OS permission is granted.
  Future<bool> hasPermission();

  /// Shows the OS prompt. True when granted.
  Future<bool> requestPermission();

  Future<void> openSettings();
}

/// Used where location must never be touched: background isolates and tests.
class NoLocation implements LocationService {
  const NoLocation();

  @override
  LatLng? recentFix({Duration maxAge = const Duration(minutes: 2)}) => null;

  @override
  Future<LatLng?> currentFix() async => null;

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> openSettings() async {}
}

/// How long after a payment "where I am now" still says something about where
/// the payment happened.
const paymentLocationWindow = Duration(minutes: 10);

bool withinLocationWindow(DateTime receivedAt, DateTime now) {
  final age = now.difference(receivedAt);
  return !age.isNegative && age < paymentLocationWindow;
}
