import '../entities/route_recording_data.dart';

abstract interface class RouteRecordingJournalRepository {
  Future<RouteRecordingJournal?> loadForDraft(String draftId);

  Future<void> save(RouteRecordingJournal journal);

  Future<void> delete({required String draftId, required String sessionId});
}
