import 'dart:convert';
import 'dart:io';

const String _toolVersion = '1.0.0';

Future<void> main(List<String> arguments) async {
  try {
    final _CliOptions options = _CliOptions.parse(arguments);
    final Directory repoRoot = Directory(options.repoRoot).absolute;
    final File policyFile = File(
      '${repoRoot.path}${Platform.pathSeparator}tools${Platform.pathSeparator}'
      'scripts${Platform.pathSeparator}boundary-policy.json',
    );
    final _BoundaryPolicy policy = _BoundaryPolicy.load(policyFile);

    if (options.selfTest) {
      _runSelfTest(repoRoot, policy);
      stdout.writeln('Boundary checker self-test passed.');
      return;
    }

    _validateRepoRoot(repoRoot, policy);
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<_Finding> findings = _scanRepository(repoRoot, policy);

    if (options.bootstrapExceptions) {
      stdout.write(
        const JsonEncoder.withIndent(
          '  ',
        ).convert(_buildBootstrapRegistry(findings, policy.exceptionBudget)),
      );
      stdout.writeln();
      return;
    }

    final File registryFile = File(
      '${repoRoot.path}${Platform.pathSeparator}tools${Platform.pathSeparator}'
      'scripts${Platform.pathSeparator}boundary-exceptions.json',
    );
    final _ExceptionRegistry registry = _ExceptionRegistry.load(registryFile);
    final _Evaluation evaluation = _evaluate(
      findings: findings,
      registry: registry,
      policy: policy,
    );
    stopwatch.stop();

    final String rendered = _render(
      format: options.format,
      policy: policy,
      evaluation: evaluation,
      scannedFileCount: evaluation.scannedFileCount,
      durationMs: stopwatch.elapsedMilliseconds,
    );

    bool outputDrift = false;
    if (options.outputPath != null) {
      final File outputFile = File(
        _resolveOutputPath(repoRoot, options.outputPath!),
      );
      if (options.checkOutput) {
        if (!outputFile.existsSync() ||
            _normalizeNewlines(outputFile.readAsStringSync()) !=
                _normalizeNewlines(rendered)) {
          stderr.writeln(
            'Generated boundary output is stale: '
            '${_repoRelative(repoRoot, outputFile.absolute.path)}',
          );
          outputDrift = true;
        }
      } else {
        outputFile.parent.createSync(recursive: true);
        outputFile.writeAsStringSync(rendered);
      }
    } else {
      stdout.write(rendered);
      if (!rendered.endsWith('\n')) stdout.writeln();
    }

    if (evaluation.hasFailures || outputDrift) {
      exitCode = 1;
    }
  } on _ToolingException catch (error) {
    stderr.writeln('Boundary checker tooling error: ${error.message}');
    exitCode = 2;
  } on Object catch (error, stackTrace) {
    stderr.writeln('Boundary checker unexpected error: $error');
    stderr.writeln(stackTrace);
    exitCode = 2;
  }
}

class _CliOptions {
  const _CliOptions({
    required this.repoRoot,
    required this.format,
    required this.selfTest,
    required this.bootstrapExceptions,
    required this.checkOutput,
    this.outputPath,
  });

  final String repoRoot;
  final String format;
  final bool selfTest;
  final bool bootstrapExceptions;
  final bool checkOutput;
  final String? outputPath;

  static _CliOptions parse(List<String> arguments) {
    String repoRoot = '.';
    String format = 'text';
    String? outputPath;
    bool selfTest = false;
    bool bootstrapExceptions = false;
    bool checkOutput = false;

    for (int index = 0; index < arguments.length; index += 1) {
      final String argument = arguments[index];
      switch (argument) {
        case '--repo-root':
          repoRoot = _requiredValue(arguments, ++index, argument);
        case '--format':
          format = _requiredValue(arguments, ++index, argument);
        case '--output':
          outputPath = _requiredValue(arguments, ++index, argument);
        case '--self-test':
          selfTest = true;
        case '--bootstrap-exceptions':
          bootstrapExceptions = true;
        case '--check-output':
          checkOutput = true;
        case '--help':
        case '-h':
          stdout.writeln(
            'Usage: dart tools/scripts/check_boundaries.dart '
            '[--repo-root .] [--format text|json|markdown] '
            '[--output path] [--check-output] [--self-test] '
            '[--bootstrap-exceptions]',
          );
          exit(0);
        default:
          throw _ToolingException('Unknown argument: $argument');
      }
    }

    if (!const <String>{'text', 'json', 'markdown'}.contains(format)) {
      throw _ToolingException('Unsupported format: $format');
    }
    if (checkOutput && outputPath == null) {
      throw _ToolingException('--check-output requires --output.');
    }
    if (selfTest && bootstrapExceptions) {
      throw _ToolingException(
        '--self-test and --bootstrap-exceptions are mutually exclusive.',
      );
    }

    return _CliOptions(
      repoRoot: repoRoot,
      format: format,
      selfTest: selfTest,
      bootstrapExceptions: bootstrapExceptions,
      checkOutput: checkOutput,
      outputPath: outputPath,
    );
  }

  static String _requiredValue(
    List<String> arguments,
    int index,
    String option,
  ) {
    if (index >= arguments.length) {
      throw _ToolingException('$option requires a value.');
    }
    return arguments[index];
  }
}

class _BoundaryPolicy {
  const _BoundaryPolicy({
    required this.schemaVersion,
    required this.policyVersion,
    required this.sourceRoots,
    required this.packageRoots,
    required this.knownLayers,
    required this.excludedGeneratedRoots,
    required this.excludedFileSuffixes,
    required this.frameworkPackages,
    required this.blockingRules,
    required this.exceptionBudget,
  });

  final int schemaVersion;
  final String policyVersion;
  final List<String> sourceRoots;
  final Map<String, String> packageRoots;
  final Set<String> knownLayers;
  final List<String> excludedGeneratedRoots;
  final List<String> excludedFileSuffixes;
  final Set<String> frameworkPackages;
  final Set<String> blockingRules;
  final int exceptionBudget;

