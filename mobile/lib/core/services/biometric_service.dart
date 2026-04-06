import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _savedTokenKey = 'saved_auth_token';
  static const String _savedUserEmail = 'saved_user_email';

  /// Check if the device hardware supports biometrics
  Future<bool> isBiometricAvailable() async {
    // Biometrics are usually not available on web or might throw errors
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  /// Get list of available biometrics (Fingerprint, Face, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Trigger the biometric prompt
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to log in to Sunkidz',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  /// Check if the user has already enabled biometric login in settings
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// Enable biometric login and store current session data
  Future<void> setEnabled({
    required bool enabled,
    String? token,
    String? userId,
    String? role,
    String? branchId,
    String? classId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
    
    if (enabled && token != null) {
      await _secureStorage.write(key: _savedTokenKey, value: token);
      await _secureStorage.write(key: 'saved_user_id', value: userId);
      await _secureStorage.write(key: 'saved_role', value: role);
      await _secureStorage.write(key: 'saved_branch_id', value: branchId);
      await _secureStorage.write(key: 'saved_class_id', value: classId);
    } else {
      await _secureStorage.deleteAll();
    }
  }

  /// Retrieve all saved auth data
  Future<Map<String, String?>> getSavedAuthData() async {
    return {
      'token': await _secureStorage.read(key: _savedTokenKey),
      'userId': await _secureStorage.read(key: 'saved_user_id'),
      'role': await _secureStorage.read(key: 'saved_role'),
      'branchId': await _secureStorage.read(key: 'saved_branch_id'),
      'classId': await _secureStorage.read(key: 'saved_class_id'),
    };
  }
  
  /// Clear everything (Logout)
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, false);
    await _secureStorage.deleteAll();
  }
}
