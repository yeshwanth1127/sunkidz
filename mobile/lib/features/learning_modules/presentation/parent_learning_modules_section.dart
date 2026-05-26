import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/learning_modules_provider.dart';

class ParentLearningModulesSection extends ConsumerWidget {
  final String studentId;

  const ParentLearningModulesSection({
    Key? key,
    required this.studentId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(studentLearningModulesProvider(studentId));

    return modulesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: SizedBox(
          height: 120,
          child: Center(
            child: CircularProgressIndicator(color: Colors.orange),
          ),
        ),
      ),
      error: (error, st) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Text(
          'Error loading modules',
          style: TextStyle(color: Colors.red, fontSize: 14),
        ),
      ),
      data: (modules) {
        if (modules.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'No learning modules assigned yet',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Learning Modules',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: modules.length,
                  itemBuilder: (context, index) {
                    final module = modules[index];
                    return GestureDetector(
                      onTap: () => context.push(
                        '/learning-modules/videos?moduleId=${module['id']}'
                      ),
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.orange.shade200,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.shade100.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              module['name'] ?? 'Module',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Icon(
                                  Icons.play_circle_outline,
                                  size: 16,
                                  color: Colors.orange.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '\ videos',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
