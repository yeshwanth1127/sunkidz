import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class LiveMapWidget extends StatefulWidget {
  final Position? currentPosition;
  final List<Position> locationHistory;
  final String? routeName;
  final VoidCallback? onMapTap;
  final bool showPolyline;

  const LiveMapWidget({
    super.key,
    this.currentPosition,
    this.locationHistory = const [],
    this.routeName,
    this.onMapTap,
    this.showPolyline = true,
  });

  @override
  State<LiveMapWidget> createState() => _LiveMapWidgetState();
}

class _LiveMapWidgetState extends State<LiveMapWidget> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(LiveMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-center map on current position
    if (widget.currentPosition != null) {
      _mapController.move(
        LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude),
        18,
      );
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<LatLng> _getPolylinePoints() {
    return widget.locationHistory
        .map((pos) => LatLng(pos.latitude, pos.longitude))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentLatLng = widget.currentPosition != null
        ? LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude)
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: currentLatLng ?? const LatLng(20.5937, 78.9629), // Default: India center
          initialZoom: 18,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.sunkidz_lms',
          ),
          if (widget.showPolyline && _getPolylinePoints().isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _getPolylinePoints(),
                  color: Colors.blue.withValues(alpha: 0.6),
                  strokeWidth: 3,
                ),
              ],
            ),
          if (currentLatLng != null)
            MarkerLayer(
              markers: [
                Marker(
                  width: 40,
                  height: 40,
                  point: currentLatLng,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.directions_bus, color: Colors.white, size: 24),
                  ),
                ),
                // Mark start point
                if (widget.locationHistory.isNotEmpty)
                  Marker(
                    width: 30,
                    height: 30,
                    point: LatLng(
                      widget.locationHistory.first.latitude,
                      widget.locationHistory.first.longitude,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flag, color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
