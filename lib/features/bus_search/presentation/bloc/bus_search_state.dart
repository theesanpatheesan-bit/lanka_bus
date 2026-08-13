part of 'bus_search_bloc.dart';

enum BusSearchStatus { initial, loading, success, empty, failure }

final class BusSearchState extends Equatable {
  const BusSearchState({
    required this.status,
    required this.originCity,
    required this.destinationCity,
    required this.departureDate,
    required this.cities,
    required this.rawResults,
    required this.filters,
    this.query,
    this.validationMessage,
    this.errorMessage,
  });

  factory BusSearchState.initial() {
    final now = DateTime.now();
    return BusSearchState(
      status: BusSearchStatus.initial,
      originCity: 'Colombo',
      destinationCity: 'Kandy',
      departureDate: DateTime(now.year, now.month, now.day),
      cities: SriLankaCities.all,
      rawResults: const [],
      filters: const BusSearchFilters(),
    );
  }

  final BusSearchStatus status;
  final String originCity;
  final String destinationCity;
  final DateTime departureDate;
  final List<String> cities;
  final List<BusScheduleModel> rawResults;
  final BusSearchFilters filters;
  final BusSearchQuery? query;
  final String? validationMessage;
  final String? errorMessage;

  List<BusScheduleModel> get visibleResults => filters.apply(rawResults);

  List<({String id, String name})> get availableOperators {
    final map = <String, String>{};
    for (final s in rawResults) {
      map[s.operatorId] = s.operatorName;
    }
    final list = map.entries
        .map((e) => (id: e.key, name: e.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  BusSearchState copyWith({
    BusSearchStatus? status,
    String? originCity,
    String? destinationCity,
    DateTime? departureDate,
    List<String>? cities,
    List<BusScheduleModel>? rawResults,
    BusSearchFilters? filters,
    BusSearchQuery? query,
    String? validationMessage,
    String? errorMessage,
    bool clearValidation = false,
    bool clearError = false,
  }) {
    return BusSearchState(
      status: status ?? this.status,
      originCity: originCity ?? this.originCity,
      destinationCity: destinationCity ?? this.destinationCity,
      departureDate: departureDate ?? this.departureDate,
      cities: cities ?? this.cities,
      rawResults: rawResults ?? this.rawResults,
      filters: filters ?? this.filters,
      query: query ?? this.query,
      validationMessage:
          clearValidation ? null : (validationMessage ?? this.validationMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        originCity,
        destinationCity,
        departureDate,
        cities,
        rawResults,
        filters,
        query,
        validationMessage,
        errorMessage,
      ];
}
