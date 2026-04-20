import '../entities/notification_item_entity.dart';
import '../repositories/notifications_repository.dart';

class GetNotificationsUseCase {
  GetNotificationsUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<List<NotificationItemEntity>> call({
    required String userId,
  }) {
    return _repository.getNotifications(userId: userId);
  }
}
