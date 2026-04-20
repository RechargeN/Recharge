import '../repositories/notifications_repository.dart';

class MarkNotificationReadUseCase {
  MarkNotificationReadUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<void> call({
    required String userId,
    required String notificationId,
  }) {
    return _repository.markNotificationRead(
      userId: userId,
      notificationId: notificationId,
    );
  }
}
