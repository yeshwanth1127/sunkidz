# Update learning_modules_provider.dart
with open('mobile/lib/features/learning_modules/data/learning_modules_provider.dart', 'r') as f:
    content = f.read()

# Add studentLearningModulesProvider
if 'studentLearningModulesProvider' not in content:
    new_provider = '''
final studentLearningModulesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, studentId) async {
  final service = ref.watch(learningModulesServiceProvider);
  if (service == null) return [];
  return service.getModulesForStudent(studentId);
});
'''
    content = content.rstrip() + '\n' + new_provider

with open('mobile/lib/features/learning_modules/data/learning_modules_provider.dart', 'w') as f:
    f.write(content)

print('✓ Updated learning_modules_provider.dart with student filter')
