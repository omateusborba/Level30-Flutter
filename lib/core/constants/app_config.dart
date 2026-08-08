class AppConfig {
  const AppConfig._();

  // Permite trocar em build/test: flutter run --dart-define=API_BASE_URL=http://localhost:8787
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://level30-api.mateus-borba.workers.dev',
  );
}
