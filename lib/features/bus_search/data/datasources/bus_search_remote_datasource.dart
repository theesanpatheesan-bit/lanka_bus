import 'package:lanka_bus/core/network/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusSearchRemoteDataSource {
  BusSearchRemoteDataSource({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> searchSchedules({
    required String originCity,
    required String destinationCity,
    required DateTime dayStart,
    required DateTime dayEnd,
  }) async {
    final rows = await _client
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
        .eq('status', 'scheduled')
        .eq('routes.origin_city', originCity)
        .eq('routes.destination_city', destinationCity)
        .eq('operators.status', 'active')
        .gte('departure_at', dayStart.toUtc().toIso8601String())
        .lt('departure_at', dayEnd.toUtc().toIso8601String())
        .order('departure_at');

    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) return list;

    final ids = list.map((e) => e['id'] as String).toList();
    final bookedCounts = await _bookedSeatCounts(ids);

    return list.map((row) {
      final id = row['id'] as String;
      return {
        ...row,
        'booked_count': bookedCounts[id] ?? 0,
      };
    }).toList();
  }

  Future<Map<String, int>> _bookedSeatCounts(List<String> scheduleIds) async {
    if (scheduleIds.isEmpty) return {};

    final rows = await _client
        .from('booked_seats')
        .select('schedule_id, status')
        .inFilter('schedule_id', scheduleIds)
        .inFilter('status', ['reserved', 'locked', 'booked']);

    final counts = <String, int>{};
    for (final row in List<Map<String, dynamic>>.from(rows as List)) {
      final id = row['schedule_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<List<String>> fetchDistinctCities() async {
    final origins = await _client
        .from('routes')
        .select('origin_city')
        .eq('is_active', true);
    final destinations = await _client
        .from('routes')
        .select('destination_city')
        .eq('is_active', true);

    final cities = <String>{};
    for (final row in List<Map<String, dynamic>>.from(origins as List)) {
      cities.add(row['origin_city'] as String);
    }
    for (final row in List<Map<String, dynamic>>.from(destinations as List)) {
      cities.add(row['destination_city'] as String);
    }
    final sorted = cities.toList()..sort();
    return sorted;
  }
}
