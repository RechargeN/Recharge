class AuthUserEntity {
  const AuthUserEntity({
    required this.id,
    required this.email,
    required this.role,
    required this.capabilities,
    required this.profileStatus,
  });

  final String id;
  final String email;
  final String role;
  final List<String> capabilities;
  final String profileStatus;

  bool get canWriteFavorites => capabilities.contains('favorites.write');
}
