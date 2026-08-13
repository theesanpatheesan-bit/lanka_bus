import 'package:lanka_bus/features/bus_search/data/models/bus_schedule_model.dart';
import 'package:lanka_bus/features/seat_booking/data/models/passenger_model.dart';
import 'package:lanka_bus/features/seat_booking/data/models/seat_model.dart';

abstract class SeatBookingRepository {
  Future<BusScheduleModel> fetchSchedule(String scheduleId);

  Future<List<SeatModel>> fetchSeatMap(String scheduleId);

  Future<List<RoutePointModel>> fetchRoutePoints({
    required String routeId,
    required String pointType,
  });

  /// Locks seats for 10 minutes; returns pending booking id.
  Future<String> lockSeats({
    required String scheduleId,
    required List<SeatModel> seats,
    required String passengerName,
    required String passengerPhone,
    String? passengerEmail,
  });

  Future<void> updateBookingCheckout({
    required String bookingId,
    required String contactEmail,
    required String contactPhone,
    required RoutePointModel boarding,
    required RoutePointModel dropping,
    required List<PassengerModel> passengers,
    required double baseFare,
    required double tax,
    required double discount,
    required double total,
    String? promoCode,
  });
}
