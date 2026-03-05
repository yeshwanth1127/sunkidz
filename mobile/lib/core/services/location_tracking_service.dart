import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  
  factory LocationTrackingService() {
    return _instance;
  }
  
  LocationTrackingService._internal();

  StreamSubscription<Position>? _positionStream;
  final _locationUpdates = <Position>[];
  
  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      return result != LocationPermission.denied && result != LocationPermission.deniedForever;
    }
    return permission != LocationPermission.deniedForever;
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      print('Error getting position: $e');
      return null;
    }
  }

  /// Start continuous location tracking (every 10 seconds)
  Stream<Position> startTracking({
    Duration updateInterval = const Duration(seconds: 10),
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0, // No distance filter, time-based only
      ),
    ).asBroadcastStream();
  }

  /// Listen to location updates and execute callback
  void listenToLocationUpdates(
    Function(Position position) onUpdate,
    Function(dynamic error) onError, {
    Duration updateInterval = const Duration(seconds: 10),
  }) {
    _positionStream?.cancel();
    
    final stream = startTracking(updateInterval: updateInterval);
    
    _positionStream = stream.listen(
      (Position position) {
        _locationUpdates.add(position);
        onUpdate(position);
      },
      onError: (dynamic error) {
        print('Location tracking error: $error');
        onError(error);
      },
    );
  }

  /// Stop location tracking
  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  /// Get all collected location updates
  List<Position> getLocationUpdates() => List.from(_locationUpdates);

  /// Clear location updates
  void clearLocationUpdates() => _locationUpdates.clear();
}
