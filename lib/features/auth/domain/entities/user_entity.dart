import 'package:equatable/equatable.dart';

enum UserRole { passenger, operator, conductor, admin }

class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.fullName,
    required this.role,
    this.email,
    this.phone,
    this.nic,
    this.avatarUrl,
  });

  final String id;
  final String fullName;
  final UserRole role;
  final String? email;
  final String? phone;
  final String? nic;
  final String? avatarUrl;

  @override
  List<Object?> get props => [id, fullName, role, email, phone, nic, avatarUrl];
}
