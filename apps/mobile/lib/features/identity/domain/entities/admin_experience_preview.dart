import '../../../../core/identity/account_experience.dart';

enum AdminExperiencePreview { viewer, creator, professionalPage }

extension AdminExperiencePreviewExperience on AdminExperiencePreview {
  AccountExperience get experience => switch (this) {
    AdminExperiencePreview.viewer => AccountExperience.viewer,
    AdminExperiencePreview.creator => AccountExperience.creator,
    AdminExperiencePreview.professionalPage =>
      AccountExperience.professionalPage,
  };
}
