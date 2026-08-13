import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lanka_bus/core/constants/app_constants.dart';
import 'package:lanka_bus/features/auth/domain/entities/user_entity.dart';
import 'package:lanka_bus/features/bus_search/data/models/bus_schedule_model.dart';
import 'package:lanka_bus/features/seat_booking/data/models/booking_summary_model.dart';
import 'package:lanka_bus/features/seat_booking/data/models/passenger_model.dart';
import 'package:lanka_bus/features/seat_booking/data/models/seat_model.dart';
import 'package:lanka_bus/features/seat_booking/domain/repositories/seat_booking_repository.dart';

part 'seat_booking_event.dart';
part 'seat_booking_state.dart';

class SeatBookingBloc extends Bloc<SeatBookingEvent, SeatBookingState> {
  SeatBookingBloc(this._repository) : super(const SeatBookingState.initial()) {
    on<SeatBookingStarted>(_onStarted);
    on<SeatBookingSeatToggled>(_onSeatToggled);
    on<SeatBookingDeckChanged>(_onDeckChanged);
    on<SeatBookingContinueFromSeats>(_onContinueFromSeats);
    on<SeatBookingBoardingSelected>(_onBoardingSelected);
    on<SeatBookingDroppingSelected>(_onDroppingSelected);
    on<SeatBookingContinueFromPoints>(_onContinueFromPoints);
    on<SeatBookingContactChanged>(_onContactChanged);
    on<SeatBookingPassengerUpdated>(_onPassengerUpdated);
    on<SeatBookingPromoChanged>(_onPromoChanged);
    on<SeatBookingPromoApplied>(_onPromoApplied);
    on<SeatBookingProceedToPayment>(_onProceedToPayment);
    on<SeatBookingReset>(_onReset);
  }

  final SeatBookingRepository _repository;

  Future<void> _onStarted(
    SeatBookingStarted event,
    Emitter<SeatBookingState> emit,
  ) async {
    emit(
      state.copyWith(
        status: SeatBookingStatus.loadingMap,
        scheduleId: event.scheduleId,
        clearError: true,
        clearSummary: true,
      ),
    );

    try {
      final schedule = event.schedule ??
          await _repository.fetchSchedule(event.scheduleId);
      final seats = await _repository.fetchSeatMap(event.scheduleId);
      final boarding = await _repository.fetchRoutePoints(
        routeId: schedule.route.id,
        pointType: 'boarding',
      );
      final dropping = await _repository.fetchRoutePoints(
        routeId: schedule.route.id,
        pointType: 'dropping',
      );

      final hasUpper = seats.any((s) => s.deck == SeatDeck.upper);

      emit(
        state.copyWith(
          status: SeatBookingStatus.selectingSeats,
          schedule: schedule,
          allSeats: seats,
          boardingPoints: boarding,
          droppingPoints: dropping,
          selectedDeck: SeatDeck.lower,
          hasUpperDeck: hasUpper,
          selectedSeatNumbers: const {},
          bookingId: null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: SeatBookingStatus.failure,
          errorMessage: 'Could not load seat map. Please try again.',
        ),
      );
    }
  }

  void _onSeatToggled(
    SeatBookingSeatToggled event,
    Emitter<SeatBookingState> emit,
  ) {
    SeatModel? seat;
    for (final s in state.allSeats) {
      if (s.seatNumber == event.seatNumber) {
        seat = s;
        break;
      }
    }
    if (seat == null || !seat.isSelectable || seat.isOccupied) return;

    final selected = {...state.selectedSeatNumbers};
    if (selected.contains(event.seatNumber)) {
      selected.remove(event.seatNumber);
    } else {
      if (selected.length >= AppConstants.maxSeatsPerBooking) {
        emit(
          state.copyWith(
            errorMessage:
                'You can select up to ${AppConstants.maxSeatsPerBooking} seats.',
          ),
        );
        return;
      }
      selected.add(event.seatNumber);
    }

    emit(
      state.copyWith(
        selectedSeatNumbers: selected,
        clearError: true,
      ),
    );
  }

  void _onDeckChanged(
    SeatBookingDeckChanged event,
    Emitter<SeatBookingState> emit,
  ) {
    emit(state.copyWith(selectedDeck: event.deck));
  }

  Future<void> _onContinueFromSeats(
    SeatBookingContinueFromSeats event,
    Emitter<SeatBookingState> emit,
  ) async {
    if (state.selectedSeats.isEmpty) {
      emit(state.copyWith(errorMessage: 'Select at least one seat.'));
      return;
    }

    emit(state.copyWith(status: SeatBookingStatus.locking, clearError: true));

    try {
      final user = event.user;
      final bookingId = await _repository.lockSeats(
        scheduleId: state.scheduleId!,
        seats: state.selectedSeats,
        passengerName: user?.fullName ?? 'Passenger',
        passengerPhone: user?.phone ?? '+94700000000',
        passengerEmail: user?.email,
      );

      final passengers = state.selectedSeats
          .map(
            (s) => PassengerModel(
              seatNumber: s.seatNumber,
              seatLayoutId: s.id,
              fareLkr: s.fareLkr,
              fullName: user?.fullName ?? '',
            ),
          )
          .toList();

      emit(
        state.copyWith(
          status: SeatBookingStatus.selectingPoints,
          bookingId: bookingId,
          passengers: passengers,
          contactEmail: user?.email ?? '',
          contactPhone: user?.phone ?? '',
          lockedUntil: DateTime.now().add(AppConstants.seatLockDuration),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: SeatBookingStatus.selectingSeats,
          errorMessage: error.toString().contains('taken')
              ? 'One or more seats were just taken. Please choose again.'
              : 'Could not lock seats. Please try again.',
        ),
      );
      add(SeatBookingStarted(scheduleId: state.scheduleId!));
    }
  }

