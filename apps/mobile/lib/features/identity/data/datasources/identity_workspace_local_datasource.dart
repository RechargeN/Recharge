import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/managed_page_entity.dart';
import '../../domain/entities/managed_page_membership_entity.dart';
import '../../domain/entities/page_limit_increase_request_entity.dart';
import '../../domain/entities/workspace_ref.dart';

class IdentityManagedPageLocalRecord {
  const IdentityManagedPageLocalRecord({
    this.pages = const <ManagedPageEntity>[],
    this.memberships = const <ManagedPageMembershipEntity>[],
    this.limitRequests = const <PageLimitIncreaseRequestEntity>[],
  });

  final List<ManagedPageEntity> pages;
  final List<ManagedPageMembershipEntity> memberships;
  final List<PageLimitIncreaseRequestEntity> limitRequests;
}

class IdentityWorkspaceLocalDataSource {
  const IdentityWorkspaceLocalDataSource(this._storage);

  static const int schemaVersion = 1;

  final FlutterSecureStorage _storage;

  String _key(String userId) => 'identity_active_workspace_$userId';
  String _managedPagesKey(String userId) => 'identity_managed_pages_$userId';

  Future<WorkspaceRef?> loadActiveWorkspace(String userId) async {
    final String? raw = await _storage.read(key: _key(userId));
    if (raw == null || raw.isEmpty) return null;

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['schemaVersion'] != schemaVersion) return null;

      final String? typeValue = decoded['type'] as String?;
      final String? id = decoded['id'] as String?;
      if (id == null || id.trim().isEmpty) return null;

      final WorkspaceType? type = switch (typeValue) {
        'personal' => WorkspaceType.personal,
        'page' => WorkspaceType.page,
        _ => null,
      };
      if (type == null) return null;
      return WorkspaceRef(type: type, id: id);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> saveActiveWorkspace(String userId, WorkspaceRef workspace) {
    return _storage.write(
      key: _key(userId),
      value: jsonEncode(<String, Object>{
        'schemaVersion': schemaVersion,
        'type': workspace.type.name,
        'id': workspace.id,
      }),
    );
  }