  static _BoundaryPolicy load(File file) {
    final Map<String, Object?> json = _readJsonObject(file);
    final int schemaVersion = _requiredInt(json, 'schemaVersion');
    if (schemaVersion != 1) {
      throw _ToolingException(
        'Unsupported boundary policy schemaVersion: $schemaVersion',
      );
    }
    final Set<String> blockingRules = _requiredStringList(
      json,
      'blockingRules',
    ).toSet();
    const Set<String> supportedRules = <String>{
      'cross_feature_import',
      'domain_to_non_domain_layer',
      'application_to_data_or_presentation',
      'data_to_application_or_presentation',
      'presentation_to_data',
      'domain_framework_dependency',
      'domain_infrastructure_dependency',
      'feature_to_app_di_or_app_presentation',
    };
    final Set<String> unknownRules = blockingRules.difference(supportedRules);
    if (unknownRules.isNotEmpty) {
      throw _ToolingException(
        'Unsupported blocking rules: ${unknownRules.join(', ')}',
      );
    }

    final Object? packageRootsRaw = json['packageRoots'];
    if (packageRootsRaw is! Map<String, dynamic>) {
      throw _ToolingException('packageRoots must be a JSON object.');
    }
    final Map<String, String> packageRoots = <String, String>{};
    for (final MapEntry<String, dynamic> entry in packageRootsRaw.entries) {
      if (entry.value is! String || (entry.value as String).isEmpty) {
        throw _ToolingException('Invalid package root for ${entry.key}.');
      }
      packageRoots[entry.key] = _normalizePath(entry.value as String);
    }

    return _BoundaryPolicy(
      schemaVersion: schemaVersion,
      policyVersion: _requiredString(json, 'policyVersion'),
      sourceRoots: _requiredStringList(
        json,
        'sourceRoots',
      ).map(_normalizePath).toList(growable: false),
      packageRoots: packageRoots,
      knownLayers: _requiredStringList(json, 'knownLayers').toSet(),
      excludedGeneratedRoots: _requiredStringList(
        json,
        'excludedGeneratedRoots',
      ).map(_normalizePath).toList(growable: false),
      excludedFileSuffixes: _requiredStringList(json, 'excludedFileSuffixes'),
      frameworkPackages: _requiredStringList(json, 'frameworkPackages').toSet(),
      blockingRules: blockingRules,
      exceptionBudget: _requiredInt(json, 'exceptionBudget'),
    );
  }
}

class _ExceptionRegistry {
  const _ExceptionRegistry({
    required this.schemaVersion,
    required this.baselineBudget,
    required this.exceptions,
  });

  final int schemaVersion;
  final int baselineBudget;
  final List<_BoundaryException> exceptions;

  static _ExceptionRegistry load(File file) {
    final Map<String, Object?> json = _readJsonObject(file);
    final int schemaVersion = _requiredInt(json, 'schemaVersion');
    if (schemaVersion != 1) {
      throw _ToolingException(
        'Unsupported exception registry schemaVersion: $schemaVersion',
      );
    }
    final Object? rawExceptions = json['exceptions'];
    if (rawExceptions is! List<Object?>) {
      throw _ToolingException('exceptions must be a JSON array.');
    }
    final List<_BoundaryException> exceptions = rawExceptions
        .map((Object? value) {
          if (value is! Map<String, dynamic>) {
            throw _ToolingException('Each exception must be a JSON object.');
          }
          return _BoundaryException.fromJson(value);
        })
        .toList(growable: false);
    _validateExceptions(exceptions);
    return _ExceptionRegistry(
      schemaVersion: schemaVersion,
      baselineBudget: _requiredInt(json, 'baselineBudget'),
      exceptions: exceptions,
    );
  }
}

class _BoundaryException {
  const _BoundaryException({
    required this.id,
    required this.rule,
    required this.source,
    required this.target,
    required this.owner,
    required this.reason,
    required this.introducedBefore,
    required this.targetSlice,
    required this.expiresOn,
    required this.expiryRationale,
    required this.fingerprint,
  });

  final String id;
  final String rule;
  final String source;
  final String target;
  final String owner;
  final String reason;
  final String introducedBefore;
  final String targetSlice;
  final DateTime? expiresOn;
  final String expiryRationale;
  final String fingerprint;

  factory _BoundaryException.fromJson(Map<String, dynamic> json) {
    final String rule = _requiredString(json, 'rule');
    final String source = _normalizePath(_requiredString(json, 'source'));
    final String target = _normalizeTarget(_requiredString(json, 'target'));
    final String fingerprint = _requiredString(json, 'fingerprint');
    final String expectedFingerprint = _fingerprint(rule, source, target);
    if (fingerprint != expectedFingerprint) {
      throw _ToolingException(
        'Exception ${json['id']} has fingerprint $fingerprint; '
        'expected $expectedFingerprint.',
      );
    }
    final Object? expiresRaw = json['expiresOn'];
    DateTime? expiresOn;
    if (expiresRaw != null) {
      if (expiresRaw is! String) {
        throw _ToolingException('expiresOn must be an ISO date or null.');
      }
      expiresOn = DateTime.tryParse(expiresRaw);
      if (expiresOn == null) {
        throw _ToolingException('Invalid expiresOn date: $expiresRaw');
      }
    }
    final String expiryRationale = _requiredString(json, 'expiryRationale');
    if (expiresOn == null && expiryRationale.isEmpty) {
      throw _ToolingException(
        'A null expiresOn requires a non-empty expiryRationale.',
      );
    }
    return _BoundaryException(
      id: _requiredString(json, 'id'),
      rule: rule,
      source: source,
      target: target,
      owner: _requiredString(json, 'owner'),
      reason: _requiredString(json, 'reason'),
      introducedBefore: _requiredString(json, 'introducedBefore'),
      targetSlice: _requiredString(json, 'targetSlice'),
      expiresOn: expiresOn,
      expiryRationale: expiryRationale,
      fingerprint: fingerprint,
    );
  }
}

