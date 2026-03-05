import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong2.dart';
import '../../../core/api/bus_tracking_provider.dart' show busTrackingApiProvider;
import '../../../core/theme/app_theme.dart';

final activeRidesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(busTrackingApiProvider);
  if (api == null) return [];
  return await api.getAllActiveRides();
});

class AdminLiveTrackingDashboard extends ConsumerStatefulWidget {
  const AdminLiveTrackingDashboard({super.key});

  @override
  ConsumerState<AdminLiveTrackingDashboard> createState() => _AdminLiveTrackingDashboardState();
}

class _AdminLiveTrackingDashboardState extends ConsumerState<AdminLiveTrackingDashboard> {
  final MapController _mapController = MapController();
  late PageController _pageController;
  int _selectedRideIndex = 0;
  bool _showList = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeRides = ref.watch(activeRidesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.3),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Live Bus Tracking',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showList ? Icons.list : Icons.map,
                color: Colors.white,
              ),
            ),
            onPressed: () {
              setState(() => _showList = !_showList);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: activeRides.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading active rides: $err'),
            ],
          ),
        ),
        data: (rides) {
          if (rides.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_bus, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('No active rides', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Bus staff will appear here when they start rides',
                    style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          }

          return Stack(
            children: [
              // Map view
              Positioned.fill(
                child: _MapView(
                  rides: rides,
                  mapController: _mapController,
                  selectedIndex: _selectedRideIndex,
                ),
              ),

              // List overlay
              if (_showList)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _RidesList(
                    rides: rides,
                    selectedIndex: _selectedRideIndex,
                    onSelect: (index) {
                      setState(() => _selectedRideIndex = index);
                      _animateToRide(rides[index]);
                    },
                  ),
                ),

              // FAB - Fit all buses in view
              Positioned(
                bottom: rides.isEmpty ? 16 : 180,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: () => _fitAllBuses(rides),
                  backgroundColor: Colors.white,
                  child: Icon(Icons.fit_screen, color: AppColors.primary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _animateToRide(Map<String, dynamic> ride) {
    final lat = ride['currentLocation']?['latitude'] as double?;
    final lng = ride['currentLocation']?['longitude'] as double?;
    if (lat != null && lng != null) {
      _mapController.move(LatLng(lat, lng), 16);
    }
  }

  void _fitAllBuses(List<Map<String, dynamic>> rides) {
    if (rides.isEmpty) return;

    final points = rides
        .where((r) =>
            r['currentLocation'] != null &&
            r['currentLocation']['latitude'] != null &&
            r['currentLocation']['longitude'] != null)
        .map((r) => LatLng(
            r['currentLocation']['latitude'] as double,
            r['currentLocation']['longitude'] as double))
        .toList();

    if (points.isNotEmpty) {
      _mapController.fitBounds(
        LatLngBounds.fromPoints(points),
        options: const FitBoundsOptions(padding: EdgeInsets.all(100)),
      );
    }
  }
}

class _MapView extends StatelessWidget {
  final List<Map<String, dynamic>> rides;
  final MapController mapController;
  final int selectedIndex;

  const _MapView({
    required this.rides,
    required this.mapController,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: _getInitialCenter(),
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.app',
        ),
        MarkerLayer(
          markers: rides
              .asMap()
              .entries
              .map((e) {
            final index = e.key;
            final ride = e.value;
            final lat = ride['currentLocation']?['latitude'] as double?;
            final lng = ride['currentLocation']?['longitude'] as double?;

            if (lat == null || lng == null) return null;

            final isSelected = index == selectedIndex;
            final staffName = ride['staffName'] as String? ?? 'Bus Staff';
            final routeName = ride['routeName'] as String? ?? 'Route';

            return Marker(
              point: LatLng(lat, lng),
              width: 60,
              height: 60,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.8)
                          : Colors.black.withValues(alpha: 0.2),
                      blurRadius: isSelected ? 12 : 4,
                      spreadRadius: isSelected ? 2 : 0,
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.primary : AppColors.success,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.directions_bus,
                      color: Colors.white,
                      size: isSelected ? 28 : 24,
                    ),
                  ),
                ),
              ),
            );
          })
              .whereType<Marker>()
              .toList(),
        ),
      ],
    );
  }

  LatLng _getInitialCenter() {
    if (rides.isEmpty) {
      return const LatLng(20.5937, 78.9629); // India center
    }

    final firstRide = rides.first;
    final lat = firstRide['currentLocation']?['latitude'] as double?;
    final lng = firstRide['currentLocation']?['longitude'] as double?;

    return lat != null && lng != null ? LatLng(lat, lng) : const LatLng(20.5937, 78.9629);
  }
}

class _RidesList extends StatelessWidget {
  final List<Map<String, dynamic>> rides;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _RidesList({
    required this.rides,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Buses (${rides.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Live',
                        style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: rides.length,
              itemBuilder: (context, index) {
                final ride = rides[index];
                final isSelected = index == selectedIndex;
                final staffName = ride['staffName'] as String? ?? 'Staff $index';
                final routeName = ride['routeName'] as String? ?? 'Route';
                final duration = ride['durationMinutes'] as int? ?? 0;
                final lat = ride['currentLocation']?['latitude'] as double?;
                final lng = ride['currentLocation']?['longitude'] as double?;

                return GestureDetector(
                  onTap: () => onSelect(index),
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.05),
                      border: isSelected
                          ? Border.all(color: AppColors.primary, width: 2)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              staffName,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              routeName,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.timer, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${duration}m',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                        if (lat != null && lng != null)
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 12, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
