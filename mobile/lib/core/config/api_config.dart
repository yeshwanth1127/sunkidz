class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.sunkidz.org',
  );
  static const String apiPrefix = '/api/v1';
}
