import 'package:equatable/equatable.dart';
import 'package:lanka_bus/features/bus_search/data/models/bus_schedule_model.dart';

enum BusSortOption { priceLowHigh, departureEarlyLate, ratingHighLow }

enum DepartureTimeSlot { morning, afternoon, evening, night }

extension DepartureTimeSlotX on DepartureTimeSlot {
  String get label => switch (this) {
        DepartureTimeSlot.morning => 'Morning',
        DepartureTimeSlot.afternoon => 'Afternoon',
        DepartureTimeSlot.evening => 'Evening',
        DepartureTimeSlot.night => 'Night',
      };

  String get subtitle => switch (this) {
        DepartureTimeSlot.morning => '5 AM – 11 AM',
        DepartureTimeSlot.afternoon => '12 PM – 4 PM',
        DepartureTimeSlot.evening => '5 PM – 8 PM',
        DepartureTimeSlot.night => '9 PM – 4 AM',
      };

  bool matches(DateTime departureLocal) {
    final hour = departureLocal.hour;
    return switch (this) {
      DepartureTimeSlot.morning => hour >= 5 && hour < 12,
      DepartureTimeSlot.afternoon => hour >= 12 && hour < 17,
      DepartureTimeSlot.evening => hour >= 17 && hour < 21,
      DepartureTimeSlot.night => hour >= 21 || hour < 5,
    };
  }
}

class BusSearchQuery extends Equatable {
  const BusSearchQuery({
    required this.originCity,
    required this.destinationCity,
    required this.departureDate,
  });

  final String originCity;
  final String destinationCity;
  final DateTime departureDate;

  DateTime get dayStart =>
      DateTime(departureDate.year, departureDate.month, departureDate.day);

  DateTime get dayEnd => dayStart.add(const Duration(days: 1));

  bool get isValid =>
      originCity.trim().isNotEmpty &&
      destinationCity.trim().isNotEmpty &&
      originCity.trim().toLowerCase() != destinationCity.trim().toLowerCase();

  @override
  List<Object?> get props => [originCity, destinationCity, dayStart];
}

class BusSearchFilters extends Equatable {
  const BusSearchFilters({
    this.sort = BusSortOption.departureEarlyLate,
    this.busTypeKeys = const {},
    this.operatorIds = const {},
    this.timeSlots = const {},
  });

  final BusSortOption sort;
  final Set<String> busTypeKeys; // ac | non_ac | sleeper | seater
  final Set<String> operatorIds;
  final Set<DepartureTimeSlot> timeSlots;

  bool get hasActiveFilters =>
      busTypeKeys.isNotEmpty ||
      operatorIds.isNotEmpty ||
      timeSlots.isNotEmpty ||
      sort != BusSortOption.departureEarlyLate;

  BusSearchFilters copyWith({
    BusSortOption? sort,
    Set<String>? busTypeKeys,
    Set<String>? operatorIds,
    Set<DepartureTimeSlot>? timeSlots,
  }) {
    return BusSearchFilters(
      sort: sort ?? this.sort,
      busTypeKeys: busTypeKeys ?? this.busTypeKeys,
      operatorIds: operatorIds ?? this.operatorIds,
      timeSlots: timeSlots ?? this.timeSlots,
    );
  }

  List<BusScheduleModel> apply(List<BusScheduleModel> source) {
    var list = List<BusScheduleModel>.from(source);

    if (busTypeKeys.isNotEmpty) {
      final allowed = <BusType>{};
      for (final key in busTypeKeys) {
        allowed.addAll(BusTypeX.group(key));
      }
      list = list.where((s) => allowed.contains(s.busType)).toList();
    }

    if (operatorIds.isNotEmpty) {
      list = list.where((s) => operatorIds.contains(s.operatorId)).toList();
    }

    if (timeSlots.isNotEmpty) {
      list = list
          .where((s) => timeSlots.any((slot) => slot.matches(s.departureAt)))
          .toList();
    }

    switch (sort) {
      case BusSortOption.priceLowHigh:
        list.sort((a, b) => a.basePriceLkr.compareTo(b.basePriceLkr));
      case BusSortOption.departureEarlyLate:
        list.sort((a, b) => a.departureAt.compareTo(b.departureAt));
      case BusSortOption.ratingHighLow:
        list.sort((a, b) => b.rating.compareTo(a.rating));
    }

    return list;
  }

  @override
  List<Object?> get props => [sort, busTypeKeys, operatorIds, timeSlots];
}
