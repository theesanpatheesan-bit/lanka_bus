import 'package:lanka_bus/core/network/supabase_client.dart';
import 'package:lanka_bus/features/operator_dashboard/data/models/operator_trip_model.dart';
import 'package:lanka_bus/features/operator_dashboard/domain/repositories/operator_repository.dart';
import 'package:lanka_bus/features/seat_booking/data/models/seat_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OperatorRepositoryImpl implements OperatorRepository {
  OperatorRepositoryImpl({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;

  @override
  Future<List<OperatorTripModel>> fetchTrips({
    required DateTime from,
    required DateTime to,
  }) async {
    final raw = await _client.rpc(
      'list_operator_trips',
      params: {
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      },
    );

    if (raw is! List) return [];
    return List<Map<String, dynamic>>.from(raw)
        .map(OperatorTripModel.fromJson)
        .toList();
  }

  @override
  Future<List<ManifestPassengerModel>> fetchManifest(String scheduleId) async {
    final raw = await _client.rpc(
      'get_trip_manifest',
      params: {'p_schedule_id': scheduleId},
    );
    final list = List<Map<String, dynamic>>.from(raw as List);
    return list.map(ManifestPassengerModel.fromJson).toList();
  }

  @override
  Future<List<SeatModel>> fetchSeatLayout(String scheduleId) async {
    final schedule = await _client
        .from('bus_schedules')
        .select('base_price_lkr, buses!inner(id)')
        .eq('id', scheduleId)
        .single();

    final bus = Map<String, dynamic>.from(schedule['buses'] as Map);
    final fare = (schedule['base_price_lkr'] as num).toDouble();
    final layouts = await _client
        .from('seat_layouts')
        .select()
        .eq('bus_id', bus['id'] as String)
        .order('deck_level')
        .order('row_index')
        .order('column_index');

    final occupancy = await _client
        .from('booked_seats')
        .select('seat_number, status, passenger_gender')
        .eq('schedule_id', scheduleId)
        .inFilter('status', ['reserved', 'locked', 'booked', 'boarded']);

    final bySeat = <String, Map<String, dynamic>>{
      for (final row in List<Map<String, dynamic>>.from(occupancy as List))
        row['seat_number'] as String: row,
    };

    return List<Map<String, dynamic>>.from(layouts as List)
        .map(
          (json) => SeatModel.fromLayoutJson(
            json,
            fareLkr: fare,
            occupancy: bySeat[json['seat_number']],
          ),
        )
        .toList();
  }

  @override
  Future<void> markSeatBoarded({
    required String bookedSeatId,
    required bool boarded,
  }) {
    return _client.rpc(
      'mark_seat_boarded',
      params: {
        'p_booked_seat_id': bookedSeatId,
        'p_boarded': boarded,
      },
    );
  }

  @override
  Future<TicketScanResult> verifyTicket({
    String? bookingId,
    String? pnr,
  }) async {
    final raw = await _client.rpc(
      'verify_and_board_ticket',
      params: {
        'p_booking_id': bookingId,
        'p_pnr': pnr,
      },
    );
    return TicketScanResult.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  @override
  Future<void> upsertBusLocation({
    required String busId,
    required String scheduleId,
    required double latitude,
    required double longitude,
    double? speedKmh,
    double? heading,
  }) {
    return _client.rpc(
      'upsert_bus_location',
      params: {
        'p_bus_id': busId,
        'p_schedule_id': scheduleId,
        'p_lat': latitude,
        'p_lng': longitude,
        'p_speed_kmh': speedKmh,
        'p_heading': heading,
      },
    );
  }
}
