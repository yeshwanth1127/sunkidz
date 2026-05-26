class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://31.97.63.193:8001',
  );
  static const String apiPrefix = '/api/v1';
}
