import '../../../../shared/primitives/errors/coded_refusal.dart';
import '../entities/route_draft_data.dart';
import '../entities/route_sync_data.dart';

class RouteSyncFailure implements CodedRefusal {
  const RouteSyncFailure(this.code);
  @override
  final String code;
  @override
  UserMessageFamily get messageFamily => UserMessageFamily.route;
  @override
  String toString() => 'RouteSyncFailure($code)';
}

/// A command the server refused; kept with its payload until the author
/// chooses `keepServer` or `reapplyLocal`. Nothing is merged automatically.
class RouteSyncConflict {
  const RouteSyncConflict({
    required this.key,
    required this.routeId,
    required this.commandType,
    required this.code,
    required this.serverRevision,
  });

  final String key;
  final String routeId;
  final String commandType;
  final String code;
  final int? serverRevision;
}

/// J1 owner-only Route sync. Every command is persisted before dispatch and
/// replayed in order; cached data is never server authority.
abstract interface class RouteSyncRepository {
  Future<void> restore();

  /// Hides every cached Route and queue entry until the next [restore].
  void clearVisible();

  /// Registers an applied GPX import as one durable import intent.
  Future<RouteSyncEntry?> importRoute({
    required String localDraftId,
    required String title,
    required RouteDraftData route,
  });

  Future<RouteSyncEntry?> save({
    required String localDraftId,
    required String title,
    required RouteDraftData route,
    required int expectedRevision,
  });

  Future<RouteSyncEntry?> setPrivacyTrim({
    required String routeId,
    required RoutePrivacyTrim trim,
    required int expectedRevision,
  });

  Future<RouteSyncEntry?> delete({
    required String routeId,
    required int expectedRevision,
  });

  Future<void> flush();

  Future<RouteSyncEntry?> refresh(String routeId);

  Future<List<RouteSyncEntry>> list();

  /// Preview and export use this exact object: one revision, one trim.
  Future<RouteTrimmedView> trimmedView(
    String routeId, {
    required int expectedRevision,
  });

  RouteSyncEntry? cached(String routeId);

  String? routeIdFor(String localDraftId);

  bool hasPending(String routeId);

  List<RouteSyncConflict> get conflicts;

  Future<void> resolveConflict(String key, {required bool reapplyLocal});

  RouteDraftData draftFrom(
    RouteSyncEntry entry, {
    required RouteDraftData template,
  });
}
