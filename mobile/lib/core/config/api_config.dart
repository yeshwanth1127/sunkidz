import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Explicit override, applied in every build mode when provided:
  ///   flutter run  --dart-define=API_BASE_URL=http://10.0.2.2:9889   (Android emulator)
  ///   flutter build --dart-define=API_BASE_URL=https://api.sunkidz.org
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// When no override is given:
  ///  - release builds talk to the deployed production API
  ///  - debug / profile builds (local `flutter run`) talk to the local
  ///    backend from backend_sunkidz/README.md
  ///    (`uvicorn app.main:app --reload --host 0.0.0.0 --port 9889`)
  ///
  /// This is what lets locally-added endpoints (e.g. the Gallery module,
  /// which isn't deployed yet) resolve during local development instead of
  /// 404ing against production.
  static final String baseUrl = _override.isNotEmpty
      ? _override
      : (kReleaseMode ? 'https://api.sunkidz.org' : 'http://localhost:9889');

  static const String apiPrefix = '/api/v1';
}
