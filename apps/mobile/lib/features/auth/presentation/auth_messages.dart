import '../../../core/localization/l10n_context.dart';
import '../application/controllers/auth_controller.dart';

/// L4: an auth state code as localized text; unknown codes get the generic
/// sign-in failure and are never shown as is.
String authMessage(AppLocalizations l10n, String code) => switch (code) {
  'AUTH_INVALID_CREDENTIALS' => l10n.authErrorInvalidCredentials,
  'AUTH_TOO_MANY_ATTEMPTS' => l10n.authErrorTooManyAttempts,
  'NETWORK_UNAVAILABLE' => l10n.authErrorNetwork,
  AuthController.sessionExpiredMessage => l10n.authSessionExpired,
  _ => l10n.authErrorGeneric,
};
