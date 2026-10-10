import 'package:flutter/widgets.dart';

enum AccountExperience { viewer, creator, professionalPage }

class AccountExperienceScope extends InheritedWidget {
  const AccountExperienceScope({
    super.key,
    required this.experience,
    required super.child,
  });

  final AccountExperience experience;

  static AccountExperienceScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AccountExperienceScope>();
  }

  @override
  bool updateShouldNotify(AccountExperienceScope oldWidget) {
    return experience != oldWidget.experience;
  }
}
