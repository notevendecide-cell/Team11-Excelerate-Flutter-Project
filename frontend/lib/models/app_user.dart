class AppUser {
  final String id;
  final String email;
  final String role;
  final String? fullName;

  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.fullName,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      fullName: json['fullName'] as String?,
    );
  }
}
