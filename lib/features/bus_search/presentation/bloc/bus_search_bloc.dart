import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lanka_bus/core/constants/sri_lanka_cities.dart';
import 'package:lanka_bus/features/bus_search/data/models/bus_schedule_model.dart';
import 'package:lanka_bus/features/bus_search/domain/entities/bus_search_query.dart';
import 'package:lanka_bus/features/bus_search/domain/repositories/bus_search_repository.dart';

part 'bus_search_event.dart';
part 'bus_search_state.dart';

class BusSearchBloc extends Bloc<BusSearchEvent, BusSearchState> {
  BusSearchBloc(this._repository) : super(BusSearchState.initial()) {
    on<BusSearchCitiesRequested>(_onCitiesRequested);
    on<BusSearchOriginChanged>(_onOriginChanged);
    on<BusSearchDestinationChanged>(_onDestinationChanged);
    on<BusSearchCitiesSwapped>(_onCitiesSwapped);
    on<BusSearchDateChanged>(_onDateChanged);
    on<BusSearchSubmitted>(_onSubmitted);
    on<BusSearchFiltersApplied>(_onFiltersApplied);
    on<BusSearchFiltersReset>(_onFiltersReset);
  }

  final BusSearchRepository _repository;

  Future<void> _onCitiesRequested(
    BusSearchCitiesRequested event,
    Emitter<BusSearchState> emit,
  ) async {
    final cities = await _repository.fetchCities();
    emit(state.copyWith(cities: cities));
  }

  void _onOriginChanged(
    BusSearchOriginChanged event,
    Emitter<BusSearchState> emit,
  ) {
    emit(state.copyWith(originCity: event.city, clearValidation: true));
  }

  void _onDestinationChanged(
    BusSearchDestinationChanged event,
    Emitter<BusSearchState> emit,
  ) {
    emit(state.copyWith(destinationCity: event.city, clearValidation: true));
  }

  void _onCitiesSwapped(
    BusSearchCitiesSwapped event,
    Emitter<BusSearchState> emit,
  ) {
    emit(
      state.copyWith(
        originCity: state.destinationCity,
        destinationCity: state.originCity,
        clearValidation: true,
      ),
    );
  }

  void _onDateChanged(
    BusSearchDateChanged event,
    Emitter<BusSearchState> emit,
  ) {
    emit(state.copyWith(departureDate: event.date, clearValidation: true));
  }

  Future<void> _onSubmitted(
    BusSearchSubmitted event,
    Emitter<BusSearchState> emit,
  ) async {
    final query = BusSearchQuery(
      originCity: state.originCity,
      destinationCity: state.destinationCity,
      departureDate: state.departureDate,
    );

    if (!query.isValid) {
      emit(
        state.copyWith(
          validationMessage: state.originCity.isEmpty ||
                  state.destinationCity.isEmpty
              ? 'Select both From and To cities.'
              : 'From and To cannot be the same city.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: BusSearchStatus.loading,
        query: query,
        clearValidation: true,
        clearError: true,
      ),
    );

    try {
      final results = await _repository.searchSchedules(query);
      emit(
        state.copyWith(
          status: results.isEmpty
              ? BusSearchStatus.empty
              : BusSearchStatus.success,
          rawResults: results,
          filters: const BusSearchFilters(),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: BusSearchStatus.failure,
          errorMessage: 'Could not load buses. Please try again.',
        ),
      );
    }
  }

  void _onFiltersApplied(
    BusSearchFiltersApplied event,
    Emitter<BusSearchState> emit,
  ) {
    emit(state.copyWith(filters: event.filters));
  }

  void _onFiltersReset(
    BusSearchFiltersReset event,
    Emitter<BusSearchState> emit,
  ) {
    emit(state.copyWith(filters: const BusSearchFilters()));
  }
}
