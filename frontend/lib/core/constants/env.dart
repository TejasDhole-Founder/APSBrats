enum AppFlavor { dev, staging, prod }

class Env {
  const Env._();

  static const baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  static const cdnUrl = String.fromEnvironment(
    'CDN_URL',
    defaultValue: 'https://cdn.apsbrat.in',
  );
}
