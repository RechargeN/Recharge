import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/managed_page_membership_entity.dart';
import '../../domain/entities/team_invitation_entity.dart';

class TeamInvitationLocalDataSource {
  const TeamInvitationLocalDataSource(this._storage);

  static const int schemaVersion = 1;

  final FlutterSecureStorage _storage;

  String _key(String pageId) => 'identity_team_invitations_$pageId';

  Future<List<TeamInvitationEntity>> loadForPage(String pageId) async {
    final String? raw = await _storage.read(key: _key(pageId));
    if (raw == null || raw.isEmpty) return const <TeamInvitationEntity>[];

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const <TeamInvitationEntity>[];
      }
      if (decoded['schemaVersion'] != schemaVersion) {
        return const <TeamInvitationEntity>[];
      }
      final List<dynamic> items =
          decoded['invitations'] as List<dynamic>? ?? const <dynamic>[];
      return items
          .map((dynamic item) => _fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } on FormatException {
      return const <TeamInvitationEntity>[];
    } on TypeError {
      return const <TeamInvitationEntity>[];
    } on StateError {
      return const <TeamInvitationEntity>[];
    }
  }

  Future<void> saveForPage(
    String pageId,
    List<TeamInvitationEntity> invitations,
  ) {
    return _storage.write(
      key: _key(pageId),
      value: jsonEncode(<String, Object>{
        'schemaVersion': schemaVersion,
        'invitations': invitations.map(_toJson).toList(growable: false),
      }),
    );
  }

  static Map<String, Object> _toJson(TeamInvitationEntity invitation) {
    return <String, Object>{
      'id': invitation.id,
      'pageId': invitation.pageId,
      'targetType': invitation.target.type.name,
      'targetValue': invitation.target.value,
      'proposedRelationship': invitation.proposedRelationship.name,
      'proposedCapabilities': invitation.proposedCapabilities.toList(
        growable: false,
      ),
      'invitedByUserId': invitation.invitedByUserId,
      'sentAtUtc': invitation.sentAtUtc.toUtc().toIso8601String(),
      'expiresAtUtc': invitation.expiresAtUtc.toUtc().toIso8601String(),
      'status': invitation.status.name,
      'resendCount': invitation.resendCount,
      if (invitation.lastResentAtUtc != null)
        'lastResentAtUtc': invitation.lastResentAtUtc!
            .toUtc()
            .toIso8601String(),
      'revision': invitation.revision,
    };
  }

  static TeamInvitationEntity _fromJson(Map<String, dynamic> json) {
    final String? lastResent = json['lastResentAtUtc'] as String?;
    return TeamInvitationEntity(
      id: json['id'] as String,
      pageId: json['pageId'] as String,
      target: TeamInvitationTarget(
        type: _enumByName(
          TeamInvitationTargetType.values,
          json['targetType'] as String,
        ),
        value: json['targetValue'] as String,
      ),
      proposedRelationship: _enumByName(
        ManagedPageRelationship.values,
        json['proposedRelationship'] as String,
      ),
      proposedCapabilities: (json['proposedCapabilities'] as List<dynamic>)
          .cast<String>()
          .toSet(),
      invitedByUserId: json['invitedByUserId'] as String,
      sentAtUtc: DateTime.parse(json['sentAtUtc'] as String).toUtc(),
      expiresAtUtc: DateTime.parse(json['expiresAtUtc'] as String).toUtc(),
      status: _enumByName(
        TeamInvitationStatus.values,
        json['status'] as String,
      ),
      resendCount: json['resendCount'] as int? ?? 0,
      lastResentAtUtc: lastResent == null
          ? null
          : DateTime.parse(lastResent).toUtc(),
      revision: json['revision'] as int,
    );
  }

  static T _enumByName<T extends Enum>(List<T> values, String name) {
    return values.firstWhere((T value) => value.name == name);
  }
}
