class ProfileEditableEntity {
  const ProfileEditableEntity({
    required this.displayName,
    required this.about,
    required this.city,
    required this.avatar,
  });

  final String displayName;
  final String about;
  final String city;
  final String avatar;

  ProfileEditableEntity copyWith({
    String? displayName,
    String? about,
    String? city,
    String? avatar,
  }) {
    return ProfileEditableEntity(
      displayName: displayName ?? this.displayName,
      about: about ?? this.about,
      city: city ?? this.city,
      avatar: avatar ?? this.avatar,
    );
  }

  factory ProfileEditableEntity.defaults({required String email}) {
    final String name = email.split('@').first.trim();
    return ProfileEditableEntity(
      displayName: name.isEmpty ? 'User' : name,
      about: '',
      city: 'Rezekne',
      avatar: '',
    );
  }
}
