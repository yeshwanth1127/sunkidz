import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/api/auth_api.dart';
import '../../../shared/widgets/sunkidz_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isParentLogin = false;
  String? _errorMessage;

  String _extractLoginError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final responseData = error.response?.data;

      if (responseData is Map && responseData['detail'] is String) {
        return responseData['detail'] as String;
      }

      if (status == 401) {
        return _isParentLogin
            ? 'Invalid admission number/email or date of birth.'
            : 'Invalid email or password.';
      }
      if (status == 403) {
        return 'Account is inactive. Contact admin.';
      }
      if (status != null) {
        return 'Server error ($status). Please try again.';
      }

      return 'Cannot reach server. Check internet and API URL.';
    }

    return _isParentLogin
        ? 'Login failed. Check admission number/email and date of birth (YYYY-MM-DD).'
        : 'Login failed. Check credentials and server.';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = AuthApi();
      Map<String, dynamic> data;

      if (_isParentLogin) {
        // Parent or Toddlers/Daycare: first field = admission_number or email, second = date_of_birth
        final field1 = _emailController.text.trim();
        final dateOfBirth = _passwordController.text.trim();
        if (field1.contains('@')) {
          // Toddlers/Daycare: email + DOB
          data = await api.login(email: field1, dateOfBirth: dateOfBirth);
        } else {
          // Parent: admission_number + DOB
          data = await api.login(admissionNumber: field1, dateOfBirth: dateOfBirth);
        }
      } else {
        // Staff login: email + password
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        data = await api.login(email: email, password: password);
      }

      final token = data['access_token'] as String;
      final userId = data['user_id'] as String;
      final roleStr = data['role'] as String;
      final role = _roleFromString(roleStr);
      final branchId = data['branch_id'] as String?;
      final classId = data['class_id'] as String?;

      await ref
          .read(authProvider.notifier)
          .login(
            token: token,
            userId: userId,
            role: role,
            branchId: branchId,
            classId: classId,
          );
      if (mounted) {
        setState(() => _isLoading = false);
        context.go(_homeForRole(role));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _extractLoginError(e);
        });
      }
    }
  }

  UserRole _roleFromString(String s) {
    switch (s.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'coordinator':
        return UserRole.coordinator;
      case 'teacher':
        return UserRole.teacher;
      case 'parent':
        return UserRole.parent;
      case 'bus_staff':
        return UserRole.busStaff;
      case 'toddlers':
        return UserRole.toddlers;
      case 'daycare':
        return UserRole.daycare;
      default:
        return UserRole.admin;
    }
  }

  String _homeForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return '/admin';
      case UserRole.coordinator:
        return '/coordinator';
      case UserRole.teacher:
        return '/teacher';
      case UserRole.parent:
        return '/parent';
      case UserRole.busStaff:
        return '/bus-staff';
      case UserRole.toddlers:
        return '/admin/toddlers';
      case UserRole.daycare:
        return '/admin/daycare';
      default:
        return '/admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              const Center(child: SunkidzLogo(size: 120, showText: false)),
              const SizedBox(height: 24),
              Text(
                'Sign in to continue',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              // Login type selector
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isParentLogin = false;
                            _emailController.clear();
                            _passwordController.clear();
                            _errorMessage = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isParentLogin
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !_isParentLogin
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Text(
                            'Staff',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: !_isParentLogin
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: !_isParentLogin
                                  ? AppColors.primary
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isParentLogin = true;
                            _emailController.clear();
                            _passwordController.clear();
                            _errorMessage = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isParentLogin
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _isParentLogin
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Text(
                            'Parent / Toddlers',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: _isParentLogin
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: _isParentLogin
                                  ? AppColors.primary
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                  ),
                ),
              ],
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: _isParentLogin ? 'Admission Number or Email' : 'Email',
                  prefixIcon: Icon(
                    _isParentLogin
                        ? Icons.badge_outlined
                        : Icons.person_outline,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: _isParentLogin ? 'Date of Birth' : 'Password',
                  prefixIcon: Icon(
                    _isParentLogin ? Icons.cake_outlined : Icons.lock_outline,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign In'),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
