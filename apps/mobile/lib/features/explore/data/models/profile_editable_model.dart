import '../../domain/entities/profile_editable_entity.dart';

class ProfileEditableModel {
  const ProfileEditableModel({
    required this.displayName,
    required this.about,
    required this.city,
    required this.avatar,
  });

  final String displayName;
  final String about;
  final String city;
  final String avatar;

  factory ProfileEditableModel.fromJson(Map<String, dynamic> json) {
    return ProfileEditableModel(
      displayName: json['displayName'] as String? ?? '',
      about: json['about'] as String? ?? '',
      city: json['city'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'displayName': displayName,
      'about': about,
      'city': city,
      'avatar': avatar,
    };
  }

  factory ProfileEditableModel.fromEntity(ProfileEditableEntity entity) {
    return ProfileEditableModel(
      displayName: entity.displayName,
      about: entity.about,
      city: entity.city,
      avatar: entity.avatar,
    );
  }

  ProfileEditableEntity toEntity() {
    return ProfileEditableEntity(
      displayName: displayName,
      about: about,
      city: city,
      avatar: avatar,
    );
  }
}
