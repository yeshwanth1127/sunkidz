import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/config/api_config.dart';

class SettingsService {
  final String _token;
  late final Dio _dio;

  SettingsService(this._token) {
    _dio = Dio(BaseOptions(
      baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
      connectTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      },
    ));
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to change password');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Current password is incorrect');
      } else if (e.response?.data is Map && e.response?.data['detail'] != null) {
        throw Exception(e.response?.data['detail']);
      } else {
        throw Exception('Failed to change password. Please try again.');
      }
    } catch (e) {
      throw Exception('An error occurred: $e');
    }
  }

  Future<void> uploadProfilePhoto({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '/auth/upload-profile-photo',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to upload profile photo');
      }
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        throw Exception(e.response?.data['detail']);
      } else {
        throw Exception('Failed to upload profile photo. Please try again.');
      }
    } catch (e) {
      throw Exception('An error occurred: $e');
    }
  }

  Future<void> deleteProfilePhoto() async {
    try {
      final response = await _dio.delete('/auth/delete-profile-photo');

      if (response.statusCode != 200) {
        throw Exception('Failed to delete profile photo');
      }
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        throw Exception(e.response?.data['detail']);
      } else {
        throw Exception('Failed to delete profile photo. Please try again.');
      }
    } catch (e) {
      throw Exception('An error occurred: $e');
    }
  }

  String getProfilePhotoUrl(String userId) {
    return '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/auth/profile-photo/$userId';
  }
}
