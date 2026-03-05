import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../../core/api/bus_tracking_provider.dart' show busTrackingApiProvider;
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/live_map_widget.dart';

final parentChildrenRidesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final api = ref.watch(busTrackingApiProvider);
  if (api == null) {
    return Stream.value([]);
  }
  
  return _createRidesStream(api);
});

Stream<List<Map<String, dynamic>>> _createRidesStream(dynamic api) async* {
  print('🔵 Stream created, starting to fetch rides...');
  int iteration = 0;
  while (true) {
    iteration++;
    try {
      print('🔵 Iteration $iteration: Fetching rides...');
      final rides = await api.getMyChildrenRides();
      print('🚌 Parent rides API response: ${rides.length} rides');
      print('🚌 Response type: ${rides.runtimeType}');
      if (rides.isNotEmpty) {
        print('🚌 First ride: ${rides[0]}');
        print('🚌 All rides: $rides');
      } else {
        print('🚌 No rides returned');
      }
      yield rides;
    } catch (e, st) {
      print('❌ Error fetching rides: $e');
      print('❌ Stack trace: $st');
      yield [];
    }
    await Future.delayed(const Duration(seconds: 5));
  }
}

class ParentBusTrackingWidget extends ConsumerWidget {
  const ParentBusTrackingWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(parentChildrenRidesProvider);

    return rides.when(
      loading: () {
        print('🔄 Loading rides...');
        return _buildLoadingCard(context);
      },
      error: (err, stack) {
        print('❌ Error loading rides: $err');
        return _buildErrorCard(context, err.toString());
      },
      data: (ridesList) {
        print('✅ Rides data received: ${ridesList.length} rides');
        print('✅ Rides list: $ridesList');
        if (ridesList.isEmpty) {
          print('  No active rides found');
          return _buildNoActiveRideCard(context);
        }

        // Find the first active ride
        final activeRide = ridesList.isNotEmpty ? ridesList.first : null;

        if (activeRide == null) {
          print('  Active ride is null');
          return _buildNoActiveRideCard(context);
        }

        print('  Active ride data: $activeRide');

        // Use correct field names from backend response
        final latestLocation = activeRide['latest_location'] as Map<String, dynamic>?;
        final lat = latestLocation?['latitude'] as double?;
        final lng = latestLocation?['longitude'] as double?;
        final busStaffName = activeRide['bus_staff_name'] as String? ?? 'Bus Staff';
        final routeName = activeRide['route_name'] as String? ?? 'Route';
        
        print('  Parsed: $busStaffName, $routeName, location: ${lat != null ? "($lat, $lng)" : "null"}');
        
        // Calculate duration from start_time
        int duration = 0;
        try {
          final startTimeStr = activeRide['start_time'] as String?;
          if (startTimeStr != null) {
            final startTime = DateTime.parse(startTimeStr);
            duration = DateTime.now().difference(startTime).inMinutes;
          }
        } catch (e) {
          // If parsing fails, duration stays 0
        }

        return Column(
          children: [
            // Status header
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                border: Border.all(color: Colors.green, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bus In Transit',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$busStaffName • $routeName',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Duration',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      Text(
                        '${duration}m',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Mini map
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (lat != null && lng != null)
                    LiveMapWidget(
                      currentPosition: Position(
                        latitude: lat!,
                        longitude: lng!,
                        timestamp: DateTime.now(),
                        accuracy: 0,
                        altitude: 0,
                        altitudeAccuracy: 0,
                        heading: 0,
                        headingAccuracy: 0,
                        speed: 0,
                        speedAccuracy: 0,
                      ),
                      locationHistory: [],
                      showPolyline: false,
                    )
                  else
                    Container(
                      color: Colors.grey.withValues(alpha: 0.1),
                      child: Center(
                        child: Text('Location updating...',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ),
                  // Info overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.3),
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (lat != null && lng != null)
                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    size: 14, color: Colors.white70),
                                const SizedBox(width: 6),
                                Text(
                                  '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Details card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bus Staff',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      Text(
                        busStaffName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Route',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      Text(
                        routeName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Open full screen button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => _FullScreenBusTracking(ride: activeRide),
                      ),
                    );
                  },
                  icon: const Icon(Icons.fullscreen),
                  label: const Text('View Full Map'),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 12),
          Text(
            'Checking bus status...',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String error) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unable to load',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  error,
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveRideCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.directions_bus,
            size: 48,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No Active Bus',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your child\'s bus is not currently in transit',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenBusTracking extends ConsumerStatefulWidget {
  final Map<String, dynamic> ride;

  const _FullScreenBusTracking({required this.ride});

  @override
  ConsumerState<_FullScreenBusTracking> createState() =>
      _FullScreenBusTrackingState();
}

class _FullScreenBusTrackingState extends ConsumerState<_FullScreenBusTracking> {
  @override
  Widget build(BuildContext context) {
    final busStaffName = widget.ride['bus_staff_name'] as String? ?? 'Bus Staff';
    final routeName = widget.ride['route_name'] as String? ?? 'Route';
    
    // Extract location data
    final latestLocation = widget.ride['latest_location'] as Map<String, dynamic>?;
    final lat = latestLocation?['latitude'] as double?;
    final lng = latestLocation?['longitude'] as double?;
    final speed = latestLocation?['speed'] as double? ?? 0;
    
    // Calculate duration
    int duration = 0;
    try {
      final startTimeStr = widget.ride['start_time'] as String?;
      if (startTimeStr != null) {
        final startTime = DateTime.parse(startTimeStr);
        duration = DateTime.now().difference(startTime).inMinutes;
      }
    } catch (e) {
      // If parsing fails, duration stays 0
    }
    
    final busPosition = lat != null && lng != null
        ? Position(
            latitude: lat,
            longitude: lng,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: speed,
            speedAccuracy: 0,
          )
        : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.3),
        elevation: 0,
        leading: IconButton(
          icon: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.arrow_back, color: Colors.black),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              routeName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              busStaffName,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: LiveMapWidget(
              currentPosition: busPosition,
              showPolyline: false,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Icon(Icons.timer, color: AppColors.primary, size: 24),
                          const SizedBox(height: 4),
                          Text(
                            'Duration',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${duration}m',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Icon(Icons.location_on, color: AppColors.primary, size: 24),
                          const SizedBox(height: 4),
                          Text(
                            'Staff',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            busStaffName,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
