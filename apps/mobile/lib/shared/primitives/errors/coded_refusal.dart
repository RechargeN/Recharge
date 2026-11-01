/// L4: the contract families whose stable codes reach the UI. The server
/// families mirror the enums of `packages/api_contracts/schema`; the client
/// families are codes the mobile adapters and controllers produce themselves.
enum UserMessageFamily {
  /// `booking/v1/booking_error.schema.json#/properties/code`.
  booking,

  /// `content/v1/content_result.schema.json#/$defs/failureCode`.
  content,

  /// `media/v1/media_result.schema.json#/$defs/failureCode`.
  media,

  /// `identity/v1/publisher_eligibility.schema.json#/properties/reason`.
  publisherEligibility,

  /// `platform/v1/error.schema.json#/properties/code`.
  platform,

  /// `notifications/v1/notifications_result.schema.json` item `contentStatus`.
  notificationContent,

  /// `library/v1/library_refusal.schema.json#/$defs/refusalCode`.
  library,

  /// `quick_plan/v1/quick_plan_refusal.schema.json#/$defs/refusalCode`.
  quickPlan,

  /// `scenario/v1/scenario_refusal.schema.json#/$defs/refusalCode`.
  scenario,

  /// `route/v1/route_refusal.schema.json#/$defs/refusalCode`.
  route,

  /// `privacy/v1/privacy_intake_refusal.schema.json#/$defs/refusalCode`.
  /// The intake has no callable or client yet, so no screen shows these.
  privacyIntake,

  /// `identity/v1/identity_session_result.schema.json#/$defs/failureCode`.
  identitySession,

  /// Callable transport failures (no server answer, no Session).
  clientTransport,

  /// Refusals the client decides before any server call.
  clientLocal,
}

/// L4.8: a failure that carries a stable code of a [UserMessageFamily], so a
/// screen can say it in words without knowing the module that raised it.
abstract interface class CodedRefusal implements Exception {
  UserMessageFamily get messageFamily;
  String get code;
}
