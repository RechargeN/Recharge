import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as paths;

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';

const _getters = {
  'marketCityId',
  'timezoneId',
  'currencyCode',
  'defaultLocaleCode',
  'supportedLocaleCodes',
};

class _References extends RecursiveAstVisitor<void> {
  _References(this.result, this.references);
  final ResolvedUnitResult result;
  final List<Map<String, Object?>> references;
  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (!node.inDeclarationContext() && _getters.contains(node.name)) {
      final element = node.element;
      final parent = node.parent;
      final Expression? target = switch (parent) {
        PrefixedIdentifier(prefix: final prefix) => prefix,
        PropertyAccess(realTarget: final target) => target,
        _ => null,
      };
      final type = target?.staticType;
      final declaredOwner = element?.enclosingElement;
      final inferredOwner = type is InterfaceType ? type.element : null;
      final owner = declaredOwner?.name == 'MarketConfig'
          ? declaredOwner
          : inferredOwner;
      if (owner?.name == 'MarketConfig' &&
          (owner?.library?.uri.toString().endsWith(
                '/app/config/market_config.dart',
              ) ??
              false)) {
        references.add({
          'file': result.path,
          'line': result.lineInfo.getLocation(node.offset).lineNumber,
          'getter': node.name,
          'owner': owner!.name,
          'resolvedMember': element != null,
        });
      }
    }
    super.visitSimpleIdentifier(node);
  }
}

Future<void> main(List<String> args) async {
  final root = Directory.current.absolute.path;
  final output = File(
    args.isEmpty
        ? '$root/outputs/IDP-M2-ONMAIN-2026-11-20/CP4-market-resolved-zero.json'
        : args.first,
  );
  final canary = File(
    '$root/outputs/IDP-M2-ONMAIN-2026-11-20/market-reference-canary.dart',
  );
  canary.parent.createSync(recursive: true);
  final fake = File(
    '$root/outputs/IDP-M2-ONMAIN-2026-11-20/market-canary/app/config/market_config.dart',
  );
  fake.parent.createSync(recursive: true);
  fake.writeAsStringSync(
    "class MarketConfig { const MarketConfig(); static const riga = MarketConfig(); String get currencyCode => 'EUR'; String get timezoneId => 'UTC'; } class MarketRegistry { const MarketRegistry(); List<MarketConfig> get markets => const [MarketConfig.riga]; }",
  );
  canary.writeAsStringSync(
    "import 'market-canary/app/config/market_config.dart'; void probe() { final lv = MarketConfig.riga; final values = [lv.currencyCode, for (final MarketConfig market in const MarketRegistry().markets) market.timezoneId]; print(values); }",
  );
  final collection = AnalysisContextCollection(
    includedPaths: [
      '$root/apps/mobile',
      '$root/packages',
      '$root/tools',
      canary.path,
    ].map(paths.normalize).toList(),
  );
  Future<ResolvedUnitResult> resolve(String path) async {
    final normalized = paths.normalize(paths.absolute(path));
    final result = await collection
        .contextFor(normalized)
        .currentSession
        .getResolvedUnit(normalized);
    if (result is! ResolvedUnitResult)
      throw StateError('Could not resolve $path: $result');
    return result;
  }

  final probe = await resolve(canary.path);
  final probeRefs = <Map<String, Object?>>[];
  probe.unit.accept(_References(probe, probeRefs));
  if (probeRefs.length != 2)
    throw StateError(
      'Canary must resolve inferred lv and typed for-in market getters: $probeRefs',
    );
  final git = Process.runSync('git', ['ls-files', '--', '*.dart']);
  if (git.exitCode != 0) throw StateError('git ls-files failed');
  final names = (git.stdout as String)
      .split(RegExp(r'[\r\n]+'))
      .where((p) => p.isNotEmpty)
      .toSet();
  for (final folder in [
    'apps/mobile/lib',
    'apps/mobile/test',
    'apps/mobile/integration_test',
    'packages',
    'tools/scripts',
  ]) {
    for (final file in Directory(
      '$root/$folder',
    ).listSync(recursive: true).whereType<File>()) {
      if (file.path.endsWith('.dart') &&
          !file.path.contains(
            '${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}',
          ) &&
          !file.path.contains(
            '${Platform.pathSeparator}build${Platform.pathSeparator}',
          )) {
        names.add(
          file.absolute.path
              .substring(root.length + 1)
              .replaceAll(Platform.pathSeparator, '/'),
        );
      }
    }
  }
  final refs = <Map<String, Object?>>[];
  final unresolved = <Map<String, Object?>>[];
  var count = 0;
  final actual = names.where((p) => File('$root/$p').existsSync()).toList()
    ..sort();
  for (final name in actual) {
    if (name == 'apps/mobile/lib/app/config/market_config.dart') continue;
    try {
      final result = await resolve(File('$root/$name').absolute.path);
      result.unit.accept(_References(result, refs));
    } catch (error) {
      unresolved.add({'file': name, 'error': '$error'});
    }
    count++;
    if (count % 250 == 0)
      stdout.writeln('Resolved $count/${actual.length} Dart files');
  }
  final report = {
    'mode':
        'resolved AST, getter owner MarketConfig, declaration file excluded',
    'head': (Process.runSync('git', ['rev-parse', 'HEAD']).stdout as String)
        .trim(),
    'filesResolved': count,
    'canary': probeRefs,
    'references': refs,
    'unresolvedFiles': unresolved,
    'zeroReferencesBeforeGetterRemoval': refs.isEmpty && unresolved.isEmpty,
  };
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln(
    jsonEncode({
      'filesResolved': count,
      'canaryReferences': probeRefs.length,
      'references': refs.length,
      'unresolved': unresolved.length,
      'zeroReferencesBeforeGetterRemoval':
          report['zeroReferencesBeforeGetterRemoval'],
    }),
  );
  if (refs.isNotEmpty || unresolved.isNotEmpty) exitCode = 1;
}
