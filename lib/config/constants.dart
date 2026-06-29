class AppConstants {
  AppConstants._();

  /// Application display name
  static const String appName = 'Joyal';

  /// Subsonic API protocol version
  static const String subsonicVersion = '1.16.1';

  /// Client identifier sent to the Subsonic server
  static const String clientName = 'MinimalPlayer';

  /// Default size for cover art requests (width in pixels)
  static const int coverArtSize = 300;

  /// Secure storage keys
  static const String keyBaseUrl = 'subsonic_base_url';
  static const String keyUsername = 'subsonic_username';
  static const String keyPassword = 'subsonic_password';
}
