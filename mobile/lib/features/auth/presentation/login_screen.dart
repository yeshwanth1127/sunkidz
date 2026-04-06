import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/api/auth_api.dart';
import '../../../shared/widgets/sunkidz_logo.dart';
import '../../../shared/widgets/animated_starry_background.dart';
import '../../../core/services/biometric_service.dart';
import 'package:local_auth/local_auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isParentLogin = false;
  String? _errorMessage;

  // New animation properties for premium feel
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
    _checkBiometricSupport();
  }

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
    _fadeController.dispose();
    super.dispose();
  }

  final _biometricService = BiometricService();
  bool _canCheckBiometrics = false;

  Future<void> _checkBiometricSupport() async {
    final available = await _biometricService.isBiometricAvailable();
    final enabled = await _biometricService.isEnabled();
    if (mounted) {
      setState(() {
        _canCheckBiometrics = available;
      });
    }

    // Auto-trigger biometric if enabled and we have a token
    if (available && enabled) {
      _tryBiometricLogin();
    }
  }

  Future<void> _tryBiometricLogin() async {
    final authenticated = await _biometricService.authenticate();
    if (authenticated) {
      final data = await _biometricService.getSavedAuthData();
      final token = data['token'];
      if (token != null) {
        final roleStr = data['role'] ?? 'admin';
        final role = _roleFromString(roleStr);
        
        await ref.read(authProvider.notifier).login(
          token: token,
          userId: data['userId'] ?? '',
          role: role,
          branchId: data['branchId'],
          classId: data['classId'],
        );
        if (mounted) {
          context.go(_homeForRole(role));
        }
      }
    }
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
        final admissionNumber = _emailController.text.trim();
        final dateOfBirth = _passwordController.text.trim();
        data = await api.login(
          admissionNumber: admissionNumber,
          dateOfBirth: dateOfBirth,
        );
      } else {
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
        
        final targetRoute = _homeForRole(role);
        
        // --- Prompt for Biometric before navigating ---
        if (_canCheckBiometrics) {
          final isCurrentlyEnabled = await _biometricService.isEnabled();
          if (!isCurrentlyEnabled && mounted) {
            await _showBiometricDialog(token, userId, roleStr, branchId, classId);
          }
        }
        
        if (mounted) {
          context.go(targetRoute);
        }
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

  Future<void> _showBiometricDialog(String token, String userId, String role, String? branchId, String? classId) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enable Fingerprint Login?'),
        content: const Text(
          'Would you like to use your fingerprint for faster logins in the future?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _biometricService.authenticate();
              if (success) {
                await _biometricService.setEnabled(
                  enabled: true, 
                  token: token,
                  userId: userId,
                  role: role,
                  branchId: branchId,
                  classId: classId,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fingerprint login enabled!')),
                  );
                }
              }
            },
            child: const Text('Yes, Enable'),
          ),
        ],
      ),
    );
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
        return '/toddler';
      case UserRole.daycare:
        return '/daycare';
      default:
        return '/admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedStarryBackground(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60),
                  const Center(child: SunkidzLogo(size: 140, showText: true)),
                  const SizedBox(height: 48),
                  
                  // Premium Toggle
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [AppShadows.soft],
                    ),
                    child: Stack(
                      children: [
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          alignment: _isParentLogin ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            width: (MediaQuery.of(context).size.width - 48) / 2,
                            height: 42,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [AppShadows.soft],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _isParentLogin = false;
                                  _errorMessage = null;
                                }),
                                behavior: HitTestBehavior.opaque,
                                child: Center(
                                  child: Text(
                                    'STAFF',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      letterSpacing: 1,
                                      color: !_isParentLogin ? AppColors.primary : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _isParentLogin = true;
                                  _errorMessage = null;
                                }),
                                behavior: HitTestBehavior.opaque,
                                child: Center(
                                  child: Text(
                                    'PARENT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      letterSpacing: 1,
                                      color: _isParentLogin ? AppColors.primary : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  if (_errorMessage != null) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: _isParentLogin ? 'Admission Number' : 'Email Address',
                      hintText: _isParentLogin ? 'e.g. SK2024-001' : 'e.g. admin@sunkidz.com',
                      prefixIcon: Icon(_isParentLogin ? Icons.badge_outlined : Icons.alternate_email_rounded, size: 20),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: _isParentLogin ? 'Date of Birth' : 'Security Password',
                      hintText: _isParentLogin ? 'YYYY-MM-DD' : '••••••••',
                      prefixIcon: Icon(_isParentLogin ? Icons.calendar_today_outlined : Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                          color: const Color(0xFF94A3B8),
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Premium Gradient Login Button
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppGradients.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [AppShadows.glow(AppColors.primary)],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                Shimmer.fromColors(
                                  baseColor: Colors.white.withValues(alpha: 0.1),
                                  highlightColor: Colors.white.withValues(alpha: 0.4),
                                  child: Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                                const Text(
                                  'SIGN IN',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.white),
                                ),
                              ],
                            ),
                    ),
                  ),
                  
                  if (_canCheckBiometrics) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: _tryBiometricLogin,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [AppShadows.soft],
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 32),
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
