import 'package:lanka_bus/core/network/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SeatBookingRemoteDataSource {
  SeatBookingRemoteDataSource({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> fetchScheduleRow(String scheduleId) async {
    final row = await _client
        .from('bus_schedules')
        .select('''
          id,
          departure_at,
          arrival_at,
          base_price_lkr,
          available_seats,
          status,
          routes!inner (
            id,
            origin_city,
            destination_city,
            origin_terminal,
            destination_terminal,
            distance_km,
            estimated_duration_minutes
          ),
          buses!inner (
            id,
            bus_number,
            bus_type,
            total_seats,
            amenities
          ),
          operators!inner (
            id,
            company_name,
            trade_name,
            rating,
            status
          )
        ''')
        .eq('id', scheduleId)
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> fetchLayouts(String busId) async {
    final rows = await _client
        .from('seat_layouts')
        .select()
        .eq('bus_id', busId)
        .order('deck_level')
        .order('row_index')
        .order('column_index');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> fetchOccupancy(String scheduleId) async {
    await _client.rpc('release_expired_seat_locks');
    final rows = await _client
        .from('booked_seats')
        .select('seat_number, status, passenger_gender, locked_until')
        .eq('schedule_id', scheduleId)
        .inFilter('status', ['reserved', 'locked', 'booked']);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> fetchRoutePoints({
    required String routeId,
    required String pointType,
  }) async {
    final rows = await _client
        .from('route_points')
        .select()
        .eq('route_id', routeId)
        .eq('point_type', pointType)
        .eq('is_active', true)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<String> lockSeats({
    required String scheduleId,
    required List<String> seatNumbers,
    required List<String> seatLayoutIds,
    required List<double> fares,
    required String passengerName,
    required String passengerPhone,
    String? passengerEmail,
  }) async {
    final bookingId = await _client.rpc(
      'lock_seats_for_checkout',
      params: {
        'p_schedule_id': scheduleId,
        'p_seat_numbers': seatNumbers,
        'p_seat_layout_ids': seatLayoutIds,
        'p_fares': fares,
        'p_passenger_name': passengerName,
        'p_passenger_phone': passengerPhone,
        'p_passenger_email': passengerEmail,
        'p_lock_minutes': 10,
      },
    );
    return bookingId as String;
  }

  Future<void> updateBooking({
    required String bookingId,
    required Map<String, dynamic> bookingFields,
    required List<Map<String, dynamic>> seatUpdates,
  }) async {
    await _client.from('bookings').update(bookingFields).eq('id', bookingId);

    for (final seat in seatUpdates) {
      await _client
          .from('booked_seats')
          .update({
            'passenger_name': seat['passenger_name'],
            'passenger_gender': seat['passenger_gender'],
          })
          .eq('booking_id', bookingId)
          .eq('seat_number', seat['seat_number']);
    }
  }
}
