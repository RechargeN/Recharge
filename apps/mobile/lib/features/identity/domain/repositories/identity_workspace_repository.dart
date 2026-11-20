import 'dart:async';
import '../entities/identity_access_snapshot.dart';
import '../entities/managed_page_entity.dart';
import '../entities/managed_page_membership_entity.dart';
import '../entities/page_limit_increase_request_entity.dart';
import '../entities/workspace_ref.dart';

abstract class IdentityWorkspaceRepository {
  static final StreamController<String> _changes =
      StreamController<String>.broadcast(sync: true);
  static Stream<String> get accessChanges => _changes.stream;
  static void notifyAccessChanged(String userId) => _changes.add(userId);

  // One local command queue per repository. Durable writes additionally lock
  // the existing owner record, including when two repository instances share it.
  static final Expando<Future<void>> _commands = Expando<Future<void>>();
  static Future<T> runCommand<T>(
    IdentityWorkspaceRepository repository,
    Future<T> Function() command,
  ) async {
    final previous = _commands[repository] ?? Future<void>.value();
    final result = previous.then((_) => command());
    final settled = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _commands[repository] = settled;
    try {
      return await result;
    } finally {
      if (identical(_commands[repository], settled)) {
        _commands[repository] = null;
      }
    }
  }

  Future<IdentityAccessSnapshot> loadAccessSnapshot(String userId);

  Future<WorkspaceRef?> loadActiveWorkspace(String userId);

  Future<void> saveActiveWorkspace(String userId, WorkspaceRef workspace);

  Future<void> saveCreatedPage({
    required String userId,
    required ManagedPageEntity page,
    required ManagedPageMembershipEntity membership,
  });

  Future<PageLimitIncreaseRequestEntity?> loadPendingPageLimitRequest(
    String userId,
  );

  Future<void> savePageLimitRequest(PageLimitIncreaseRequestEntity request);
}
