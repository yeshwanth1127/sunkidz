# Update learning_modules_service.dart
with open('mobile/lib/features/learning_modules/data/learning_modules_service.dart', 'r') as f:
    content = f.read()

# Add getModulesForStudent method after getModules
if 'getModulesForStudent' not in content:
    new_method = '''
  Future<List<Map<String, dynamic>>> getModulesForStudent(String studentId) async {
    try {
      final response = await _dio.get('/learning-modules/for-student/\');
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load modules for student: \');
    }
  }

'''
    # Insert after getModules method
    pos = content.find('  Future<List<Map<String, dynamic>>> getModuleVideos')
    if pos != -1:
        content = content[:pos] + new_method + content[pos:]

# Add assignment methods at the end before closing brace
if 'assignModuleToStudent' not in content:
    assign_methods = '''
  Future<Map<String, dynamic>> assignModuleToStudent(String moduleId, String studentId) async {
    try {
      final response = await _dio.post('/learning-modules/\/assign-to-student/\');
      return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
    } catch (e) {
      throw Exception('Failed to assign module: \');
    }
  }

  Future<void> unassignModuleFromStudent(String moduleId, String studentId) async {
    try {
      await _dio.delete('/learning-modules/\/unassign-from-student/\');
    } catch (e) {
      throw Exception('Failed to unassign module: \');
    }
  }
'''
    # Insert before the final closing brace
    pos = content.rfind('}')
    if pos != -1:
        content = content[:pos] + assign_methods + '\n' + content[pos:]

with open('mobile/lib/features/learning_modules/data/learning_modules_service.dart', 'w') as f:
    f.write(content)

print('✓ Updated learning_modules_service.dart with student filtering')
