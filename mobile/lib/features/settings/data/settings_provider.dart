import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import 'settings_service.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null) {
    throw Exception('No authentication token found');
  }
  return SettingsService(auth.token!);
});