class _DirectiveUri {
  const _DirectiveUri(this.uri, this.line);

  final String uri;
  final int line;
}

class _SourceMeta {
  const _SourceMeta({required this.feature, required this.layer});

  final String? feature;
  final String? layer;
}

class _Finding {
  const _Finding({
    required this.rule,
    required this.source,
    required this.target,
    required this.importUri,
    required this.line,
  });

  final String rule;
  final String source;
  final String target;
  final String importUri;
  final int line;

  String get fingerprint => _fingerprint(rule, source, target);

  Map<String, Object> toJson() => <String, Object>{
    'rule': rule,
    'source': source,
    'target': target,
    'importUri': importUri,
    'line': line,
    'fingerprint': fingerprint,
  };
}

class _Evaluation {
  const _Evaluation({
    required this.findings,
    required this.violations,
    required this.suppressed,
    required this.stale,
    required this.expired,
    required this.budgetExceeded,
    required this.scannedFileCount,
  });

  final List<_Finding> findings;
  final List<_Finding> violations;
  final List<_Finding> suppressed;
  final List<_BoundaryException> stale;
  final List<_BoundaryException> expired;
  final bool budgetExceeded;
  final int scannedFileCount;

  bool get hasFailures =>
      violations.isNotEmpty ||
      stale.isNotEmpty ||
      expired.isNotEmpty ||
      budgetExceeded;
}

class _ScanOutput {
  const _ScanOutput(this.findings, this.fileCount);

  final List<_Finding> findings;
  final int fileCount;
}

class _ToolingException implements Exception {
  const _ToolingException(this.message);

  final String message;
}

void _validateRepoRoot(Directory repoRoot, _BoundaryPolicy policy) {
  final File marker = File(
    '${repoRoot.path}${Platform.pathSeparator}melos.yaml',
  );
  if (!marker.existsSync()) {
    throw _ToolingException(
      'Invalid repo root ${repoRoot.path}: melos.yaml is missing.',
    );
  }
  for (final String root in policy.sourceRoots) {
    final Directory directory = Directory(_absoluteFromRepo(repoRoot, root));
    if (!directory.existsSync()) {
      throw _ToolingException('Required source root is missing: $root');
    }
  }
}

List<_Finding> _scanRepository(Directory repoRoot, _BoundaryPolicy policy) {
  return _scanRepositoryWithCount(repoRoot, policy).findings;
}

_ScanOutput _scanRepositoryWithCount(
  Directory repoRoot,
  _BoundaryPolicy policy,
) {
  final List<_Finding> findings = <_Finding>[];
  int fileCount = 0;
  for (final String sourceRoot in policy.sourceRoots) {
    final Directory directory = Directory(
      _absoluteFromRepo(repoRoot, sourceRoot),
    );
    final List<File> files =
        directory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((File file) => file.path.endsWith('.dart'))
            .toList(growable: false)
          ..sort((File left, File right) => left.path.compareTo(right.path));
    for (final File file in files) {
      final String sourcePath = _repoRelative(repoRoot, file.absolute.path);
      if (_isExcluded(sourcePath, policy)) continue;
      fileCount += 1;
      findings.addAll(
        _scanSource(
          source: file.readAsStringSync(),
          sourcePath: sourcePath,
          repoRoot: repoRoot,
          policy: policy,
        ),
      );
    }
  }
  findings.sort(_compareFindings);
  _lastScannedFileCount = fileCount;
  return _ScanOutput(findings, fileCount);
}

int _lastScannedFileCount = 0;

List<_Finding> _scanSource({
  required String source,
  required String sourcePath,
  required Directory repoRoot,
  required _BoundaryPolicy policy,
}) {
  final List<_Finding> findings = <_Finding>[];
  final _SourceMeta sourceMeta = _sourceMeta(sourcePath, policy.knownLayers);
  for (final _DirectiveUri directive in _scanDirectiveUris(source)) {
    final String uri = directive.uri;
    if (uri.startsWith('dart:')) continue;
    final String? localTarget = _resolveLocalTarget(
      repoRoot: repoRoot,
      sourcePath: sourcePath,
      uri: uri,
      packageRoots: policy.packageRoots,
    );
    final _SourceMeta? targetMeta = localTarget == null
        ? null
        : _sourceMeta(localTarget, policy.knownLayers);

    String? rule;
    if (sourceMeta.feature != null &&
        targetMeta?.feature != null &&
        sourceMeta.feature != targetMeta!.feature) {
      rule = 'cross_feature_import';
    } else if (sourceMeta.feature != null &&
        sourceMeta.feature == targetMeta?.feature) {
      rule = _forbiddenLayerRule(sourceMeta.layer, targetMeta?.layer);
    }

    if (rule == null &&
        sourceMeta.layer == 'domain' &&
        _isFrameworkPackage(uri, policy.frameworkPackages)) {
      rule = 'domain_framework_dependency';
    }
    if (rule == null &&
        sourceMeta.layer == 'domain' &&
        localTarget != null &&
        localTarget.startsWith('apps/mobile/lib/core/')) {
      rule = 'domain_infrastructure_dependency';
    }
    if (rule == null &&
        sourceMeta.feature != null &&
        localTarget != null &&
        (localTarget.startsWith('apps/mobile/lib/app/di/') ||
            localTarget.startsWith('apps/mobile/lib/app/presentation/'))) {
      rule = 'feature_to_app_di_or_app_presentation';
    }

    if (rule != null && policy.blockingRules.contains(rule)) {
      findings.add(
        _Finding(
          rule: rule,
          source: _normalizePath(sourcePath),
          target: _normalizeTarget(localTarget ?? uri),
          importUri: uri,
          line: directive.line,
        ),
      );
    }
  }
  return findings;
}

