import 'package:equatable/equatable.dart';

enum UserRole { passenger, operator, conductor, admin }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.passenger => 'Passenger',
        UserRole.operator => 'Operator',
        UserRole.conductor => 'Conductor',
        UserRole.admin => 'Admin',
      };

  bool get isStaff =>
      this == UserRole.operator ||
      this == UserRole.conductor ||
      this == UserRole.admin;

  bool get isPartnerPortal =>
      this == UserRole.operator || this == UserRole.conductor;

  String get homeRoute => switch (this) {
        UserRole.passenger => '/passenger-home',
        UserRole.operator || UserRole.conductor => '/operator-dashboard',
        UserRole.admin => '/admin-dashboard',
      };

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.passenger,
    );
  }
}

class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.fullName,
    required this.role,
    this.email,
    this.phone,
    this.nic,
    this.avatarUrl,
    this.isActive = true,
  });

  final String id;
  final String fullName;
  final UserRole role;
  final String? email;
  final String? phone;
  final String? nic;
  final String? avatarUrl;
  final bool isActive;

  @override
  List<Object?> get props =>
      [id, fullName, role, email, phone, nic, avatarUrl, isActive];
}
