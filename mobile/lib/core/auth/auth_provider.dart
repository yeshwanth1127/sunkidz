import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum UserRole { admin, coordinator, teacher, parent, busStaff }

class AuthState {
  final String? token;
  final String? userId;
  final UserRole? role;
  final String? branchId;
  final String? classId;
  final DateTime? tokenExpiry;

  const AuthState({
    this.token,
    this.userId,
    this.role,
    this.branchId,
    this.classId,
    this.tokenExpiry,
  });

  bool get isAuthenticated => token != null && token!.isNotEmpty && !isTokenExpired;
  
  bool get isTokenExpired {
    if (tokenExpiry == null) return true;
    return DateTime.now().isAfter(tokenExpiry!);
  }
  
  bool get needsRefresh {
    if (tokenExpiry == null) return false;
    // Refresh if token expires within next 24 hours
    return DateTime.now().isAfter(tokenExpiry!.subtract(const Duration(hours: 24)));
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._storage) : super(const AuthState()) {
    _loadFromStorage();
  }

  final FlutterSecureStorage _storage;
  static const _keyToken = 'auth_token';
  static const _keyUserId = 'user_id';
  static const _keyRole = 'user_role';
  static const _keyBranchId = 'branch_id';
  static const _keyClassId = 'class_id';
  static const _keyTokenExpiry = 'token_expiry';
  static const _keyRememberMe = 'remember_me';

  Future<void> _loadFromStorage() async {
    try {
      final token = await _storage.read(key: _keyToken);
      final rememberMe = await _storage.read(key: _keyRememberMe);
      
      if (token != null && rememberMe == 'true') {
        final expiryString = await _storage.read(key: _keyTokenExpiry);
        DateTime? expiry;
        if (expiryString != null) {
          expiry = DateTime.tryParse(expiryString);
        }
        
        // Only restore session if token hasn't expired
        if (expiry == null || DateTime.now().isBefore(expiry)) {
          final userId = await _storage.read(key: _keyUserId);
          final roleStr = await _storage.read(key: _keyRole);
          final branchId = await _storage.read(key: _keyBranchId);
          final classId = await _storage.read(key: _keyClassId);
          
          state = AuthState(
            token: token,
            userId: userId,
            role: _parseRole(roleStr),
            branchId: branchId,
            classId: classId,
            tokenExpiry: expiry,
          );
        } else {
          // Token expired, clear storage
          await logout();
        }
      }
    } catch (e) {
      // If any error in loading, just start with empty state
      state = const AuthState();
    }
  }

  UserRole? _parseRole(String? r) {
    if (r == null) return null;
    final normalized = r.toLowerCase().replaceAll('_', '');
    switch (normalized) {
      case 'admin':
        return UserRole.admin;
      case 'coordinator':
        return UserRole.coordinator;
      case 'teacher':
        return UserRole.teacher;
      case 'parent':
        return UserRole.parent;
      case 'busstaff':
        return UserRole.busStaff;
      default:
        return UserRole.values.firstWhere(
          (e) => e.name.toLowerCase() == normalized,
          orElse: () => UserRole.admin,
        );
    }
  }

  Future<void> login({
    required String token,
    required String userId,
    required UserRole role,
    String? branchId,
    String? classId,
    bool rememberMe = true, // Default to true for 1-month sessions
    int sessionDurationDays = 30, // Default 30 days
  }) async {
    final expiry = DateTime.now().add(Duration(days: sessionDurationDays));
    
    // Write to secure storage
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyUserId, value: userId);
    await _storage.write(key: _keyRole, value: role.name);
    await _storage.write(key: _keyRememberMe, value: rememberMe.toString());
    await _storage.write(key: _keyTokenExpiry, value: expiry.toIso8601String());
    
    if (branchId != null) {
      await _storage.write(key: _keyBranchId, value: branchId);
    }
    if (classId != null) {
      await _storage.write(key: _keyClassId, value: classId);
    }
    
    // Update state
    state = AuthState(
      token: token,
      userId: userId,
      role: role,
      branchId: branchId,
      classId: classId,
      tokenExpiry: expiry,
    );
  }

  Future<void> logout() async {
    // Clear all secure storage keys
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyRole);
    await _storage.delete(key: _keyBranchId);
    await _storage.delete(key: _keyClassId);
    await _storage.delete(key: _keyTokenExpiry);
    await _storage.delete(key: _keyRememberMe);
    
    state = const AuthState();
  }
  
  /// Extend current session by another period
  Future<void> extendSession({int days = 30}) async {
    if (state.token == null) return;
    
    final newExpiry = DateTime.now().add(Duration(days: days));
    await _storage.write(key: _keyTokenExpiry, value: newExpiry.toIso8601String());
    
    state = AuthState(
      token: state.token,
      userId: state.userId,
      role: state.role,
      branchId: state.branchId,
      classId: state.classId,
      tokenExpiry: newExpiry,
    );
  }
  
  /// Check if session is valid and extend if needed
  Future<bool> validateAndExtendSession() async {
    if (!state.isAuthenticated) return false;
    
    // If token is close to expiry, extend it
    if (state.needsRefresh) {
      await extendSession();
    }
    
    return true;
  }
  
  /// Clear all stored data (useful for debugging or account deletion)
  Future<void> clearAllData() async {
    await _storage.deleteAll();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  throw UnimplementedError('AuthNotifier requires FlutterSecureStorage - use override');
});