String? _forbiddenLayerRule(String? fromLayer, String? toLayer) {
  if (fromLayer == null || toLayer == null) return null;
  switch (fromLayer) {
    case 'domain':
      return toLayer == 'domain' ? null : 'domain_to_non_domain_layer';
    case 'application':
      return const <String>{'data', 'presentation'}.contains(toLayer)
          ? 'application_to_data_or_presentation'
          : null;
    case 'data':
      return const <String>{'application', 'presentation'}.contains(toLayer)
          ? 'data_to_application_or_presentation'
          : null;
    case 'presentation':
      return toLayer == 'data' ? 'presentation_to_data' : null;
  }
  return null;
}

_SourceMeta _sourceMeta(String path, Set<String> knownLayers) {
  final List<String> parts = _normalizePath(path).split('/');
  final int featureIndex = parts.indexOf('features');
  if (featureIndex < 0 || featureIndex + 1 >= parts.length) {
    return const _SourceMeta(feature: null, layer: null);
  }
  final String feature = parts[featureIndex + 1];
  String? layer;
  if (featureIndex + 2 < parts.length &&
      knownLayers.contains(parts[featureIndex + 2])) {
    layer = parts[featureIndex + 2];
  }
  return _SourceMeta(feature: feature, layer: layer);
}

String? _resolveLocalTarget({
  required Directory repoRoot,
  required String sourcePath,
  required String uri,
  required Map<String, String> packageRoots,
}) {
  if (uri.startsWith('package:')) {
    final String rest = uri.substring('package:'.length);
    final int slash = rest.indexOf('/');
    if (slash <= 0) return null;
    final String packageName = rest.substring(0, slash);
    final String? packageRoot = packageRoots[packageName];
    if (packageRoot == null) return null;
    return _normalizePath('$packageRoot/${rest.substring(slash + 1)}');
  }
  if (uri.contains(':')) return null;
  final File sourceFile = File(_absoluteFromRepo(repoRoot, sourcePath));
  final File targetFile = File(
    '${sourceFile.parent.path}${Platform.pathSeparator}'
    '${uri.replaceAll('/', Platform.pathSeparator)}',
  ).absolute;
  return _repoRelative(repoRoot, targetFile.path);
}

bool _isFrameworkPackage(String uri, Set<String> frameworkPackages) {
  if (!uri.startsWith('package:')) return false;
  final String rest = uri.substring('package:'.length);
  final String packageName = rest.split('/').first;
  return frameworkPackages.contains(packageName);
}

bool _isExcluded(String path, _BoundaryPolicy policy) {
  final String normalized = _normalizePath(path);
  if (policy.excludedGeneratedRoots.any(
    (String root) => normalized == root || normalized.startsWith('$root/'),
  )) {
    return true;
  }
  return policy.excludedFileSuffixes.any(normalized.endsWith);
}

List<_DirectiveUri> _scanDirectiveUris(String source) {
  final List<_DirectiveUri> result = <_DirectiveUri>[];
  int index = 0;
  int line = 1;
  while (index < source.length) {
    final _Cursor skipped = _skipWhitespaceAndComments(source, index, line);
    index = skipped.index;
    line = skipped.line;
    if (index >= source.length) break;

    final bool rawString =
        source[index] == 'r' &&
        index + 1 < source.length &&
        _isQuote(source[index + 1]);
    if (_isQuote(source[index]) || rawString) {
      final _StringToken token = _readString(
        source,
        rawString ? index + 1 : index,
        line,
        raw: rawString,
      );
      index = token.end;
      line = token.endLine;
      continue;
    }

    if (_isIdentifierStart(source.codeUnitAt(index))) {
      final int start = index;
      index += 1;
      while (index < source.length &&
          _isIdentifierPart(source.codeUnitAt(index))) {
        index += 1;
      }
      final String identifier = source.substring(start, index);
      if (identifier == 'import' || identifier == 'export') {
        final int directiveLine = line;
        while (index < source.length) {
          final _Cursor bodySkipped = _skipWhitespaceAndComments(
            source,
            index,
            line,
          );
          index = bodySkipped.index;
          line = bodySkipped.line;
          if (index >= source.length) {
            throw _ToolingException(
              'Unterminated $identifier directive at line $directiveLine.',
            );
          }
          if (source[index] == ';') {
            index += 1;
            break;
          }
          final bool bodyRaw =
              source[index] == 'r' &&
              index + 1 < source.length &&
              _isQuote(source[index + 1]);
          if (_isQuote(source[index]) || bodyRaw) {
            final _StringToken token = _readString(
              source,
              bodyRaw ? index + 1 : index,
              line,
              raw: bodyRaw,
            );
            result.add(_DirectiveUri(token.value, directiveLine));
            index = token.end;
            line = token.endLine;
            continue;
          }
          if (source[index] == '\n') line += 1;
          index += 1;
        }
      }
      continue;
    }
    if (source[index] == '\n') line += 1;
    index += 1;
  }
  return result;
}

class _Cursor {
  const _Cursor(this.index, this.line);

  final int index;
  final int line;
}

class _StringToken {
  const _StringToken({
    required this.value,
    required this.end,
    required this.endLine,
  });

  final String value;
  final int end;
  final int endLine;
}

_Cursor _skipWhitespaceAndComments(String source, int index, int line) {
  while (index < source.length) {
    final int code = source.codeUnitAt(index);
    if (_isWhitespace(code)) {
      if (code == 10) line += 1;
      index += 1;
      continue;
    }
    if (source.startsWith('//', index)) {
      index += 2;
      while (index < source.length && source.codeUnitAt(index) != 10) {
        index += 1;
      }
      continue;
    }
    if (source.startsWith('/*', index)) {
      int depth = 1;
      index += 2;
      while (index < source.length && depth > 0) {
        if (source.startsWith('/*', index)) {
          depth += 1;
          index += 2;
        } else if (source.startsWith('*/', index)) {
          depth -= 1;
          index += 2;
        } else {
          if (source.codeUnitAt(index) == 10) line += 1;
          index += 1;
        }
      }
      if (depth != 0) {
        throw const _ToolingException('Unterminated block comment.');
      }
      continue;
    }
    break;
  }
  return _Cursor(index, line);
}