  Future<IdentityManagedPageLocalRecord> loadManagedPageRecord(
    String userId,
  ) async {
    final String? raw = await _storage.read(key: _managedPagesKey(userId));
    if (raw == null || raw.isEmpty) {
      return const IdentityManagedPageLocalRecord();
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != schemaVersion) {
        return const IdentityManagedPageLocalRecord();
      }
      final List<dynamic> pageJson =
          decoded['pages'] as List<dynamic>? ?? const <dynamic>[];
      final List<dynamic> membershipJson =
          decoded['memberships'] as List<dynamic>? ?? const <dynamic>[];
      final List<dynamic> requestJson =
          decoded['limitRequests'] as List<dynamic>? ?? const <dynamic>[];
      return IdentityManagedPageLocalRecord(
        pages: pageJson
            .map((dynamic item) => _pageFromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        memberships: membershipJson
            .map(
              (dynamic item) =>
                  _membershipFromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
        limitRequests: requestJson
            .map(
              (dynamic item) => _requestFromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
      );
    } on FormatException {
      return const IdentityManagedPageLocalRecord();
    } on TypeError {
      return const IdentityManagedPageLocalRecord();
    } on StateError {
      return const IdentityManagedPageLocalRecord();
    }
  }

  Future<void> saveManagedPageRecord(
    String userId,
    IdentityManagedPageLocalRecord record,
  ) {
    return _storage.write(
      key: _managedPagesKey(userId),
      value: jsonEncode(<String, Object>{
        'schemaVersion': schemaVersion,
        'pages': record.pages.map(_pageToJson).toList(growable: false),
        'memberships': record.memberships
            .map(_membershipToJson)
            .toList(growable: false),
        'limitRequests': record.limitRequests
            .map(_requestToJson)
            .toList(growable: false),
      }),
    );
  }

  static Map<String, Object> _pageToJson(ManagedPageEntity page) {
    return <String, Object>{
      'id': page.id,
      'ownerUserId': page.ownerUserId,
      'kind': page.kind.name,
      'displayName': page.displayName,
      'avatar': page.avatar,
      'verificationStatus': page.verificationStatus.name,
      'lifecycle': page.lifecycle.name,
      'marketId': page.marketId,
      'countryCode': page.countryCode,
      'defaultLocale': page.defaultLocale,
      'timezone': page.timezone,
      'defaultCurrency': page.defaultCurrency,
      'supportedLocales': page.supportedLocales,
      'createdAtUtc': page.createdAtUtc.toUtc().toIso8601String(),
      'revision': page.revision,
    };
  }

  static ManagedPageEntity _pageFromJson(Map<String, dynamic> json) {
    return ManagedPageEntity(
      id: json['id'] as String,
      ownerUserId: json['ownerUserId'] as String,
      kind: _enumByName(ManagedPageKind.values, json['kind'] as String),
      displayName: json['displayName'] as String,
      avatar: json['avatar'] as String? ?? '',
      verificationStatus: _enumByName(
        ManagedPageVerificationStatus.values,
        json['verificationStatus'] as String,
      ),
      lifecycle: _enumByName(
        ManagedPageLifecycle.values,
        json['lifecycle'] as String,
      ),
      marketId: json['marketId'] as String,
      countryCode: json['countryCode'] as String,
      defaultLocale: json['defaultLocale'] as String,
      timezone: json['timezone'] as String,
      defaultCurrency: json['defaultCurrency'] as String,
      supportedLocales: (json['supportedLocales'] as List<dynamic>)
          .cast<String>()
          .toList(growable: false),
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toUtc(),
      revision: json['revision'] as int,
    );
  }

  static Map<String, Object> _membershipToJson(
    ManagedPageMembershipEntity membership,
  ) {
    return <String, Object>{
      'pageId': membership.pageId,
      'userId': membership.userId,
      'relationship': membership.relationship.name,
      'status': membership.status.name,
      'capabilities': membership.capabilities.toList(growable: false),
      'revision': membership.revision,
    };
  }

  static ManagedPageMembershipEntity _membershipFromJson(
    Map<String, dynamic> json,
  ) {
    return ManagedPageMembershipEntity(
      pageId: json['pageId'] as String,
      userId: json['userId'] as String,
      relationship: _enumByName(
        ManagedPageRelationship.values,
        json['relationship'] as String,
      ),
      status: _enumByName(
        ManagedPageMembershipStatus.values,
        json['status'] as String,
      ),
      capabilities: (json['capabilities'] as List<dynamic>)
          .cast<String>()
          .toSet(),
      revision: json['revision'] as int,
    );
  }

  static Map<String, Object> _requestToJson(
    PageLimitIncreaseRequestEntity request,
  ) {
    return <String, Object>{
      'id': request.id,
      'userId': request.userId,
      'currentOwnedPageCount': request.currentOwnedPageCount,
      'requestedOwnedPageLimit': request.requestedOwnedPageLimit,
      'status': request.status.name,
      'createdAtUtc': request.createdAtUtc.toUtc().toIso8601String(),
      'revision': request.revision,
    };
  }

  static PageLimitIncreaseRequestEntity _requestFromJson(
    Map<String, dynamic> json,
  ) {
    return PageLimitIncreaseRequestEntity(
      id: json['id'] as String,
      userId: json['userId'] as String,
      currentOwnedPageCount: json['currentOwnedPageCount'] as int,
      requestedOwnedPageLimit: json['requestedOwnedPageLimit'] as int,
      status: _enumByName(
        PageLimitIncreaseRequestStatus.values,
        json['status'] as String,
      ),
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toUtc(),
      revision: json['revision'] as int,
    );
  }

  static T _enumByName<T extends Enum>(List<T> values, String name) {
    return values.firstWhere((T value) => value.name == name);
  }
}
