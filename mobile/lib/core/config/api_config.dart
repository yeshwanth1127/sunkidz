class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.0.5:8001',
  );
  static const String apiPrefix = '/api/v1';
}
