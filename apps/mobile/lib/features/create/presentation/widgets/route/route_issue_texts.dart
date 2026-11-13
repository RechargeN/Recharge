import '../../../../../core/localization/l10n_context.dart';

/// L4: Route check codes that have their own user message.
const Set<String> _specific = <String>{
  'route_too_short',
  'route_too_long',
  'route_duration_too_long',
  'loop_must_close',
  'one_way_must_not_close',
  'out_and_back_must_return',
  'anchors_too_few',
  'segments_missing',
  'manual_duration_reason_required',
  'provider_license_disallows_publish',
  'temporary_id_not_publishable',
};

/// The message key of a stable Route check [code]: its own text when it has
/// one, else the user-level family it belongs to. Technical codes are never
/// shown; the code stays on the issue for diagnostics.
String routeIssueMessageKey(String code) {
  if (_specific.contains(code)) return code;
  if (code.startsWith('segment')) return 'family_segment';
  if (code.startsWith('waypoint')) return 'family_waypoint';
  if (code.startsWith('anchor') || code.startsWith('turning_anchor')) {
    return 'family_anchor';
  }
  if (code.startsWith('condition') || code.startsWith('surface')) {
    return 'family_condition';
  }
  if (code.contains('duration')) return 'family_duration';
  return 'family_data';
}

/// "• message — section" for one Route check, localized.
String routeIssueLine(AppLocalizations l10n, String code, String sectionId) =>
    l10n.routeIssueLine(
      l10n.routeValidationIssue(routeIssueMessageKey(code)),
      l10n.routeValidationSection(sectionId),
    );
