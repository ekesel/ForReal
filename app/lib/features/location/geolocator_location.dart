import 'package:geolocator/geolocator.dart';

import '../../data/models.dart';
import 'location_service.dart';

/// Coarse, foreground-only location through the geolocator plugin.
///
/// The manifest declares ACCESS_COARSE_LOCATION only, so the platform itself never
/// hands out a precise position, and there is no background permission to use.
class GeolocatorLocation implements LocationService {
  GeolocatorLocation({required this._consentGranted, required this._inForeground, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// Whether the user currently holds the `location` consent.
  final bool Function() _consentGranted;

  /// Whether the app is on screen.
  final bool Function() _inForeground;
  final DateTime Function() _now;

  LatLng? _last;
  DateTime? _lastAt;

  @override
  LatLng? recentFix({Duration maxAge = const Duration(minutes: 2)}) {
    final at = _lastAt;
    if (_last == null || at == null) return null;
    if (!_consentGranted() || !_inForeground()) return null;
    return _now().difference(at) <= maxAge ? _last : null;
  }

  @override
  Future<LatLng?> currentFix() async {
    if (!_consentGranted() || !_inForeground()) return null;
    try {
      if (!await hasPermission()) return null;
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 8)),
      );
      _last = LatLng(position.latitude, position.longitude).coarse;
      _lastAt = _now();
      return _last;
    } catch (_) {
      // No fix in time, or location switched off: carry on without one.
      return null;
    }
  }

  @override
  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }

  @override
  Future<bool> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Forget the cached fix, for example when the consent is withdrawn.
  void forget() {
    _last = null;
    _lastAt = null;
  }
}
