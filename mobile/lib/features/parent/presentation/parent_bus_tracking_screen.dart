import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/parent_bus_tracking_widget.dart';

class ParentBusTrackingScreen extends ConsumerWidget {
  const ParentBusTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      appBar: AppBar(
        title: const Text('Bus Tracking'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const ParentBusTrackingWidget(),
    );
  }
}
