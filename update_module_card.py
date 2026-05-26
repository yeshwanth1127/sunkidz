# Update _ModuleAdminCard class
with open('mobile/lib/features/learning_modules/presentation/admin_learning_modules_screen.dart', 'r') as f:
    content = f.read()

# Add onAssignStudents parameter to _ModuleAdminCard
if 'onAssignStudents' not in content:
    content = content.replace(
        'class _ModuleAdminCard extends StatelessWidget {' + '\n' + '  final Map<String, dynamic> module;' + '\n' + '  final VoidCallback onUploadVideo;' + '\n' + '  final VoidCallback onDelete;',
        'class _ModuleAdminCard extends StatelessWidget {' + '\n' + '  final Map<String, dynamic> module;' + '\n' + '  final VoidCallback onUploadVideo;' + '\n' + '  final VoidCallback onAssignStudents;' + '\n' + '  final VoidCallback onDelete;'
    )
    
    content = content.replace(
        'const _ModuleAdminCard({' + '\n' + '    required this.module,' + '\n' + '    required this.onUploadVideo,' + '\n' + '    required this.onDelete,' + '\n' + '  });',
        'const _ModuleAdminCard({' + '\n' + '    required this.module,' + '\n' + '    required this.onUploadVideo,' + '\n' + '    required this.onAssignStudents,' + '\n' + '    required this.onDelete,' + '\n' + '  });'
    )
    
    # Add the assign button to the button row
    content = content.replace(
        'Expanded(' + '\n' + '                child: FilledButton.icon(' + '\n' + '                  onPressed: onUploadVideo,',
        'Expanded(' + '\n' + '                child: FilledButton.icon(' + '\n' + '                  onPressed: onAssignStudents,' + '\n' + '                  icon: const Icon(Icons.person_add, size: 16),' + '\n' + '                  label: const Text(\"Assign\"),' + '\n' + '                  style: FilledButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 8)),' + '\n' + '                ),' + '\n' + '              ),' + '\n' + '              const SizedBox(width: 8),' + '\n' + '              Expanded(' + '\n' + '                child: FilledButton.icon(' + '\n' + '                  onPressed: onUploadVideo,'
    )

with open('mobile/lib/features/learning_modules/presentation/admin_learning_modules_screen.dart', 'w') as f:
    f.write(content)

print('✓ Updated _ModuleAdminCard class')
