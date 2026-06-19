class AppConstants {
  AppConstants._();

  static const String appName = 'PauloFlix';
  static const Duration cacheDefaultExpiry = Duration(minutes: 30);
  static const Duration searchDebounceDuration = Duration(milliseconds: 300);
  static const int maxConcurrentDownloads = 3;
}
