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

  static const cdnUrl = String.fromEnvironment(
    'CDN_URL',
    defaultValue: 'https://cdn.apsbrat.in',
  );
}