  void _onBoardingSelected(
    SeatBookingBoardingSelected event,
    Emitter<SeatBookingState> emit,
  ) {
    emit(state.copyWith(boardingPointId: event.pointId, clearError: true));
  }

  void _onDroppingSelected(
    SeatBookingDroppingSelected event,
    Emitter<SeatBookingState> emit,
  ) {
    emit(state.copyWith(droppingPointId: event.pointId, clearError: true));
  }

  void _onContinueFromPoints(
    SeatBookingContinueFromPoints event,
    Emitter<SeatBookingState> emit,
  ) {
    if (state.boardingPoint == null || state.droppingPoint == null) {
      emit(
        state.copyWith(
          errorMessage: 'Select both boarding and dropping points.',
        ),
      );
      return;
    }
    emit(state.copyWith(status: SeatBookingStatus.passengerDetails));
  }

  void _onContactChanged(
    SeatBookingContactChanged event,
    Emitter<SeatBookingState> emit,
  ) {
    emit(
      state.copyWith(
        contactEmail: event.email ?? state.contactEmail,
        contactPhone: event.phone ?? state.contactPhone,
        clearError: true,
      ),
    );
  }

  void _onPassengerUpdated(
    SeatBookingPassengerUpdated event,
    Emitter<SeatBookingState> emit,
  ) {
    final list = [...state.passengers];
    final index = list.indexWhere((p) => p.seatNumber == event.seatNumber);
    if (index < 0) return;
    list[index] = list[index].copyWith(
      fullName: event.fullName,
      age: event.age,
      gender: event.gender,
    );
    emit(state.copyWith(passengers: list, clearError: true));
  }

  void _onPromoChanged(
    SeatBookingPromoChanged event,
    Emitter<SeatBookingState> emit,
  ) {
    emit(state.copyWith(promoInput: event.code, promoMessage: null));
  }

  void _onPromoApplied(
    SeatBookingPromoApplied event,
    Emitter<SeatBookingState> emit,
  ) {
    final code = state.promoInput.trim().toUpperCase();
    if (code.isEmpty) {
      emit(
        state.copyWith(
          clearPromo: true,
          promoMessage: 'Enter a promo code',
        ),
      );
      return;
    }
    if (code == BookingSummaryModel.promoCodeValue) {
      emit(
        state.copyWith(
          appliedPromoCode: code,
          promoMessage: '10% discount applied!',
        ),
      );
    } else {
      emit(
        state.copyWith(
          clearPromo: true,
          promoMessage: 'Invalid promo code',
        ),
      );
    }
  }

  Future<void> _onProceedToPayment(
    SeatBookingProceedToPayment event,
    Emitter<SeatBookingState> emit,
  ) async {
    final email = state.contactEmail.trim();
    final phone = state.contactPhone.trim();

    if (email.isEmpty || !email.contains('@')) {
      emit(state.copyWith(errorMessage: 'Enter a valid contact email.'));
      return;
    }
    if (phone.length < 9) {
      emit(state.copyWith(errorMessage: 'Enter a valid mobile number.'));
      return;
    }
    if (state.passengers.any((p) => !p.isValid)) {
      emit(
        state.copyWith(
          errorMessage: 'Complete name, age, and gender for every passenger.',
        ),
      );
      return;
    }
    if (state.boardingPoint == null ||
        state.droppingPoint == null ||
        state.bookingId == null ||
        state.schedule == null) {
      emit(state.copyWith(errorMessage: 'Booking session is incomplete.'));
      return;
    }

    final pricing = BookingSummaryModel.calculate(
      seats: state.selectedSeats,
      promoCode: state.appliedPromoCode,
    );

    emit(state.copyWith(status: SeatBookingStatus.submitting, clearError: true));

    try {
      await _repository.updateBookingCheckout(
        bookingId: state.bookingId!,
        contactEmail: email,
        contactPhone: phone,
        boarding: state.boardingPoint!,
        dropping: state.droppingPoint!,
        passengers: state.passengers,
        baseFare: pricing.base,
        tax: pricing.tax,
        discount: pricing.discount,
        total: pricing.total,
        promoCode: state.appliedPromoCode,
      );

      final summary = BookingSummaryModel(
        scheduleId: state.scheduleId!,
        bookingId: state.bookingId!,
        operatorName: state.schedule!.operatorName,
        routeLabel: state.schedule!.route.label,
        departureAt: state.schedule!.departureAt,
        selectedSeats: state.selectedSeats,
        passengers: state.passengers,
        contactEmail: email,
        contactPhone: phone,
        boardingPoint: state.boardingPoint!,
        droppingPoint: state.droppingPoint!,
        baseFareLkr: pricing.base,
        taxLkr: pricing.tax,
        discountLkr: pricing.discount,
        totalLkr: pricing.total,
        promoCode: state.appliedPromoCode,
      );

      emit(
        state.copyWith(
          status: SeatBookingStatus.readyForPayment,
          summary: summary,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: SeatBookingStatus.passengerDetails,
          errorMessage: 'Could not save passenger details. Please try again.',
        ),
      );
    }
  }

  void _onReset(SeatBookingReset event, Emitter<SeatBookingState> emit) {
    emit(const SeatBookingState.initial());
  }
}
