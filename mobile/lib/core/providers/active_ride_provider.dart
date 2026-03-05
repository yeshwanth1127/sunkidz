import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_tracking_service.dart';
import '../api/bus_tracking_api.dart';
import '../api/bus_tracking_provider.dart';

// Active ride state
class ActiveRideState {
  final String? rideId;
  final String? routeId;
  final String? routeName;
  final DateTime? startTime;
  final Position? currentLocation;
  final bool isTracking;
  final String? error;

  const ActiveRideState({
    this.rideId,
    this.routeId,
    this.routeName,
    this.startTime,
    this.currentLocation,
    this.isTracking = false,
    this.error,
  });

  ActiveRideState copyWith({
    String? rideId,
    String? routeId,
    String? routeName,
    DateTime? startTime,
    Position? currentLocation,
    bool? isTracking,
    String? error,
  }) {
    return ActiveRideState(
      rideId: rideId ?? this.rideId,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      startTime: startTime ?? this.startTime,
      currentLocation: currentLocation ?? this.currentLocation,
      isTracking: isTracking ?? this.isTracking,
      error: error ?? this.error,
    );
  }
}

// Active ride notifier
class ActiveRideNotifier extends StateNotifier<ActiveRideState> {
  final BusTrackingApi? _api;
  final LocationTrackingService _locationService = LocationTrackingService();

  ActiveRideNotifier(this._api) : super(const ActiveRideState()) {
    _checkActiveRide();
  }

  Future<void> _checkActiveRide() async {
    try {
      if (_api == null) return;
      final ride = await _api!.getActiveRide();
      if (ride != null) {
        state = state.copyWith(
          rideId: ride['id'],
          routeId: ride['route_id'],
          routeName: ride['route_name'],
          startTime: DateTime.parse(ride['start_time']),
        );
      }
    } catch (e) {
      print('Error checking active ride: $e');
    }
  }

  Future<void> startRide() async {
    try {
      print('ActiveRideNotifier.startRide called');
      print('API available: $_api != null');
      if (_api == null) throw 'API not available';

      state = state.copyWith(error: null);

      // Request permission first
      print('Requesting location permission...');
      final hasPermission = await _locationService.requestLocationPermission();
      print('Location permission: $hasPermission');
      if (!hasPermission) {
        state = state.copyWith(error: 'Location permission denied');
        return;
      }

      // Get current position to verify GPS is working
      print('Getting current position...');
      final position = await _locationService.getCurrentPosition();
      print('Current position: ${position?.latitude}, ${position?.longitude}');
      if (position == null) {
        state = state.copyWith(error: 'Unable to get current location');
        return;
      }

      // Start ride on backend
      print('Calling backend startRide API...');
      final response = await _api!.startRide();
      print('Backend response: $response');

      state = state.copyWith(
        rideId: response['id'],
        routeId: response['route_id'],
        routeName: response['route_name'] ?? 'Route',
        startTime: DateTime.now(),
        currentLocation: position,
        isTracking: true,
      );
      print('State updated: isTracking = ${state.isTracking}');

      // Start tracking locations
      _startLocationTracking();
      print('Location tracking started');
    } catch (e) {
      print('Error in startRide: $e');
      String errorMessage = e.toString();
      
      // Make error messages more user-friendly
      if (errorMessage.contains('400') || errorMessage.contains('already have an active ride')) {
        errorMessage = 'You already have an active ride. End it first or contact admin.';
      } else if (errorMessage.contains('404') || errorMessage.contains('No route assigned')) {
        errorMessage = 'No route assigned to you. Contact admin.';
      } else if (errorMessage.contains('403')) {
        errorMessage = 'Permission denied. You must be logged in as bus staff.';
      }
      
      state = state.copyWith(error: errorMessage);
    }
  }

  void _startLocationTracking() {
    _locationService.listenToLocationUpdates(
      (position) async {
        state = state.copyWith(currentLocation: position);

        // Send to backend every 10-15 seconds
        if (_api != null && state.rideId != null) {
          try {
            await _api!.updateLocation(
              state.rideId!,
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
              speed: position.speed,
              heading: position.heading,
              altitude: position.altitude,
            );
          } catch (e) {
            print('Error updating location: $e');
          }
        }
      },
      (error) {
        state = state.copyWith(error: 'Tracking error: $error');
      },
      updateInterval: const Duration(seconds: 10),
    );
  }

  Future<void> endRide() async {
    try {
      if (_api == null || state.rideId == null) return;

      _locationService.stopTracking();

      await _api!.endRide(state.rideId!);

      state = const ActiveRideState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> checkForExistingRide() async {
    try {
      if (_api == null) return null;
      
      print('🔍 Checking for existing active ride...');
      final rideData = await _api!.getActiveRide();
      
      if (rideData != null) {
        print('⚠️ Found existing active ride: ${rideData['ride_id']}');
        return rideData;
      } else {
        print('✅ No existing active ride found');
        return null;
      }
    } catch (e) {
      print('❌ Error checking for existing ride: $e');
      return null;
    }
  }

  Future<bool> endRideById(String rideId) async {
    try {
      if (_api == null) {
        print('❌ API is null');
        return false;
      }

      print('🛑 Ending ride: $rideId');
      _locationService.stopTracking();
      
      await _api!.endRide(rideId);
      
      state = const ActiveRideState();
      print('✅ Successfully ended ride');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error ending ride: $e');
      print('Stack trace: $stackTrace');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void stopTracking() {
    _locationService.stopTracking();
  }
}

// Provider
final activeRideProvider = StateNotifierProvider<ActiveRideNotifier, ActiveRideState>((ref) {
  final api = ref.watch(busTrackingApiProvider);
  return ActiveRideNotifier(api);
});
