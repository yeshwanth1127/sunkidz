class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:9889',
  );
  static const String apiPrefix = '/api/v1';
}