_StringToken _readString(
  String source,
  int quoteIndex,
  int line, {
  required bool raw,
}) {
  final String quote = source[quoteIndex];
  final bool triple =
      quoteIndex + 2 < source.length &&
      source[quoteIndex + 1] == quote &&
      source[quoteIndex + 2] == quote;
  final int delimiterLength = triple ? 3 : 1;
  final int contentStart = quoteIndex + delimiterLength;
  int index = contentStart;
  final StringBuffer value = StringBuffer();
  while (index < source.length) {
    if (triple &&
        index + 2 < source.length &&
        source[index] == quote &&
        source[index + 1] == quote &&
        source[index + 2] == quote) {
      return _StringToken(
        value: value.toString(),
        end: index + 3,
        endLine: line,
      );
    }
    if (!triple && source[index] == quote) {
      return _StringToken(
        value: value.toString(),
        end: index + 1,
        endLine: line,
      );
    }
    if (!raw && source[index] == '\\' && index + 1 < source.length) {
      value.write(source[index + 1]);
      index += 2;
      continue;
    }
    if (source[index] == '\n') {
      line += 1;
      if (!triple) {
        throw const _ToolingException('Unterminated single-line string.');
      }
    }
    value.write(source[index]);
    index += 1;
  }
  throw const _ToolingException('Unterminated string literal.');
}

bool _isQuote(String value) => value == "'" || value == '"';

bool _isWhitespace(int code) =>
    code == 9 || code == 10 || code == 13 || code == 32;

bool _isIdentifierStart(int code) =>
    (code >= 65 && code <= 90) ||
    (code >= 97 && code <= 122) ||
    code == 95 ||
    code == 36;

bool _isIdentifierPart(int code) =>
    _isIdentifierStart(code) || (code >= 48 && code <= 57);

_Evaluation _evaluate({
  required List<_Finding> findings,
  required _ExceptionRegistry registry,
  required _BoundaryPolicy policy,
}) {
  if (registry.baselineBudget != policy.exceptionBudget) {
    throw _ToolingException(
      'Registry baselineBudget ${registry.baselineBudget} does not match '
      'policy exceptionBudget ${policy.exceptionBudget}.',
    );
  }
  final Map<String, _BoundaryException> byFingerprint =
      <String, _BoundaryException>{
        for (final _BoundaryException exception in registry.exceptions)
          exception.fingerprint: exception,
      };
  final Set<String> activeFingerprints = findings
      .map((finding) => finding.fingerprint)
      .toSet();
  final DateTime today = DateTime.now().toUtc();
  final List<_BoundaryException> expired = registry.exceptions
      .where(
        (_BoundaryException exception) =>
            exception.expiresOn != null &&
            exception.expiresOn!.isBefore(
              DateTime.utc(today.year, today.month, today.day),
            ),
      )
      .toList(growable: false);
  final Set<String> expiredFingerprints = expired
      .map((exception) => exception.fingerprint)
      .toSet();
  final List<_Finding> suppressed = findings
      .where(
        (_Finding finding) =>
            byFingerprint.containsKey(finding.fingerprint) &&
            !expiredFingerprints.contains(finding.fingerprint),
      )
      .toList(growable: false);
  final Set<String> suppressedFingerprints = suppressed
      .map((finding) => finding.fingerprint)
      .toSet();
  final List<_Finding> violations = findings
      .where(
        (_Finding finding) =>
            !suppressedFingerprints.contains(finding.fingerprint),
      )
      .toList(growable: false);
  final List<_BoundaryException> stale = registry.exceptions
      .where(
        (_BoundaryException exception) =>
            !activeFingerprints.contains(exception.fingerprint),
      )
      .toList(growable: false);
  return _Evaluation(
    findings: findings,
    violations: violations,
    suppressed: suppressed,
    stale: stale,
    expired: expired,
    budgetExceeded: registry.exceptions.length > policy.exceptionBudget,
    scannedFileCount: _lastScannedFileCount,
  );
}

String _render({
  required String format,
  required _BoundaryPolicy policy,
  required _Evaluation evaluation,
  required int scannedFileCount,
  required int durationMs,
}) {
  switch (format) {
    case 'json':
      return '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{'schemaVersion': 1, 'toolVersion': _toolVersion, 'policyVersion': policy.policyVersion, 'scannedFileCount': scannedFileCount, 'findingCount': evaluation.findings.length, 'violationCount': evaluation.violations.length, 'suppressedCount': evaluation.suppressed.length, 'staleExceptionCount': evaluation.stale.length, 'expiredExceptionCount': evaluation.expired.length, 'exceptionBudget': policy.exceptionBudget, 'budgetExceeded': evaluation.budgetExceeded, 'durationMs': durationMs, 'violations': evaluation.violations.map((finding) => finding.toJson()).toList(), 'suppressed': evaluation.suppressed.map((finding) => finding.toJson()).toList(), 'staleExceptions': evaluation.stale.map((exception) => exception.id).toList(), 'expiredExceptions': evaluation.expired.map((exception) => exception.id).toList()})}\n';
    case 'markdown':
      return _renderMarkdown(policy, evaluation, scannedFileCount);
    case 'text':
      return _renderText(policy, evaluation, scannedFileCount);
  }
  throw _ToolingException('Unsupported format: $format');
}

