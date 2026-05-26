# Update admin_learning_modules_screen.dart
with open('mobile/lib/features/learning_modules/presentation/admin_learning_modules_screen.dart', 'r') as f:
    content = f.read()

# Add import for assign dialog
if 'assign_module_dialog' not in content:
    lines = content.split('\n')
    last_import = -1
    for i, line in enumerate(lines):
        if line.startswith('import '):
            last_import = i
    
    if last_import > 0:
        lines.insert(last_import + 1, "import './assign_module_dialog.dart';")
        content = '\n'.join(lines)

# Add onAssignStudents parameter to _ModuleAdminCard if it doesn't exist
if 'onAssignStudents' not in content:
    content = content.replace(
        'onDelete: () async {',
        'onAssignStudents: () {\n                          setState(() {\n                            _selectedModuleId = m[\"id\"];\n                          });\n                          showDialog(\n                            context: context,\n                            builder: (ctx) => AssignModuleDialog(\n                              moduleId: m[\"id\"],\n                              onAssignmentComplete: () {\n                                ref.refresh(learningModulesProvider);\n                              },\n                            ),\n                          );\n                        },\n                        onDelete: () async {'
    )

with open('mobile/lib/features/learning_modules/presentation/admin_learning_modules_screen.dart', 'w') as f:
    f.write(content)

print('✓ Updated admin_learning_modules_screen.dart')
