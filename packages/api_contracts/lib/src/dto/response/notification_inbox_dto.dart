import '../../contracts/booking/booking_contract.dart';

/// F1: category of one server inbox record (`notifications_result.schema.json`).
enum NotificationInboxCategory {
  bookingReceipts('booking.receipts'),
  bookingChanges('booking.changes');

  const NotificationInboxCategory(this.wire);

  final String wire;
}

enum NotificationInboxStatus { unread, read, archived }

enum NotificationContentStatus {
  rendered,
  unsupportedLocale('unsupported_locale'),
  templateUnavailable('template_unavailable');

  const NotificationContentStatus([this._wire]);

  final String? _wire;

  String get wire => _wire ?? name;
}

final RegExp _notificationIdPattern = RegExp(r'^ntf_[0-9a-f]{32}$');
final RegExp _objectIdPattern = RegExp(r'^[A-Za-z0-9_.:-]{1,200}$');

/// The typed, allowlisted navigation intent of a record. Never a URL; the
/// client revalidates the target when it opens it.
class NotificationNavigationDto {
  NotificationNavigationDto({required this.eventId});

  factory NotificationNavigationDto.fromJson(Map<String, Object?> json) {
    requireExactKeys(
      json,
      allowed: const <String>{'routeKind', 'objectRef', 'routeContractVersion'},
      required: const <String>{
        'routeKind',
        'objectRef',
        'routeContractVersion',
      },
      objectName: 'navigation',
    );
    if (json['routeKind'] != 'eventDetails' ||
        json['routeContractVersion'] != 1) {
      throw const BookingContractFormatException(
        'navigation must be eventDetails v1',
      );
    }
    final Object? ref = json['objectRef'];
    if (ref is! Map) {
      throw const BookingContractFormatException(
        'navigation.objectRef must be an object',
      );
    }
    final Map<String, Object?> objectRef = ref.cast<String, Object?>();
    requireExactKeys(
      objectRef,
      allowed: const <String>{'type', 'id'},
      required: const <String>{'type', 'id'},
      objectName: 'navigation.objectRef',
    );
    final Object? id = objectRef['id'];
    if (objectRef['type'] != 'event' ||
        id is! String ||
        !_objectIdPattern.hasMatch(id)) {
      throw const BookingContractFormatException(
        'navigation.objectRef must be an event id',
      );
    }
    return NotificationNavigationDto(eventId: id);
  }

  final String eventId;
}

/// One server inbox record as `listInbox` returns it.
class NotificationInboxItemDto {
  NotificationInboxItemDto({
    required this.notificationId,
    required this.category,
    required this.status,
    required this.revision,
    required this.createdAtUtc,
    required this.occurredAtUtc,
    required this.readAtUtc,
    required this.archivedAtUtc,
    required this.templateKey,
    required this.templateRevision,
    required this.title,
    required this.body,
    required this.contentStatus,
    required this.navigation,
  });

