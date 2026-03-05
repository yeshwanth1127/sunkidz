import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/active_ride_provider.dart';
import '../../../shared/widgets/live_map_widget.dart';

class BusStaffLiveTrackingScreen extends ConsumerWidget {
  const BusStaffLiveTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRide = ref.watch(activeRideProvider);

    if (!activeRide.isTracking) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Tracking')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('No active ride', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Start a ride to begin live tracking', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }



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
            Text(activeRide.routeName ?? 'Active Ride',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Live GPS Active',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Full-screen map
          Positioned.fill(
            child: LiveMapWidget(
              currentPosition: activeRide.currentLocation,
              showPolyline: true,
            ),
          ),

          // Bottom info panel
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        icon: Icons.timer,
                        label: 'Duration',
                        value: _formatDuration(DateTime.now()
                            .difference(activeRide.startTime ?? DateTime.now())),
                      ),
                      _StatItem(
                        icon: Icons.speed,
                        label: 'Current Speed',
                        value: activeRide.currentLocation != null
                            ? '${(activeRide.currentLocation!.speed * 3.6).toStringAsFixed(1)} km/h'
                            : '— km/h',
                      ),
                      _StatItem(
                        icon: Icons.location_on,
                        label: 'Accuracy',
                        value: activeRide.currentLocation != null
                            ? '±${activeRide.currentLocation!.accuracy.toStringAsFixed(0)}m'
                            : '—',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location info
                  if (activeRide.currentLocation != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Location',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  '${activeRide.currentLocation!.latitude.toStringAsFixed(4)}, '
                                  '${activeRide.currentLocation!.longitude.toStringAsFixed(4)}',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // FAB - Center on location
          Positioned(
            bottom: 260,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: () => {}, // Map controller handles this
              backgroundColor: Colors.white,
              child: Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m ${seconds}s';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
        )),
      ],
    );
  }
}
