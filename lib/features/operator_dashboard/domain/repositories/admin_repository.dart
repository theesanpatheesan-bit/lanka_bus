import 'package:lanka_bus/features/operator_dashboard/data/models/admin_models.dart';

abstract class AdminRepository {
  Future<AdminMetrics> fetchMetrics();

  Future<List<AdminOperatorItem>> listOperators({String? status});

  Future<void> setOperatorStatus({
    required String operatorId,
    required String status,
    String? note,
  });

  Future<List<AdminBusItem>> listBuses();

  Future<void> upsertBus({
    required String operatorId,
    required String busNumber,
    required String registrationNo,
    required String busType,
    required int totalSeats,
    List<String> amenities,
    String? busId,
    bool generateLayout,
  });

  Future<List<AdminRouteItem>> listRoutes();

  Future<String> upsertRoute({
    required String originCity,
    required String destinationCity,
    String? originTerminal,
    String? destinationTerminal,
    double? distanceKm,
    int? durationMinutes,
    String? routeId,
  });

  Future<void> upsertRoutePoint({
    required String routeId,
    required String pointType,
    required String name,
    int offsetMinutes,
    int sortOrder,
    String? pointId,
  });

  Future<int> createSchedule({
    required String routeId,
    required String busId,
    required String operatorId,
    required DateTime departureAt,
    required DateTime arrivalAt,
    required double basePriceLkr,
    int recurringDays,
  });
}
