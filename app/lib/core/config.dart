/// Build-time configuration.
class AppConfig {
  const AppConfig._();

  /// Set with --dart-define=API_BASE_URL=http://192.168.1.20:8000
  /// The default reaches a backend on the development machine from the Android emulator.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');

  /// Root of the versioned API, always with a trailing slash.
  static String get apiRoot {
    final base = apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl;
    return '$base/api/v1/';
  }
}
