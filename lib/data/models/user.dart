import 'enums.dart';

/// مستخدم التطبيق (أستاذ أو تلميذ).
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;

  bool get isTeacher => role == UserRole.teacher;
  bool get isStudent => role == UserRole.student;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'].toString(),
        fullName: (json['full_name'] ?? json['name'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        role: UserRole.fromWire(json['role'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'role': role.wire,
      };

  AppUser copyWith({String? fullName, String? email}) => AppUser(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        role: role,
      );

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.fullName == fullName &&
      other.email == email &&
      other.role == role;

  @override
  int get hashCode => Object.hash(id, fullName, email, role);
}

/// جلسة مخزَّنة محليًا: الرمز + بيانات المستخدم.
class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AppUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: (json['token'] ?? json['access_token'] ?? '') as String,
        user: AppUser.fromJson(
          Map<String, dynamic>.from(json['user'] as Map),
        ),
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'user': user.toJson(),
      };
}
