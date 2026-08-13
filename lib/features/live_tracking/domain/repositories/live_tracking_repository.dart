import 'dart:async';

import 'package:lanka_bus/features/live_tracking/data/models/live_tracking_snapshot.dart';

abstract class LiveTrackingRepository {
  Future<LiveTrackingSnapshot> fetchSnapshot({
    String? scheduleId,
    String? busId,
  });

  /// Emits updated snapshots when `bus_locations` changes for [busId].
  Stream<LiveTrackingSnapshot> watchBusLocation({
    required String busId,
    required LiveTrackingSnapshot seed,
  });

  Future<void> disposeWatch();
}
