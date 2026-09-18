import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/documents_api.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/session_guard.dart';

final documentsApiProvider = Provider<DocumentsApi?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null || auth.token!.isEmpty) return null;
  if (!canManageDocuments(auth.role)) return null;
  return DocumentsApi(auth.token!, onUnauthorized: ref.read(onUnauthorizedProvider));
});

/// Roles allowed to upload/review admission documents. Mirrors the backend
/// check in `app/api/documents.py` (`STAFF_ROLES`). Parents are deliberately
/// excluded — they cannot upload or edit admission forms.
bool canManageDocuments(UserRole? role) =>
    role == UserRole.admin ||
    role == UserRole.coordinator ||
    role == UserRole.teacher;