String _renderText(
  _BoundaryPolicy policy,
  _Evaluation evaluation,
  int scannedFileCount,
) {
  final StringBuffer buffer = StringBuffer()
    ..writeln('Boundary checker v$_toolVersion')
    ..writeln('Policy: ${policy.policyVersion}')
    ..writeln('Scanned Dart files: $scannedFileCount')
    ..writeln('Findings: ${evaluation.findings.length}')
    ..writeln('Suppressed: ${evaluation.suppressed.length}')
    ..writeln('Violations: ${evaluation.violations.length}')
    ..writeln('Stale exceptions: ${evaluation.stale.length}')
    ..writeln('Expired exceptions: ${evaluation.expired.length}')
    ..writeln(
      'Exception budget: ${evaluation.suppressed.length}/'
      '${policy.exceptionBudget}',
    );
  for (final _Finding finding in evaluation.violations) {
    buffer.writeln(
      'VIOLATION ${finding.rule}: ${finding.source}:${finding.line} '
      '-> ${finding.target}',
    );
  }
  for (final _BoundaryException exception in evaluation.stale) {
    buffer.writeln('STALE ${exception.id}: ${exception.fingerprint}');
  }
  for (final _BoundaryException exception in evaluation.expired) {
    buffer.writeln('EXPIRED ${exception.id}: ${exception.fingerprint}');
  }
  buffer.writeln(
    evaluation.hasFailures
        ? 'Boundary checks failed.'
        : 'Boundary checks passed.',
  );
  return buffer.toString();
}

String _renderMarkdown(
  _BoundaryPolicy policy,
  _Evaluation evaluation,
  int scannedFileCount,
) {
  final Map<String, int> byRule = <String, int>{};
  final Map<String, int> bySourceFeature = <String, int>{};
  final Map<String, int> byTargetFeature = <String, int>{};
  final Map<String, int> byPair = <String, int>{};
  for (final _Finding finding in evaluation.suppressed) {
    byRule.update(finding.rule, (int value) => value + 1, ifAbsent: () => 1);
    final String sourceFeature =
        _featureFromPath(finding.source) ?? 'non-feature';
    final String targetFeature =
        _featureFromPath(finding.target) ?? _targetGroup(finding.target);
    bySourceFeature.update(
      sourceFeature,
      (int value) => value + 1,
      ifAbsent: () => 1,
    );
    byTargetFeature.update(
      targetFeature,
      (int value) => value + 1,
      ifAbsent: () => 1,
    );
    byPair.update(
      '$sourceFeature → $targetFeature',
      (int value) => value + 1,
      ifAbsent: () => 1,
    );
  }
  final StringBuffer buffer = StringBuffer()
    ..writeln('# Mobile Boundary Inventory')
    ..writeln()
    ..writeln(
      '> Generator-owned by `tools/scripts/check_boundaries.dart`. Do not edit manually.',
    )
    ..writeln()
    ..writeln('- Tool version: `$_toolVersion`')
    ..writeln('- Policy version: `${policy.policyVersion}`')
    ..writeln('- Scanned Dart files: $scannedFileCount')
    ..writeln('- Active exceptions: ${evaluation.suppressed.length}')
    ..writeln('- Exception budget: ${policy.exceptionBudget}')
    ..writeln('- Unsuppressed violations: ${evaluation.violations.length}')
    ..writeln('- Stale exceptions: ${evaluation.stale.length}')
    ..writeln('- Expired exceptions: ${evaluation.expired.length}')
    ..writeln()
    ..writeln('## By rule')
    ..writeln()
    ..write(_markdownCountTable(byRule, 'Rule'))
    ..writeln()
    ..writeln('## By source feature')
    ..writeln()
    ..write(_markdownCountTable(bySourceFeature, 'Source'))
    ..writeln()
    ..writeln('## By target group')
    ..writeln()
    ..write(_markdownCountTable(byTargetFeature, 'Target'))
    ..writeln()
    ..writeln('## By pair')
    ..writeln()
    ..write(_markdownCountTable(byPair, 'Pair'));
  return buffer.toString();
}

String _markdownCountTable(Map<String, int> counts, String label) {
  final List<MapEntry<String, int>> entries = counts.entries.toList()
    ..sort((left, right) {
      final int byCount = right.value.compareTo(left.value);
      return byCount != 0 ? byCount : left.key.compareTo(right.key);
    });
  final StringBuffer buffer = StringBuffer()
    ..writeln('| $label | Count |')
    ..writeln('|---|---:|');
  for (final MapEntry<String, int> entry in entries) {
    buffer.writeln('| `${entry.key}` | ${entry.value} |');
  }
  return buffer.toString();
}

Map<String, Object> _buildBootstrapRegistry(
  List<_Finding> findings,
  int budget,
) {
  if (findings.length > budget) {
    throw _ToolingException(
      'Cannot bootstrap ${findings.length} findings with budget $budget.',
    );
  }
  return <String, Object>{
    'schemaVersion': 1,
    'baselineBudget': budget,
    'exceptions': <Map<String, Object?>>[
      for (int index = 0; index < findings.length; index += 1)
        _bootstrapException(findings[index], index + 1),
    ],
  };
}

Map<String, Object?> _bootstrapException(_Finding finding, int sequence) {
  final String sourceFeature =
      _featureFromPath(finding.source) ?? 'architecture';
  final String targetFeature =
      _featureFromPath(finding.target) ?? _targetGroup(finding.target);
  final String targetSlice;
  final String reason;
  switch (finding.rule) {
    case 'cross_feature_import':
      targetSlice =
          'BND-REM-${sourceFeature.toUpperCase()}-${targetFeature.toUpperCase()}';
      reason = 'Legacy direct cross-feature import pending facade migration.';
    case 'domain_infrastructure_dependency':
      targetSlice = 'MOB-ARCH-M2-PRIMITIVES';
      reason =
          'Legacy domain dependency pending primitive/port reconciliation.';
    case 'feature_to_app_di_or_app_presentation':
      targetSlice = 'MOB-ARCH-M3-COMPOSITION';
      reason = 'Legacy composition leak pending provider/facade migration.';
    default:
      targetSlice = 'MOB-ARCH-M1-REMEDIATION';
      reason = 'Legacy boundary debt pending an approved remediation slice.';
  }
  return <String, Object?>{
    'id': 'BND-LEGACY-${sequence.toString().padLeft(4, '0')}',
    'rule': finding.rule,
    'source': finding.source,
    'target': finding.target,
    'owner': '$sourceFeature-feature',
    'reason': reason,
    'introducedBefore': '2026-08-10',
    'targetSlice': targetSlice,
    'expiresOn': null,
    'expiryRationale':
        'No removal date accepted; registry budget cannot increase.',
    'fingerprint': finding.fingerprint,
  };
}

