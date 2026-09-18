import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/gallery_api.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/session_guard.dart';

final galleryApiProvider = Provider<GalleryApi?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.token == null || auth.token!.isEmpty) return null;
  return GalleryApi(auth.token!, onUnauthorized: ref.read(onUnauthorizedProvider));
});

/// Roles allowed to upload / manage gallery content. Mirrors the backend
/// check in `app/api/gallery.py` (`UPLOAD_ROLES`).
bool canManageGallery(UserRole? role) =>
    role == UserRole.admin ||
    role == UserRole.coordinator ||
    role == UserRole.teacher;
