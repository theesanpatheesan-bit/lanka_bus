import 'dart:async';

import 'package:lanka_bus/core/network/supabase_client.dart';
import 'package:lanka_bus/features/live_tracking/data/models/live_tracking_snapshot.dart';
import 'package:lanka_bus/features/live_tracking/domain/repositories/live_tracking_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveTrackingRepositoryImpl implements LiveTrackingRepository {
  LiveTrackingRepositoryImpl({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;
  RealtimeChannel? _channel;

  @override
  Future<LiveTrackingSnapshot> fetchSnapshot({
    String? scheduleId,
    String? busId,
  }) async {
    final raw = await _client.rpc(
      'get_live_tracking_snapshot',
      params: {
        'p_schedule_id': scheduleId,
        'p_bus_id': busId,
      },
    );
    return LiveTrackingSnapshot.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  @override
  Stream<LiveTrackingSnapshot> watchBusLocation({
    required String busId,
    required LiveTrackingSnapshot seed,
  }) {
    final controller = StreamController<LiveTrackingSnapshot>.broadcast(
      onCancel: () {
        unawaited(disposeWatch());
      },
    );

    var current = seed;
    controller.add(current);

    _channel = _client
        .channel('bus-loc-$busId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bus_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'bus_id',
            value: busId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            if (row.isEmpty) return;
            final lat = (row['current_latitude'] as num?)?.toDouble();
            final lng = (row['current_longitude'] as num?)?.toDouble();
            if (lat == null || lng == null) return;

            final updatedAt = row['updated_at'] != null
                ? DateTime.parse(row['updated_at'] as String).toLocal()
                : DateTime.now();
            final online =
                DateTime.now().difference(updatedAt) < const Duration(minutes: 3);

            current = current.copyWithLocation(
              latitude: lat,
              longitude: lng,
              speedKmh: (row['speed_kmh'] as num?)?.toDouble(),
              headingDegrees: (row['heading_degrees'] as num?)?.toDouble(),
              locationUpdatedAt: updatedAt,
              isOnline: online,
            );
            if (!controller.isClosed) controller.add(current);
          },
        )
        .subscribe();

    return controller.stream;
  }

  @override
  Future<void> disposeWatch() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }
}