void _runSelfTest(Directory repoRoot, _BoundaryPolicy policy) {
  final File manifestFile = File(
    '${repoRoot.path}${Platform.pathSeparator}tools${Platform.pathSeparator}'
    'scripts${Platform.pathSeparator}boundary_fixtures'
    '${Platform.pathSeparator}manifest.json',
  );
  final Map<String, Object?> manifest = _readJsonObject(manifestFile);
  if (_requiredInt(manifest, 'schemaVersion') != 1) {
    throw const _ToolingException('Unsupported fixture manifest schema.');
  }
  final Object? casesRaw = manifest['cases'];
  if (casesRaw is! List<Object?>) {
    throw const _ToolingException('Fixture cases must be a JSON array.');
  }
  for (final Object? caseRaw in casesRaw) {
    if (caseRaw is! Map<String, dynamic>) {
      throw const _ToolingException('Fixture case must be a JSON object.');
    }
    final String filePath = _requiredString(caseRaw, 'file');
    final String sourcePath = _requiredString(caseRaw, 'sourcePath');
    final File fixture = File(
      '${manifestFile.parent.path}${Platform.pathSeparator}'
      '${filePath.replaceAll('/', Platform.pathSeparator)}',
    );
    if (!fixture.existsSync()) {
      throw _ToolingException('Missing fixture: $filePath');
    }
    final List<String> actual = _scanSource(
      source: fixture.readAsStringSync(),
      sourcePath: sourcePath,
      repoRoot: repoRoot,
      policy: policy,
    ).map((finding) => finding.rule).toList()..sort();
    final List<String> expected = _requiredStringList(caseRaw, 'expectedRules')
      ..sort();
    if (jsonEncode(actual) != jsonEncode(expected)) {
      throw _ToolingException(
        'Fixture $filePath expected $expected but found $actual.',
      );
    }
  }

  final _Finding sample = const _Finding(
    rule: 'cross_feature_import',
    source: 'apps/mobile/lib/features/a/presentation/example.dart',
    target: 'apps/mobile/lib/features/b/domain/example.dart',
    importUri: '../../../b/domain/example.dart',
    line: 1,
  );
  final Map<String, Object?> json = _bootstrapException(sample, 1);
  final _BoundaryException exception = _BoundaryException.fromJson(json);
  bool duplicateRejected = false;
  try {
    _validateExceptions(<_BoundaryException>[exception, exception]);
  } on _ToolingException {
    duplicateRejected = true;
  }
  if (!duplicateRejected) {
    throw const _ToolingException('Duplicate exception self-test failed.');
  }

  final _ExceptionRegistry staleRegistry = _ExceptionRegistry(
    schemaVersion: 1,
    baselineBudget: policy.exceptionBudget,
    exceptions: <_BoundaryException>[exception],
  );
  final _Evaluation staleEvaluation = _evaluate(
    findings: const <_Finding>[],
    registry: staleRegistry,
    policy: policy,
  );
  if (staleEvaluation.stale.length != 1 || !staleEvaluation.hasFailures) {
    throw const _ToolingException('Stale exception self-test failed.');
  }

  final Map<String, Object?> expiredJson = Map<String, Object?>.from(json)
    ..['expiresOn'] = '2000-01-01';
  final _BoundaryException expiredException = _BoundaryException.fromJson(
    expiredJson,
  );
  final _Evaluation expiredEvaluation = _evaluate(
    findings: <_Finding>[sample],
    registry: _ExceptionRegistry(
      schemaVersion: 1,
      baselineBudget: policy.exceptionBudget,
      exceptions: <_BoundaryException>[expiredException],
    ),
    policy: policy,
  );
  if (expiredEvaluation.expired.length != 1 ||
      expiredEvaluation.violations.length != 1) {
    throw const _ToolingException('Expired exception self-test failed.');
  }

  final _BoundaryPolicy zeroBudgetPolicy = _BoundaryPolicy(
    schemaVersion: policy.schemaVersion,
    policyVersion: policy.policyVersion,
    sourceRoots: policy.sourceRoots,
    packageRoots: policy.packageRoots,
    knownLayers: policy.knownLayers,
    excludedGeneratedRoots: policy.excludedGeneratedRoots,
    excludedFileSuffixes: policy.excludedFileSuffixes,
    frameworkPackages: policy.frameworkPackages,
    blockingRules: policy.blockingRules,
    exceptionBudget: 0,
  );
  final _Evaluation budgetEvaluation = _evaluate(
    findings: <_Finding>[sample],
    registry: _ExceptionRegistry(
      schemaVersion: 1,
      baselineBudget: 0,
      exceptions: <_BoundaryException>[exception],
    ),
    policy: zeroBudgetPolicy,
  );
  if (!budgetEvaluation.budgetExceeded || !budgetEvaluation.hasFailures) {
    throw const _ToolingException('Exception budget self-test failed.');
  }

  final _Evaluation formatEvaluation = _evaluate(
    findings: <_Finding>[sample],
    registry: _ExceptionRegistry(
      schemaVersion: 1,
      baselineBudget: policy.exceptionBudget,
      exceptions: const <_BoundaryException>[],
    ),
    policy: policy,
  );
  final String textReport = _render(
    format: 'text',
    policy: policy,
    evaluation: formatEvaluation,
    scannedFileCount: 1,
    durationMs: 1,
  );
  final Map<String, dynamic> jsonReport =
      jsonDecode(
            _render(
              format: 'json',
              policy: policy,
              evaluation: formatEvaluation,
              scannedFileCount: 1,
              durationMs: 1,
            ),
          )
          as Map<String, dynamic>;
  final String markdownReport = _render(
    format: 'markdown',
    policy: policy,
    evaluation: formatEvaluation,
    scannedFileCount: 1,
    durationMs: 1,
  );
  if (!formatEvaluation.hasFailures ||
      formatEvaluation.violations.length != 1 ||
      !textReport.contains('Findings: 1') ||
      !textReport.contains('Violations: 1') ||
      jsonReport['findingCount'] != 1 ||
      jsonReport['violationCount'] != 1 ||
      !markdownReport.contains('- Unsuppressed violations: 1')) {
    throw const _ToolingException('Report format parity self-test failed.');
  }

  bool missingRootRejected = false;
  try {
    _validateRepoRoot(
      Directory('${repoRoot.path}${Platform.pathSeparator}missing-self-test'),
      policy,
    );
  } on _ToolingException {
    missingRootRejected = true;
  }
  if (!missingRootRejected) {
    throw const _ToolingException('Missing root self-test failed.');
  }

  bool pathEscapeRejected = false;
  try {
    final Directory canonicalRoot = Directory(
      repoRoot.absolute.uri.normalizePath().toFilePath(),
    );
    _repoRelative(
      canonicalRoot,
      '${canonicalRoot.parent.path}${Platform.pathSeparator}outside.dart',
    );
  } on _ToolingException {
    pathEscapeRejected = true;
  }
  if (!pathEscapeRejected) {
    throw const _ToolingException('Path escape self-test failed.');
  }
}

