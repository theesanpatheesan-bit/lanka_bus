import 'package:equatable/equatable.dart';
import 'package:lanka_bus/features/auth/domain/entities/user_entity.dart';

/// Data-layer user mapped from the `public.users` table.
class UserModel extends Equatable {
  const UserModel({
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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: (json['full_name'] as String?)?.trim().isNotEmpty == true
          ? json['full_name'] as String
          : 'User',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      nic: json['nic'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: UserRoleX.fromString(json['role'] as String?),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'nic': nic,
      'avatar_url': avatarUrl,
      'role': role.name,
      'is_active': isActive,
    };
  }

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      fullName: fullName,
      email: email,
      phone: phone,
      nic: nic,
      avatarUrl: avatarUrl,
      role: role,
      isActive: isActive,
    );
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      fullName: entity.fullName,
      email: entity.email,
      phone: entity.phone,
      nic: entity.nic,
      avatarUrl: entity.avatarUrl,
      role: entity.role,
      isActive: entity.isActive,
    );
  }

  @override
  List<Object?> get props =>
      [id, fullName, role, email, phone, nic, avatarUrl, isActive];
}
