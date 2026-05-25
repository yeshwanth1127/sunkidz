import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import 'learning_modules_service.dart';

final learningModulesServiceProvider = Provider<LearningModulesService?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null || auth.token!.isEmpty) return null;
  return LearningModulesService(auth.token!);
});

final learningModulesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(learningModulesServiceProvider);
  if (service == null) return [];
  return service.getModules();
});

final moduleVideosProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, moduleId) async {
  final service = ref.watch(learningModulesServiceProvider);
  if (service == null) return [];
  return service.getModuleVideos(moduleId);
});
