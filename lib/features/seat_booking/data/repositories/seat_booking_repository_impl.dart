import 'package:lanka_bus/features/bus_search/data/models/bus_schedule_model.dart';
import 'package:lanka_bus/features/seat_booking/data/datasources/seat_booking_remote_datasource.dart';
import 'package:lanka_bus/features/seat_booking/data/models/passenger_model.dart';
import 'package:lanka_bus/features/seat_booking/data/models/seat_model.dart';
import 'package:lanka_bus/features/seat_booking/domain/repositories/seat_booking_repository.dart';

class SeatBookingRepositoryImpl implements SeatBookingRepository {
  SeatBookingRepositoryImpl(this._remote);

  final SeatBookingRemoteDataSource _remote;

  @override
  Future<BusScheduleModel> fetchSchedule(String scheduleId) async {
    final row = await _remote.fetchScheduleRow(scheduleId);
    return BusScheduleModel.fromJoinedJson({
      ...row,
      'booked_count': null,
    });
  }

  @override
  Future<List<SeatModel>> fetchSeatMap(String scheduleId) async {
    final schedule = await _remote.fetchScheduleRow(scheduleId);
    final bus = Map<String, dynamic>.from(schedule['buses'] as Map);
    final busId = bus['id'] as String;
    final fare = (schedule['base_price_lkr'] as num).toDouble();

    final layouts = await _remote.fetchLayouts(busId);
    final occupancyRows = await _remote.fetchOccupancy(scheduleId);
    final occupancyBySeat = <String, Map<String, dynamic>>{
      for (final row in occupancyRows) row['seat_number'] as String: row,
    };

    if (layouts.isEmpty) {
      return _fallbackSeaterLayout(fare);
    }

    return layouts
        .map(
          (json) => SeatModel.fromLayoutJson(
            json,
            fareLkr: fare,
            occupancy: occupancyBySeat[json['seat_number']],
          ),
        )
        .toList();
  }

  @override
  Future<List<RoutePointModel>> fetchRoutePoints({
    required String routeId,
    required String pointType,
  }) async {
    final rows = await _remote.fetchRoutePoints(
      routeId: routeId,
      pointType: pointType,
    );
    return rows.map(RoutePointModel.fromJson).toList();
  }

  @override
  Future<String> lockSeats({
    required String scheduleId,
    required List<SeatModel> seats,
    required String passengerName,
    required String passengerPhone,
    String? passengerEmail,
  }) {
    return _remote.lockSeats(
      scheduleId: scheduleId,
      seatNumbers: seats.map((s) => s.seatNumber).toList(),
      seatLayoutIds: seats.map((s) => s.id).toList(),
      fares: seats.map((s) => s.fareLkr).toList(),
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      passengerEmail: passengerEmail,
    );
  }

  @override
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
  }) {
    return _remote.updateBooking(
      bookingId: bookingId,
      bookingFields: {
        'passenger_name': passengers.first.fullName,
        'passenger_phone': contactPhone,
        'passenger_email': contactEmail,
        'boarding_point_id': boarding.id,
        'dropping_point_id': dropping.id,
        'seat_count': passengers.length,
        'base_fare_lkr': baseFare,
        'tax_lkr': tax,
        'discount_lkr': discount,
        'total_amount_lkr': total,
        'promo_code': promoCode,
      },
      seatUpdates: passengers
          .map(
            (p) => {
              'seat_number': p.seatNumber,
              'passenger_name': p.fullName,
              'passenger_gender': p.gender?.dbValue,
            },
          )
          .toList(),
    );
  }

  /// Offline-friendly 2+2 map when layouts are not seeded yet.
  List<SeatModel> _fallbackSeaterLayout(double fare) {
    final seats = <SeatModel>[];
    seats.add(
      SeatModel(
        id: 'drv',
        seatNumber: 'DRV',
        rowIndex: 0,
        columnIndex: 0,
        kind: SeatKind.driver,
        deck: SeatDeck.lower,
        isSelectable: false,
        reservedFor: 'any',
        fareLkr: fare,
      ),
    );
    var n = 1;
    for (var row = 1; row <= 8; row++) {
      for (final col in [0, 1, 2, 3, 4]) {
        if (col == 2) {
          seats.add(
            SeatModel(
              id: 'aisle-$row',
              seatNumber: 'A$row',
              rowIndex: row,
              columnIndex: col,
              kind: SeatKind.aisle,
              deck: SeatDeck.lower,
              isSelectable: false,
              reservedFor: 'any',
              fareLkr: fare,
            ),
          );
          continue;
        }
        final letter = switch (col) {
          0 => 'A',
          1 => 'B',
          3 => 'C',
          _ => 'D',
        };
        seats.add(
          SeatModel(
            id: 'gen-$n',
            seatNumber: '$row$letter',
            rowIndex: row,
            columnIndex: col,
            kind: SeatKind.seater,
            deck: SeatDeck.lower,
            isSelectable: true,
            reservedFor: row <= 2 && col <= 1 ? 'female' : 'any',
            fareLkr: fare,
          ),
        );
        n++;
      }
    }
    return seats;
  }
}
