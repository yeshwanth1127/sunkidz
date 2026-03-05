import 'package:dio/dio.dart';
import '../config/api_config.dart';

class BusTrackingApi {
  late final Dio _dio;

  BusTrackingApi({required String token}) {
    _dio = Dio(BaseOptions(
      baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ));
  }

  // Bus Staff APIs
  Future<Map<String, dynamic>> getMyRoute() async {
    final response = await _dio.get('/bus-tracking/bus-staff/my-route');
    return response.data;
  }

  Future<Map<String, dynamic>> startRide() async {
    final response = await _dio.post(
      '/bus-tracking/bus-staff/rides/start',
    );
    return response.data;
  }

  Future<Map<String, dynamic>> updateLocation(
    String rideId, {
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
    double? altitude,
  }) async {
    final response = await _dio.post(
      '/bus-tracking/bus-staff/rides/$rideId/update-location',
      data: {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
        if (altitude != null) 'altitude': altitude,
      },
    );
    return response.data;
  }

  Future<Map<String, dynamic>> endRide(String rideId) async {
    final response = await _dio.post('/bus-tracking/bus-staff/rides/$rideId/end');
    return response.data;
  }

  Future<Map<String, dynamic>?> getActiveRide() async {
    final response = await _dio.get('/bus-tracking/bus-staff/rides/active');
    return response.data;
  }

  // Admin APIs
  Future<List<Map<String, dynamic>>> getAllActiveRides({String? branchId}) async {
    final response = await _dio.get(
      '/bus-tracking/admin/rides/active',
      queryParameters: {
        if (branchId != null) 'branch_id': branchId,
      },
    );
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<List<Map<String, dynamic>>> getRideLocations(String rideId, {int limit = 100}) async {
    final response = await _dio.get(
      '/bus-tracking/admin/rides/$rideId/locations',
      queryParameters: {'limit': limit},
    );
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<List<Map<String, dynamic>>> getRideHistory({
    String? branchId,
    String? busStaffId,
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '/bus-tracking/admin/rides/history',
      queryParameters: {
        if (branchId != null) 'branch_id': branchId,
        if (busStaffId != null) 'bus_staff_id': busStaffId,
        'limit': limit,
      },
    );
    return List<Map<String, dynamic>>.from(response.data);
  }

  // Parent APIs
  Future<List<Map<String, dynamic>>> getMyChildrenRides() async {
    final response = await _dio.get('/bus-tracking/parent/my-children-rides');
    return List<Map<String, dynamic>>.from(response.data);
  }

  Dio get dio => _dio;
}
