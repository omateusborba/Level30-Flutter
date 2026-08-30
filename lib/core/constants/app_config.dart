class AppConfig {
  const AppConfig._();

  // API Spring Boot (Fase 5), na VM Oracle atrás do Cloudflare Tunnel.
  // Override em build/test: flutter run --dart-define=API_BASE_URL=http://localhost:8080
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.level30.online',
  );
}
