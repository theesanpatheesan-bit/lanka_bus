part of 'seat_booking_bloc.dart';

enum SeatBookingStatus {
  initial,
  loadingMap,
  selectingSeats,
  locking,
  selectingPoints,
  passengerDetails,
  submitting,
  readyForPayment,
  failure,
}

final class SeatBookingState extends Equatable {
  const SeatBookingState({
    required this.status,
    this.scheduleId,
    this.schedule,
    this.allSeats = const [],
    this.selectedSeatNumbers = const {},
    this.selectedDeck = SeatDeck.lower,
    this.hasUpperDeck = false,
    this.boardingPoints = const [],
    this.droppingPoints = const [],
    this.boardingPointId,
    this.droppingPointId,
    this.bookingId,
    this.lockedUntil,
    this.passengers = const [],
    this.contactEmail = '',
    this.contactPhone = '',
    this.promoInput = '',
    this.appliedPromoCode,
    this.promoMessage,
    this.summary,
    this.errorMessage,
  });

  const SeatBookingState.initial()
      : this(status: SeatBookingStatus.initial);

  final SeatBookingStatus status;
  final String? scheduleId;
  final BusScheduleModel? schedule;
  final List<SeatModel> allSeats;
  final Set<String> selectedSeatNumbers;
  final SeatDeck selectedDeck;
  final bool hasUpperDeck;
  final List<RoutePointModel> boardingPoints;
  final List<RoutePointModel> droppingPoints;
  final String? boardingPointId;
  final String? droppingPointId;
  final String? bookingId;
  final DateTime? lockedUntil;
  final List<PassengerModel> passengers;
  final String contactEmail;
  final String contactPhone;
  final String promoInput;
  final String? appliedPromoCode;
  final String? promoMessage;
  final BookingSummaryModel? summary;
  final String? errorMessage;

  List<SeatModel> get selectedSeats => allSeats
      .where((s) => selectedSeatNumbers.contains(s.seatNumber))
      .toList()
    ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));

  List<SeatModel> seatsForDeck(SeatDeck deck) =>
      allSeats.where((s) => s.deck == deck).toList();

  RoutePointModel? get boardingPoint {
    final id = boardingPointId;
    if (id == null) return null;
    try {
      return boardingPoints.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  RoutePointModel? get droppingPoint {
    final id = droppingPointId;
    if (id == null) return null;
    try {
      return droppingPoints.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  double get selectedTotal =>
      selectedSeats.fold<double>(0, (sum, s) => sum + s.fareLkr);

  ({double base, double tax, double discount, double total}) get pricing =>
      BookingSummaryModel.calculate(
        seats: selectedSeats,
        promoCode: appliedPromoCode,
      );

  SeatBookingState copyWith({
    SeatBookingStatus? status,
    String? scheduleId,
    BusScheduleModel? schedule,
    List<SeatModel>? allSeats,
    Set<String>? selectedSeatNumbers,
    SeatDeck? selectedDeck,
    bool? hasUpperDeck,
    List<RoutePointModel>? boardingPoints,
    List<RoutePointModel>? droppingPoints,
    String? boardingPointId,
    String? droppingPointId,
    String? bookingId,
    DateTime? lockedUntil,
    List<PassengerModel>? passengers,
    String? contactEmail,
    String? contactPhone,
    String? promoInput,
    String? appliedPromoCode,
    String? promoMessage,
    BookingSummaryModel? summary,
    String? errorMessage,
    bool clearError = false,
    bool clearSummary = false,
    bool clearPromo = false,
  }) {
    return SeatBookingState(
      status: status ?? this.status,
      scheduleId: scheduleId ?? this.scheduleId,
      schedule: schedule ?? this.schedule,
      allSeats: allSeats ?? this.allSeats,
      selectedSeatNumbers: selectedSeatNumbers ?? this.selectedSeatNumbers,
      selectedDeck: selectedDeck ?? this.selectedDeck,
      hasUpperDeck: hasUpperDeck ?? this.hasUpperDeck,
      boardingPoints: boardingPoints ?? this.boardingPoints,
      droppingPoints: droppingPoints ?? this.droppingPoints,
      boardingPointId: boardingPointId ?? this.boardingPointId,
      droppingPointId: droppingPointId ?? this.droppingPointId,
      bookingId: bookingId ?? this.bookingId,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      passengers: passengers ?? this.passengers,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      promoInput: promoInput ?? this.promoInput,
      appliedPromoCode:
          clearPromo ? null : (appliedPromoCode ?? this.appliedPromoCode),
      promoMessage: promoMessage ?? this.promoMessage,
      summary: clearSummary ? null : (summary ?? this.summary),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        scheduleId,
        schedule,
        allSeats,
        selectedSeatNumbers,
        selectedDeck,
        hasUpperDeck,
        boardingPoints,
        droppingPoints,
        boardingPointId,
        droppingPointId,
        bookingId,
        lockedUntil,
        passengers,
        contactEmail,
        contactPhone,
        promoInput,
        appliedPromoCode,
        promoMessage,
        summary,
        errorMessage,
      ];
}
