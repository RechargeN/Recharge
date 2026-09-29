import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/managed_page_entity.dart';

class PublicProfessionalPageLocalDataSource {
  const PublicProfessionalPageLocalDataSource(this._storage);

  static const int schemaVersion = 1;
  static const String _storageKey = 'identity_public_professional_pages';

  final FlutterSecureStorage _storage;

  Future<List<ManagedPageEntity>> loadPages() async {
    final String? raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return const <ManagedPageEntity>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != schemaVersion) {
        return const <ManagedPageEntity>[];
      }
      final List<dynamic> pages =
          decoded['pages'] as List<dynamic>? ?? const <dynamic>[];
      return pages
          .map((dynamic item) => _pageFromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } on FormatException {
      return const <ManagedPageEntity>[];
    } on TypeError {
      return const <ManagedPageEntity>[];
    } on StateError {
      return const <ManagedPageEntity>[];
    }
  }

  Future<void> upsertPage(ManagedPageEntity page) async {
    final List<ManagedPageEntity> current = await loadPages();
    final List<ManagedPageEntity> next = <ManagedPageEntity>[
      for (final ManagedPageEntity item in current)
        if (item.id != page.id) item,
      page,
    ];
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(<String, Object>{
        'schemaVersion': schemaVersion,
        'pages': next.map(_pageToJson).toList(growable: false),
      }),
    );
  }

  static Map<String, Object> _pageToJson(ManagedPageEntity page) {
    return <String, Object>{
      'id': page.id,
      'ownerUserId': page.ownerUserId,
      'kind': page.kind.name,
      'displayName': page.displayName,
      'slug': page.slug,
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
    final String id = json['id'] as String;
    final String displayName = json['displayName'] as String;
    return ManagedPageEntity(
      id: id,
      ownerUserId: json['ownerUserId'] as String,
      kind: _enumByName(ManagedPageKind.values, json['kind'] as String),
      displayName: displayName,
      slug: (json['slug'] as String?)?.trim().isNotEmpty ?? false
          ? (json['slug'] as String).trim()
          : ManagedPageEntity.localSlug(displayName: displayName, pageId: id),
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

  static T _enumByName<T extends Enum>(List<T> values, String name) {
    return values.firstWhere((T value) => value.name == name);
  }
}
