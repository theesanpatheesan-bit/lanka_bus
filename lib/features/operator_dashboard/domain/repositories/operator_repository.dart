import 'package:lanka_bus/features/operator_dashboard/data/models/operator_trip_model.dart';
import 'package:lanka_bus/features/seat_booking/data/models/seat_model.dart';

abstract class OperatorRepository {
  Future<List<OperatorTripModel>> fetchTrips({
    required DateTime from,
    required DateTime to,
  });

  Future<List<ManifestPassengerModel>> fetchManifest(String scheduleId);

  Future<List<SeatModel>> fetchSeatLayout(String scheduleId);

  Future<void> markSeatBoarded({
    required String bookedSeatId,
    required bool boarded,
  });

  Future<TicketScanResult> verifyTicket({
    String? bookingId,
    String? pnr,
  });

  Future<void> upsertBusLocation({
    required String busId,
    required String scheduleId,
    required double latitude,
    required double longitude,
    double? speedKmh,
    double? heading,
  });
}
