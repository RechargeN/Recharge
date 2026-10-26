import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/product_analytics/product_analytics_contract.dart';

/// PA-T11 (ANALYTICS_L3_PRODUCT_ANALYTICS_AMENDMENT.md §2, §12 п.11): a client
/// producer, sink, queue store or analytics SDK that is not registered fails
/// here. The legacy console telemetry (inventory M-1/M-2) is frozen: it is
/// developer diagnostics, not product analytics, and a new name in it needs
/// an explicit inventory decision. Positive controls prove each scan fails.
const Map<String, String> _eventClasses = <String, String>{
  'DetailsOpened': 'details_opened',
  'FavoriteAdded': 'favorite_added',
  'CreatePublishFinished': 'create_publish_finished',
};
const String _contractDir = 'lib/core/product_analytics/';
const Set<String> _registeredSinks = <String>{'DisabledProductAnalyticsSink'};
const Set<String> _registeredStores = <String>{
  'InMemoryProductAnalyticsQueueStore',
};
const Set<String> _registeredLegacySinks = <String>{'ConsoleAnalyticsService'};

/// Literal names of the legacy console `AnalyticsService.track` (M-1/M-2).
const Set<String> _legacyConsoleNames = <String>{
  'app_lifecycle_changed',
  'auth_gate_viewed',
  'auth_guest_continue_clicked',
  'auth_screen_viewed',
  'auth_session_expired_shown',
  'auth_session_restore_failed',
  'auth_session_restore_started',
  'auth_session_restore_succeeded',
  'auth_sign_in_failed',
  'auth_sign_in_started',
  'auth_sign_in_succeeded',
  'auth_sign_out_failed',
  'auth_sign_out_started',
  'auth_sign_out_succeeded',
  'collection_create_action',
  'create_draft_loaded',
  'create_draft_saved',
  'create_publish_denied',
  'create_publish_failed',
  'create_publish_succeeded',
  'discover_details_calendar_exported',
  'discover_details_cta_clicked',
  'discover_details_external_cta_tapped',
  'discover_details_load_failed',
  'discover_details_load_started',
  'discover_details_viewed',
  'discover_feed_load_failed',
  'discover_feed_load_started',
  'discover_feed_loaded',
  'event_classification_additional_participation_changed',
  'event_classification_archetype_selected',
  'event_classification_cleared',
  'event_classification_primary_participation_selected',
  'explore_profile_loaded',
  'explore_profile_saved',
  'explore_settings_updated',
  'favorites_add_started',
  'favorites_add_succeeded',
  'favorites_load_failed',
  'favorites_loaded',
  'favorites_remove_started',
  'favorites_remove_succeeded',
  'identity_admin_experience_preview_selected',
  'identity_notification_append_failed',
  'identity_page_limit_request_submitted',
  'identity_professional_page_created',
  'identity_workspace_loaded',
  'identity_workspace_switched',
  'notifications_load_failed',
  'notifications_loaded',
  'notifications_mark_all_read_started',
  'notifications_mark_all_read_succeeded',
  'notifications_mark_read_started',
  'notifications_mark_read_succeeded',
  'notifications_search_changed',
  'quick_plan_expanded_to_scenario',
  'rental_sink_activation_failed',
  'route_publish_succeeded',
  'route_safety_report_submitted',
  'scenario_object_intake_action',
  'scenario_transit_action',
  'time_fit_invalid_opening_rule',
  'time_fit_relaxation_selected',
  'time_fit_result_shown',
  'time_fit_unknown_shown',
  'time_window_applied',
  'travel_estimate_failed',
  'visit_history_removed',
  'visit_history_self_reported',
  'visited_places_load_failed',
  'visited_places_loaded',
  'visited_places_period_changed',
};

/// Files whose `.track(` call takes a computed name or is a typed wrapper.
const Set<String> _legacyDynamicFiles = <String>{
  'lib/app/application/controllers/scenario_object_intake_controller.dart',
  'lib/app/observers/app_route_observer.dart',
  'lib/app/presentation/class_workshop_details_page.dart',
  'lib/app/presentation/scenario_object_intake_sheet.dart',
};

final RegExp _analyticsSdk = RegExp(
  r'^(firebase_analytics|firebase_crashlytics|google_analytics\w*|amplitude\w*|mixpanel\w*|segment\w*|posthog\w*|appsflyer\w*|adjust_sdk|branch\w*_sdk|sentry\w*|datadog\w*|new_relic\w*|flutter_branch_sdk)$',
);

