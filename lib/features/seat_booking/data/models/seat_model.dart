import 'package:equatable/equatable.dart';

enum SeatDeck { lower, upper }

enum SeatKind { seater, sleeperLower, sleeperUpper, aisle, driver }

enum SeatVisualStatus { available, booked, locked, selected, femaleAvailable, femaleBooked }

class SeatModel extends Equatable {
  const SeatModel({
    required this.id,
    required this.seatNumber,
    required this.rowIndex,
    required this.columnIndex,
    required this.kind,
    required this.deck,
    required this.isSelectable,
    required this.reservedFor,
    required this.fareLkr,
    this.occupancyStatus,
    this.bookedGender,
  });

  final String id;
  final String seatNumber;
  final int rowIndex;
  final int columnIndex;
  final SeatKind kind;
  final SeatDeck deck;
  final bool isSelectable;
  final String reservedFor; // any | female | male
  final double fareLkr;
  final String? occupancyStatus; // reserved | locked | booked from DB
  final String? bookedGender;

  bool get isOccupied =>
      occupancyStatus == 'reserved' ||
      occupancyStatus == 'locked' ||
      occupancyStatus == 'booked' ||
      occupancyStatus == 'boarded';

  bool get isFemalePreferred => reservedFor == 'female';

  SeatVisualStatus get visualStatus {
    if (kind == SeatKind.aisle || kind == SeatKind.driver) {
      return SeatVisualStatus.booked;
    }
    if (isOccupied) {
      return (bookedGender == 'female' || isFemalePreferred)
          ? SeatVisualStatus.femaleBooked
          : SeatVisualStatus.booked;
    }
    if (isFemalePreferred) return SeatVisualStatus.femaleAvailable;
    return SeatVisualStatus.available;
  }

  factory SeatModel.fromLayoutJson(
    Map<String, dynamic> json, {
    required double fareLkr,
    Map<String, dynamic>? occupancy,
  }) {
    final type = json['seat_type'] as String? ?? 'seater';
    final kind = switch (type) {
      'sleeper_lower' => SeatKind.sleeperLower,
      'sleeper_upper' => SeatKind.sleeperUpper,
      'aisle' => SeatKind.aisle,
      'driver' => SeatKind.driver,
      _ => SeatKind.seater,
    };
    final deck = (json['deck_level'] as String?) == 'upper'
        ? SeatDeck.upper
        : SeatDeck.lower;
    final available = json['is_available'] as bool? ?? true;

    return SeatModel(
      id: json['id'] as String,
      seatNumber: json['seat_number'] as String,
      rowIndex: (json['row_index'] as num).toInt(),
      columnIndex: (json['column_index'] as num).toInt(),
      kind: kind,
      deck: deck,
      isSelectable: available && kind != SeatKind.aisle && kind != SeatKind.driver,
      reservedFor: json['reserved_for'] as String? ?? 'any',
      fareLkr: fareLkr,
      occupancyStatus: occupancy?['status'] as String?,
      bookedGender: occupancy?['passenger_gender'] as String?,
    );
  }

  SeatModel copyWithOccupancy(Map<String, dynamic>? occupancy) {
    return SeatModel(
      id: id,
      seatNumber: seatNumber,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      kind: kind,
      deck: deck,
      isSelectable: isSelectable,
      reservedFor: reservedFor,
      fareLkr: fareLkr,
      occupancyStatus: occupancy?['status'] as String?,
      bookedGender: occupancy?['passenger_gender'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, seatNumber, occupancyStatus];
}
