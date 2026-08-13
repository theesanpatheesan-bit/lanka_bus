part of 'bus_search_bloc.dart';

sealed class BusSearchEvent extends Equatable {
  const BusSearchEvent();

  @override
  List<Object?> get props => [];
}

final class BusSearchCitiesRequested extends BusSearchEvent {
  const BusSearchCitiesRequested();
}

final class BusSearchOriginChanged extends BusSearchEvent {
  const BusSearchOriginChanged(this.city);

  final String city;

  @override
  List<Object?> get props => [city];
}

final class BusSearchDestinationChanged extends BusSearchEvent {
  const BusSearchDestinationChanged(this.city);

  final String city;

  @override
  List<Object?> get props => [city];
}

final class BusSearchCitiesSwapped extends BusSearchEvent {
  const BusSearchCitiesSwapped();
}

final class BusSearchDateChanged extends BusSearchEvent {
  const BusSearchDateChanged(this.date);

  final DateTime date;

  @override
  List<Object?> get props => [date];
}

final class BusSearchSubmitted extends BusSearchEvent {
  const BusSearchSubmitted();
}

final class BusSearchFiltersApplied extends BusSearchEvent {
  const BusSearchFiltersApplied(this.filters);

  final BusSearchFilters filters;

  @override
  List<Object?> get props => [filters];
}

final class BusSearchFiltersReset extends BusSearchEvent {
  const BusSearchFiltersReset();
}
