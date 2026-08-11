import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/create_template_model.dart';

class CreateTemplateLocalDataSource {
  const CreateTemplateLocalDataSource(
    this._storage, {
    required this.activeMarketCityId,
    required this.activeTimezone,
    required this.activeCountry,
    required this.activeCity,
    required this.activeCurrency,
  });

  final FlutterSecureStorage _storage;
  final String activeMarketCityId;
  final String activeTimezone;
  final String activeCountry;
  final String activeCity;
  final String activeCurrency;

  String _key(String userId) => 'create_templates_v1_$userId';

  Future<List<CreateTemplateModel>> loadTemplates(String userId) async {
    try {
      final String? raw = await _storage.read(key: _key(userId));
      if (raw == null || raw.isEmpty) return const <CreateTemplateModel>[];
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1 ||
          decoded['templates'] is! List<dynamic>) {
        return const <CreateTemplateModel>[];
      }
      final List<CreateTemplateModel> result = <CreateTemplateModel>[];
      for (final Object? item in decoded['templates'] as List<dynamic>) {
        if (item is! Map<dynamic, dynamic>) continue;
        try {
          result.add(
            CreateTemplateModel.fromJson(
              Map<String, dynamic>.from(item),
              activeMarketCityId: activeMarketCityId,
              activeTimezone: activeTimezone,
              activeCountry: activeCountry,
              activeCity: activeCity,
              activeCurrency: activeCurrency,
            ),
          );
        } on Object {
          // One corrupt or future record must not hide valid sibling templates.
        }
      }
      return result;
    } on Object {
      return const <CreateTemplateModel>[];
    }
  }

  Future<void> saveTemplates(
    String userId,
    List<CreateTemplateModel> templates,
  ) {
    return _storage.write(
      key: _key(userId),
      value: jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'templates': templates
            .map((CreateTemplateModel item) => item.toJson())
            .toList(growable: false),
      }),
    );
  }
}
