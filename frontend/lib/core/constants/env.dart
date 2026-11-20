enum AppFlavor { dev, staging, prod }

class Env {
  const Env._();

  static const baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  static const wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://localhost:8080/ws',
  );

  /// Shows "Skip login (dev)" in a release build. Only for a build pointed at a
  /// dev/qa API with throwaway data: it signs in with the universal OTP, which
  /// the prod API always refuses.
  static const devLogin = bool.fromEnvironment('DEV_LOGIN');

  static const cdnUrl = String.fromEnvironment(
    'CDN_URL',
    defaultValue: 'https://cdn.apsbrat.in',
  );
}
