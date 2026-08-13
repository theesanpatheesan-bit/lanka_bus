part of 'seat_booking_bloc.dart';

sealed class SeatBookingEvent extends Equatable {
  const SeatBookingEvent();

  @override
  List<Object?> get props => [];
}

final class SeatBookingStarted extends SeatBookingEvent {
  const SeatBookingStarted({required this.scheduleId, this.schedule});

  final String scheduleId;
  final BusScheduleModel? schedule;

  @override
  List<Object?> get props => [scheduleId, schedule];
}

final class SeatBookingSeatToggled extends SeatBookingEvent {
  const SeatBookingSeatToggled(this.seatNumber);

  final String seatNumber;

  @override
  List<Object?> get props => [seatNumber];
}

final class SeatBookingDeckChanged extends SeatBookingEvent {
  const SeatBookingDeckChanged(this.deck);

  final SeatDeck deck;

  @override
  List<Object?> get props => [deck];
}

final class SeatBookingContinueFromSeats extends SeatBookingEvent {
  const SeatBookingContinueFromSeats({this.user});

  final UserEntity? user;

  @override
  List<Object?> get props => [user];
}

final class SeatBookingBoardingSelected extends SeatBookingEvent {
  const SeatBookingBoardingSelected(this.pointId);

  final String pointId;

  @override
  List<Object?> get props => [pointId];
}

final class SeatBookingDroppingSelected extends SeatBookingEvent {
  const SeatBookingDroppingSelected(this.pointId);

  final String pointId;

  @override
  List<Object?> get props => [pointId];
}

final class SeatBookingContinueFromPoints extends SeatBookingEvent {
  const SeatBookingContinueFromPoints();
}

final class SeatBookingContactChanged extends SeatBookingEvent {
  const SeatBookingContactChanged({this.email, this.phone});

  final String? email;
  final String? phone;

  @override
  List<Object?> get props => [email, phone];
}

final class SeatBookingPassengerUpdated extends SeatBookingEvent {
  const SeatBookingPassengerUpdated({
    required this.seatNumber,
    this.fullName,
    this.age,
    this.gender,
  });

  final String seatNumber;
  final String? fullName;
  final int? age;
  final PassengerGender? gender;

  @override
  List<Object?> get props => [seatNumber, fullName, age, gender];
}

final class SeatBookingPromoChanged extends SeatBookingEvent {
  const SeatBookingPromoChanged(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

final class SeatBookingPromoApplied extends SeatBookingEvent {
  const SeatBookingPromoApplied();
}

final class SeatBookingProceedToPayment extends SeatBookingEvent {
  const SeatBookingProceedToPayment();
}

final class SeatBookingReset extends SeatBookingEvent {
  const SeatBookingReset();
}