List<String> inventoryGaps(Map<String, String> sources, String pubspec) {
  final List<String> gaps = <String>[];
  final Map<String, String> producerOf = <String, String>{
    for (final ProductAnalyticsDefinition definition
        in productAnalyticsEventRegistry)
      definition.eventName: definition.producer,
  };
  for (final MapEntry<String, String> file in sources.entries) {
    final String path = file.key;
    final String text = file.value;
    if (!path.startsWith(_contractDir)) {
      for (final MapEntry<String, String> event in _eventClasses.entries) {
        if (RegExp('\\b${event.key}\\(').hasMatch(text) &&
            'apps/mobile/$path' != producerOf[event.value]) {
          gaps.add('producer_unregistered:${event.value}:$path');
        }
      }
    }
    for (final Match match in RegExp(
      r'class (\w+)[^{]*implements[^{]*\b(ProductAnalyticsSink|ProductAnalyticsQueueStore|AnalyticsService)\b',
    ).allMatches(text)) {
      final String name = match.group(1)!;
      final Set<String> allowed = switch (match.group(2)) {
        'ProductAnalyticsSink' => _registeredSinks,
        'ProductAnalyticsQueueStore' => _registeredStores,
        _ => _registeredLegacySinks,
      };
      if (!allowed.contains(name)) gaps.add('sink_unregistered:$name:$path');
    }
    if (path.startsWith(_contractDir) &&
        RegExp(
          r"import 'package:(http|firebase_\w+|cloud_\w+)/|import 'dart:io'|analytics_service\.dart|\bprint\(|developer\.log",
        ).hasMatch(text)) {
      gaps.add('network_or_log_path:$path');
    }
    if (path == 'lib/core/telemetry/analytics_service.dart' &&
        RegExp(r"import '(?!dart:developer)").hasMatch(text)) {
      gaps.add('legacy_sink_widened:$path');
    }
    for (final Match match in RegExp(
      r"\.track\(\s*([^,)]+)",
    ).allMatches(text)) {
      final String argument = match.group(1)!.trim();
      final Match? literal = RegExp(r"^'([a-z0-9_]+)'$").firstMatch(argument);
      if (literal != null) {
        if (!_legacyConsoleNames.contains(literal.group(1))) {
          gaps.add('legacy_name_unregistered:${literal.group(1)}');
        }
      } else if (!_legacyDynamicFiles.contains(path)) {
        gaps.add('legacy_dynamic_unregistered:$path');
      }
    }
  }
  for (final Match match in RegExp(
    r'^  ([a-z_][a-z0-9_]*):',
    multiLine: true,
  ).allMatches(pubspec)) {
    if (_analyticsSdk.hasMatch(match.group(1)!)) {
      gaps.add('sdk_unregistered:${match.group(1)}');
    }
  }
  return (gaps.toSet().toList())..sort();
}

Map<String, String> _libSources() => <String, String>{
  for (final FileSystemEntity entity in Directory(
    'lib',
  ).listSync(recursive: true))
    if (entity is File && entity.path.endsWith('.dart'))
      entity.path.replaceAll('\\', '/'): entity.readAsStringSync(),
};

void main() {
  test('PA-T11: every producer, sink, store and dependency is registered', () {
    final Map<String, String> sources = _libSources();
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    // The scans must see the real tree, or an empty scan would pass.
    expect(sources.keys, contains('lib/core/telemetry/analytics_service.dart'));
    expect(pubspec, contains('firebase_auth'));
    expect(inventoryGaps(sources, pubspec), isEmpty);
    // Every registered producer really constructs its event.
    for (final ProductAnalyticsDefinition definition
        in productAnalyticsEventRegistry) {
      final String path = definition.producer.replaceFirst('apps/mobile/', '');
      final String className = _eventClasses.entries
          .firstWhere(
            (MapEntry<String, String> e) => e.value == definition.eventName,
          )
          .key;
      expect(
        RegExp('\\b$className\\(').hasMatch(sources[path]!),
        isTrue,
        reason: path,
      );
    }
  });

  test('PA-T11 positive controls: each unregistered path fails the scan', () {
    final Map<String, String> synthetic = <String, String>{
      'lib/features/explore/application/explore_controller.dart':
          'recorder.record(DetailsOpened(kind));',
      'lib/app/adapters/remote_analytics_sink.dart':
          'class RemoteSink implements ProductAnalyticsSink {}',
      'lib/app/adapters/file_queue.dart':
          'class FileQueue implements ProductAnalyticsQueueStore {}',
      'lib/app/adapters/firebase_analytics_service.dart':
          'class FirebaseAnalyticsService implements AnalyticsService {}',
      'lib/core/product_analytics/remote.dart':
          "import 'package:http/http.dart' as http;",
      'lib/core/telemetry/analytics_service.dart':
          "import 'dart:developer' as developer;\nimport 'package:http/http.dart';",
      'lib/features/search/application/search_controller.dart':
          "_analytics.track('search_query_entered', params: {'q': q});\n"
          '_analytics.track(name);',
    };
    expect(inventoryGaps(synthetic, 'dependencies:\n  firebase_analytics: ^11.0.0\n'), <
      String
    >[
      'legacy_dynamic_unregistered:lib/features/search/application/search_controller.dart',
      'legacy_name_unregistered:search_query_entered',
      'legacy_sink_widened:lib/core/telemetry/analytics_service.dart',
      'network_or_log_path:lib/core/product_analytics/remote.dart',
      'producer_unregistered:details_opened:lib/features/explore/application/explore_controller.dart',
      'sdk_unregistered:firebase_analytics',
      'sink_unregistered:FileQueue:lib/app/adapters/file_queue.dart',
      'sink_unregistered:FirebaseAnalyticsService:lib/app/adapters/firebase_analytics_service.dart',
      'sink_unregistered:RemoteSink:lib/app/adapters/remote_analytics_sink.dart',
    ]);
  });
}
