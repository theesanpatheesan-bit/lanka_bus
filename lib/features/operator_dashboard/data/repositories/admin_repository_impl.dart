import 'package:lanka_bus/core/network/supabase_client.dart';
import 'package:lanka_bus/features/operator_dashboard/data/models/admin_models.dart';
import 'package:lanka_bus/features/operator_dashboard/domain/repositories/admin_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;

  @override
  Future<AdminMetrics> fetchMetrics() async {
    final raw = await _client.rpc('admin_dashboard_metrics');
    return AdminMetrics.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  @override
  Future<List<AdminOperatorItem>> listOperators({String? status}) async {
    final raw = await _client.rpc(
      'admin_list_operators',
      params: {'p_status': status},
    );
    return List<Map<String, dynamic>>.from(raw as List)
        .map(AdminOperatorItem.fromJson)
        .toList();
  }

  @override
  Future<void> setOperatorStatus({
    required String operatorId,
    required String status,
    String? note,
  }) async {
    await _client.rpc(
      'admin_set_operator_status',
      params: {
        'p_operator_id': operatorId,
        'p_status': status,
        'p_note': note,
      },
    );
  }

  @override
  Future<List<AdminBusItem>> listBuses() async {
    final raw = await _client.rpc('admin_list_buses');
    return List<Map<String, dynamic>>.from(raw as List)
        .map(AdminBusItem.fromJson)
        .toList();
  }

  @override
  Future<void> upsertBus({
    required String operatorId,
    required String busNumber,
    required String registrationNo,
    required String busType,
    required int totalSeats,
    List<String> amenities = const [],
    String? busId,
    bool generateLayout = true,
  }) async {
    await _client.rpc(
      'admin_upsert_bus',
      params: {
        'p_operator_id': operatorId,
        'p_bus_number': busNumber,
        'p_registration_no': registrationNo,
        'p_bus_type': busType,
        'p_total_seats': totalSeats,
        'p_amenities': amenities,
        'p_bus_id': busId,
        'p_generate_layout': generateLayout,
      },
    );
  }

  @override
  Future<List<AdminRouteItem>> listRoutes() async {
    final raw = await _client.rpc('admin_list_routes');
    return List<Map<String, dynamic>>.from(raw as List)
        .map(AdminRouteItem.fromJson)
        .toList();
  }

  @override
  Future<String> upsertRoute({
    required String originCity,
    required String destinationCity,
    String? originTerminal,
    String? destinationTerminal,
    double? distanceKm,
    int? durationMinutes,
    String? routeId,
  }) async {
    final raw = await _client.rpc(
      'admin_upsert_route',
      params: {
        'p_origin_city': originCity,
        'p_destination_city': destinationCity,
        'p_origin_terminal': originTerminal,
        'p_destination_terminal': destinationTerminal,
        'p_distance_km': distanceKm,
        'p_duration_minutes': durationMinutes,
        'p_route_id': routeId,
      },
    );
    return Map<String, dynamic>.from(raw as Map)['id'] as String;
  }

  @override
  Future<void> upsertRoutePoint({
    required String routeId,
    required String pointType,
    required String name,
    int offsetMinutes = 0,
    int sortOrder = 0,
    String? pointId,
  }) async {
    await _client.rpc(
      'admin_upsert_route_point',
      params: {
        'p_route_id': routeId,
        'p_point_type': pointType,
        'p_name': name,
        'p_offset_minutes': offsetMinutes,
        'p_sort_order': sortOrder,
        'p_point_id': pointId,
      },
    );
  }

  @override
  Future<int> createSchedule({
    required String routeId,
    required String busId,
    required String operatorId,
    required DateTime departureAt,
    required DateTime arrivalAt,
    required double basePriceLkr,
    int recurringDays = 1,
  }) async {
    final raw = await _client.rpc(
      'admin_create_schedule',
      params: {
        'p_route_id': routeId,
        'p_bus_id': busId,
        'p_operator_id': operatorId,
        'p_departure_at': departureAt.toUtc().toIso8601String(),
        'p_arrival_at': arrivalAt.toUtc().toIso8601String(),
        'p_base_price_lkr': basePriceLkr,
        'p_recurring_days': recurringDays,
      },
    );
    return (Map<String, dynamic>.from(raw as Map)['count'] as num).toInt();
  }
}
