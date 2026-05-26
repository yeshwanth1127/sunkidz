# Update parent_dashboard_screen.dart
with open('mobile/lib/features/dashboard/presentation/parent_dashboard_screen.dart', 'r') as f:
    content = f.read()

# Add import for learning modules
if 'parent_learning_modules_section' not in content:
    # Find the last import line
    lines = content.split('\n')
    last_import = -1
    for i, line in enumerate(lines):
        if line.startswith('import '):
            last_import = i
    
    if last_import > 0:
        lines.insert(last_import + 1, "import '../../../features/learning_modules/presentation/parent_learning_modules_section.dart';")
        content = '\n'.join(lines)

# Add the learning modules section to the build method
if '_buildLearningModulesSection' not in content:
    # Find where to insert - after Quick Actions
    marker = '// Recent Homework'
    pos = content.find(marker)
    if pos != -1:
        new_section = '''// Learning Modules
                    if (_selectedChild != null)
                      ParentLearningModulesSection(studentId: _selectedChild!['id']),

                    '''
        content = content[:pos] + new_section + content[pos:]

with open('mobile/lib/features/dashboard/presentation/parent_dashboard_screen.dart', 'w') as f:
    f.write(content)

print('✓ Updated parent_dashboard_screen.dart')