  factory NotificationInboxItemDto.fromJson(Map<String, Object?> json) {
    const keys = <String>{
      'notificationId',
      'category',
      'status',
      'revision',
      'createdAtUtc',
      'occurredAtUtc',
      'readAtUtc',
      'archivedAtUtc',
      'template',
      'content',
      'contentStatus',
      'navigation',
    };
    requireExactKeys(json, allowed: keys, required: keys, objectName: 'item');
    final String notificationId = requireNonBlankString(
      json['notificationId'],
      'item.notificationId',
    );
    if (!_notificationIdPattern.hasMatch(notificationId)) {
      throw const BookingContractFormatException('item.notificationId invalid');
    }
    final Object? template = json['template'];
    if (template is! Map) {
      throw const BookingContractFormatException('item.template invalid');
    }
    final Map<String, Object?> templateJson = template.cast<String, Object?>();
    requireExactKeys(
      templateJson,
      allowed: const <String>{'key', 'revision'},
      required: const <String>{'key', 'revision'},
      objectName: 'item.template',
    );
    final NotificationContentStatus contentStatus = parseWireEnum(
      json['contentStatus'],
      NotificationContentStatus.values,
      field: 'item.contentStatus',
      wireValue: (NotificationContentStatus value) => value.wire,
    );
    final Object? content = json['content'];
    String? title;
    String? body;
    if (content != null) {
      if (content is! Map) {
        throw const BookingContractFormatException('item.content invalid');
      }
      final Map<String, Object?> contentJson = content.cast<String, Object?>();
      requireExactKeys(
        contentJson,
        allowed: const <String>{'title', 'body'},
        required: const <String>{'title', 'body'},
        objectName: 'item.content',
      );
      title = requireNonBlankString(contentJson['title'], 'item.content.title');
      body = requireNonBlankString(contentJson['body'], 'item.content.body');
    }
    if ((content == null) ==
        (contentStatus == NotificationContentStatus.rendered)) {
      throw const BookingContractFormatException(
        'item.content must be present exactly when rendered',
      );
    }
    final Object? navigation = json['navigation'];
    if (navigation is! Map) {
      throw const BookingContractFormatException('item.navigation invalid');
    }
    return NotificationInboxItemDto(
      notificationId: notificationId,
      category: parseWireEnum(
        json['category'],
        NotificationInboxCategory.values,
        field: 'item.category',
        wireValue: (NotificationInboxCategory value) => value.wire,
      ),
      status: parseWireEnum(
        json['status'],
        NotificationInboxStatus.values,
        field: 'item.status',
      ),
      revision: requirePositiveInt(json['revision'], 'item.revision'),
      createdAtUtc: requireUtcTimestamp(
        json['createdAtUtc'],
        'item.createdAtUtc',
      ),
      occurredAtUtc: requireUtcTimestamp(
        json['occurredAtUtc'],
        'item.occurredAtUtc',
      ),
      readAtUtc: optionalUtcTimestamp(json['readAtUtc'], 'item.readAtUtc'),
      archivedAtUtc: optionalUtcTimestamp(
        json['archivedAtUtc'],
        'item.archivedAtUtc',
      ),
      templateKey: requireNonBlankString(
        templateJson['key'],
        'item.template.key',
      ),
      templateRevision: requirePositiveInt(
        templateJson['revision'],
        'item.template.revision',
      ),
      title: title,
      body: body,
      contentStatus: contentStatus,
      navigation: NotificationNavigationDto.fromJson(
        navigation.cast<String, Object?>(),
      ),
    );
  }

  final String notificationId;
  final NotificationInboxCategory category;
  final NotificationInboxStatus status;
  final int revision;
  final DateTime createdAtUtc;
  final DateTime occurredAtUtc;
  final DateTime? readAtUtc;
  final DateTime? archivedAtUtc;
  final String templateKey;
  final int templateRevision;

  /// Server-rendered text in the requested locale; `null` when the pinned
  /// template revision has no text for it (fail closed, no fallback).
  final String? title;
  final String? body;
  final NotificationContentStatus contentStatus;
  final NotificationNavigationDto navigation;
}

/// A succeeded `listInbox` answer.
class NotificationInboxPageDto {
  NotificationInboxPageDto({
    required this.locale,
    required this.view,
    required this.items,
    required this.nextCursor,
  });

  factory NotificationInboxPageDto.fromJson(Map<String, Object?> json) {
    const keys = <String>{
      'schemaVersion',
      'queryType',
      'requestId',
      'kind',
      'locale',
      'view',
      'items',
      'nextCursor',
    };
    requireExactKeys(json, allowed: keys, required: keys, objectName: 'page');
    if (json['schemaVersion'] != 1 ||
        json['queryType'] != 'listInbox' ||
        json['kind'] != 'succeeded') {
      throw const BookingContractFormatException(
        'page must be a succeeded listInbox v1 answer',
      );
    }
    final Object? items = json['items'];
    if (items is! List || items.length > 50) {
      throw const BookingContractFormatException('page.items invalid');
    }
    final Object? view = json['view'];
    if (view != 'active' && view != 'archived') {
      throw const BookingContractFormatException('page.view invalid');
    }
    return NotificationInboxPageDto(
      locale: requireNonBlankString(json['locale'], 'page.locale'),
      view: view! as String,
      items: List<NotificationInboxItemDto>.unmodifiable(
        items.map((Object? item) {
          if (item is! Map) {
            throw const BookingContractFormatException('page.item invalid');
          }
          return NotificationInboxItemDto.fromJson(
            item.cast<String, Object?>(),
          );
        }),
      ),
      nextCursor: optionalNonBlankString(json['nextCursor'], 'page.nextCursor'),
    );
  }

  final String locale;
  final String view;
  final List<NotificationInboxItemDto> items;
  final String? nextCursor;
}
