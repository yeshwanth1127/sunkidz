import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/bus_tracking_provider.dart';
import '../../../core/providers/active_ride_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';
import '../data/bus_staff_dashboard_provider.dart';

class BusStaffDashboardScreen extends ConsumerStatefulWidget {
  const BusStaffDashboardScreen({super.key});

  @override
  ConsumerState<BusStaffDashboardScreen> createState() => _BusStaffDashboardScreenState();
}

class _BusStaffDashboardScreenState extends ConsumerState<BusStaffDashboardScreen> {
  bool _showStartRideConfirm = false;
  Map<String, dynamic>? _existingRide;
  bool _isCheckingRide = true;

  @override
  void initState() {
    super.initState();
    // Check for existing rides on next frame to avoid accessing ref during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForExistingRide();
    });
  }

  Future<void> _checkForExistingRide() async {
    if (!mounted) return;
    
    try {
      final rideData = await ref.read(activeRideProvider.notifier).checkForExistingRide();
      if (mounted) {
        setState(() {
          _existingRide = rideData;
          _isCheckingRide = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingRide = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(busStaffDashboardDataProvider);
    final data = dataAsync.valueOrNull ?? const BusStaffDashboardData();
    final activeRide = ref.watch(activeRideProvider);
    
    final routeName = data.routeName ?? 'No route assigned';
    final branchName = data.branchName ?? '—';
    final studentsAssigned = data.studentsAssigned;
    final students = data.students;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'images/new_logo.png',
                height: 32,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.directions_bus, color: AppColors.primary, size: 28);
                },
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activeRide.isTracking ? 'Live Tracking' : 'Bus Dashboard', 
                  style: Theme.of(context).textTheme.titleMedium),
                Text('$routeName • $branchName', 
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutDialog(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Existing Ride Warning Card
            if (_existingRide != null && !activeRide.isTracking)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Active Ride Found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Ride ID:', _existingRide!['id'] ?? 'Unknown'),
                            const SizedBox(height: 8),
                            _buildInfoRow('Route:', _existingRide!['route_name'] ?? 'Unknown'),
                            const SizedBox(height: 8),
                            _buildInfoRow('Started:', _formatStartTime(_existingRide!['start_time'])),
                            const SizedBox(height: 8),
                            _buildInfoRow('Duration:', _calculateDuration(_existingRide!['start_time'])),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You have an active ride from a previous session. Please end it before starting a new ride.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          final rideId = _existingRide!['id'];
                          if (rideId != null) {
                            print('🔴 Button clicked, ride ID: $rideId');
                            _endExistingRide(rideId);
                          } else {
                            print('❌ No ride ID found in existing ride data');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invalid ride ID'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.stop_circle),
                        label: const Text('End This Ride'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Status Card - Start/End Ride
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: activeRide.isTracking ? const Color(0xFFF0F4FF) : Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: activeRide.isTracking ? AppColors.primary : Theme.of(context).dividerColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: activeRide.isTracking ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          activeRide.isTracking ? 'Route Active - Live Tracking' : 'Ready to Start Route',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: activeRide.isTracking ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!activeRide.isTracking)
                      FilledButton.icon(
                        onPressed: () async {
                          print('Start Ride pressed');
                          try {
                            await ref.read(activeRideProvider.notifier).startRide();
                            print('Ride started successfully');
                          } catch (e) {
                            print('Error starting ride: $e');
                          }
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Ride'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Duration:', style: Theme.of(context).textTheme.bodySmall),
                                Text(
                                  _formatDuration(DateTime.now().difference(activeRide.startTime ?? DateTime.now())),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (activeRide.currentLocation != null)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Speed:', style: Theme.of(context).textTheme.bodySmall),
                                  Text(
                                    '${(activeRide.currentLocation!.speed * 3.6).toStringAsFixed(1)} km/h',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _confirmEndRide(ref),
                        icon: const Icon(Icons.stop_circle),
                        label: const Text('End Ride'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                    if (activeRide.error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error, color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                activeRide.error!,
                                style: TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Route Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(routeName, style: Theme.of(context).textTheme.titleMedium),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$studentsAssigned Students',
                            style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Students on Route', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: students.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text('No students assigned',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: students.length,
                      itemBuilder: (_, i) => _StudentPickupTile(student: students[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _confirmEndRide(WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Ride?'),
        content: const Text('Are you sure you want to end this ride? Location tracking will stop.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(activeRideProvider.notifier).endRide();
              Navigator.pop(ctx);
            },
            child: const Text('End Ride'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pop(ctx);
              context.go('/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatStartTime(dynamic startTime) {
    try {
      if (startTime == null) return 'Unknown';
      DateTime dateTime;
      if (startTime is String) {
        dateTime = DateTime.parse(startTime);
      } else if (startTime is DateTime) {
        dateTime = startTime;
      } else {
        return 'Unknown';
      }
      
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  String _calculateDuration(dynamic startTime) {
    try {
      if (startTime == null) return '00:00:00';
      DateTime dateTime;
      if (startTime is String) {
        dateTime = DateTime.parse(startTime);
      } else if (startTime is DateTime) {
        dateTime = startTime;
      } else {
        return '00:00:00';
      }
      
      final duration = DateTime.now().difference(dateTime);
      return _formatDuration(duration);
    } catch (e) {
      return '00:00:00';
    }
  }

  Future<void> _endExistingRide(String rideId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: SizedBox(
          height: 60,
          child: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Ending ride...'),
            ],
          ),
        ),
      ),
    );

    try {
      final success = await ref.read(activeRideProvider.notifier).endRideById(rideId);
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        if (success) {
          setState(() {
            _existingRide = null;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ride ended successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to end ride. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ Exception in _endExistingRide: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _StudentPickupTile extends StatelessWidget {
  final Map<String, dynamic> student;

  const _StudentPickupTile({required this.student});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.pastelGreen,
              child: Text(
                (student['name'] as String? ?? 'S')[0].toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student['name'] as String? ?? 'Unknown',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    student['pickup_address'] as String? ?? 'No address',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Checkbox(value: false, onChanged: (_) {}),
          ],
        ),
      ),
    );
  }
}

class _PickupStudentRow extends StatelessWidget {
  final String name;
  final String parent;
  final bool pickedUp;
  final bool isAbsent;

  const _PickupStudentRow({required this.name, required this.parent, required this.pickedUp, this.isAbsent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                backgroundImage: isAbsent ? null : const NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuBrrPy7opRzJ7ohLK8hGuv4FIYZfYb7SEhA3z6V4qJZX_a-4Uvf7FG4EOyWoS1P9acueQZfb2JJ4QoHFVCMbhE0XAvFGh_fFGovdtB0Vz6e57peh4Rb1U9q9ltlLZlDy-0Hl5MiC6Aek0CJYqB5Ja-BEte6n6EpEzM_itNZTSW2osnBzrnU6Wv0Hp7dFmoZOnFAHbXVKkO-bCJ2OxtUaHYaZqBWdL8W4HYCZFltc7Mb3iE-c2BnVvZB6G76G6fdEOPu93ZaeOyvDjc'),
                child: isAbsent ? Icon(Icons.event_busy, color: Colors.grey) : null,
              ),
              if (pickedUp)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isAbsent ? Colors.grey : null)),
                if (parent.isNotEmpty)
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 18,
                        onPressed: () {},
                        icon: Icon(Icons.call, color: AppColors.primary, size: 18),
                      ),
                      Text(parent, style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                if (isAbsent) Text('Reported Absent', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(isAbsent ? 'N/A' : (pickedUp ? 'Status: In' : 'Status: Waiting'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              if (!isAbsent)
                Switch(
                  value: pickedUp,
                  onChanged: (_) {},
                ),
            ],
          ),
        ],
      ),
    );
  }
}