void _validateExceptions(List<_BoundaryException> exceptions) {
  final Set<String> ids = <String>{};
  final Set<String> fingerprints = <String>{};
  for (final _BoundaryException exception in exceptions) {
    if (!ids.add(exception.id)) {
      throw _ToolingException('Duplicate exception ID: ${exception.id}');
    }
    if (!fingerprints.add(exception.fingerprint)) {
      throw _ToolingException(
        'Duplicate exception fingerprint: ${exception.fingerprint}',
      );
    }
  }
}

Map<String, Object?> _readJsonObject(File file) {
  if (!file.existsSync()) {
    throw _ToolingException('Required file is missing: ${file.path}');
  }
  Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    throw _ToolingException('Invalid JSON in ${file.path}: ${error.message}');
  }
  if (decoded is! Map<String, dynamic>) {
    throw _ToolingException('Expected JSON object in ${file.path}.');
  }
  return decoded;
}

String _requiredString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! String || value.isEmpty) {
    throw _ToolingException('$key must be a non-empty string.');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! int) {
    throw _ToolingException('$key must be an integer.');
  }
  return value;
}

List<String> _requiredStringList(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! List<Object?> || value.any((element) => element is! String)) {
    throw _ToolingException('$key must be an array of strings.');
  }
  return value.cast<String>().toList(growable: false);
}

String _absoluteFromRepo(Directory repoRoot, String relativePath) => File(
  '${repoRoot.path}${Platform.pathSeparator}'
  '${relativePath.replaceAll('/', Platform.pathSeparator)}',
).absolute.uri.normalizePath().toFilePath();

String _repoRelative(Directory repoRoot, String absolutePath) {
  final String root = _normalizePath(
    repoRoot.absolute.uri.normalizePath().toFilePath(),
  ).replaceFirst(RegExp(r'/+$'), '');
  final String full = _normalizePath(
    File(absolutePath).absolute.uri.normalizePath().toFilePath(),
  );
  if (full == root) return '.';
  if (!full.startsWith('$root/')) {
    throw _ToolingException('Resolved path escapes repo root: $full');
  }
  return full.substring(root.length + 1);
}

String _resolveOutputPath(Directory repoRoot, String path) {
  final File file = File(path);
  if (file.isAbsolute) {
    _repoRelative(repoRoot, file.path);
    return file.path;
  }
  return _absoluteFromRepo(repoRoot, path);
}

String _normalizePath(String value) =>
    value.replaceAll('\\', '/').replaceAll(RegExp('/+'), '/');

String _normalizeTarget(String value) =>
    value.startsWith('package:') ? value : _normalizePath(value);

String _normalizeNewlines(String value) =>
    value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

String? _featureFromPath(String path) {
  final List<String> parts = _normalizePath(path).split('/');
  final int index = parts.indexOf('features');
  return index >= 0 && index + 1 < parts.length ? parts[index + 1] : null;
}

String _targetGroup(String target) {
  final String normalized = _normalizeTarget(target);
  if (normalized.startsWith('apps/mobile/lib/core/')) return 'core';
  if (normalized.startsWith('apps/mobile/lib/app/di/')) return 'app/di';
  if (normalized.startsWith('apps/mobile/lib/app/presentation/')) {
    return 'app/presentation';
  }
  if (normalized.startsWith('package:')) {
    return normalized.substring('package:'.length).split('/').first;
  }
  return 'other';
}

String _fingerprint(String rule, String source, String target) {
  final List<int> bytes = utf8.encode(
    '$rule\n${_normalizePath(source)}\n${_normalizeTarget(target)}',
  );
  int hash = 0x811c9dc5;
  for (final int byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

int _compareFindings(_Finding left, _Finding right) {
  int value = left.rule.compareTo(right.rule);
  if (value != 0) return value;
  value = left.source.compareTo(right.source);
  if (value != 0) return value;
  value = left.target.compareTo(right.target);
  if (value != 0) return value;
  return left.line.compareTo(right.line);
}
