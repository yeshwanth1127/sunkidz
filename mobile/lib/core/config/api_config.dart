class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:9995',
  );
  static const String apiPrefix = '/api/v1';
}
