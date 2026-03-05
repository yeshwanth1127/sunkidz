import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { admin, coordinator, teacher, parent, busStaff }

class AuthState {
  final String? token;
  final String? userId;
  final UserRole? role;
  final String? branchId;
  final String? classId;

  const AuthState({
    this.token,
    this.userId,
    this.role,
    this.branchId,
    this.classId,
  });

  bool get isAuthenticated => token != null && token!.isNotEmpty;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._prefs) : super(const AuthState()) {
    _loadFromStorage();
  }

  final SharedPreferences _prefs;
  static const _keyToken = 'auth_token';
  static const _keyUserId = 'user_id';
  static const _keyRole = 'user_role';
  static const _keyBranchId = 'branch_id';
  static const _keyClassId = 'class_id';

  void _loadFromStorage() {
    final token = _prefs.getString(_keyToken);
    if (token != null) {
      state = AuthState(
        token: token,
        userId: _prefs.getString(_keyUserId),
        role: _parseRole(_prefs.getString(_keyRole)),
        branchId: _prefs.getString(_keyBranchId),
        classId: _prefs.getString(_keyClassId),
      );
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
        return UserRole.values.firstWhere((e) => e.name.toLowerCase() == normalized, orElse: () => UserRole.admin);
    }
  }

  Future<void> login({
    required String token,
    required String userId,
    required UserRole role,
    String? branchId,
    String? classId,
  }) async {
    await _prefs.setString(_keyToken, token);
    await _prefs.setString(_keyUserId, userId);
    await _prefs.setString(_keyRole, role.name);
    if (branchId != null) await _prefs.setString(_keyBranchId, branchId);
    if (classId != null) await _prefs.setString(_keyClassId, classId);
    state = AuthState(token: token, userId: userId, role: role, branchId: branchId, classId: classId);
  }

  Future<void> logout() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyUserId);
    await _prefs.remove(_keyRole);
    await _prefs.remove(_keyBranchId);
    await _prefs.remove(_keyClassId);
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  throw UnimplementedError('AuthNotifier requires SharedPreferences - use override');
});
