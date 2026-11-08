import '../../booking/data/booking_callable_adapter.dart';
import '../domain/entities/seller_declaration.dart';

/// A refused or failed declaration call. `code` is the server result code
/// (`invalid_contract`, `revision_conflict`, `account_inactive`,
/// `unauthenticated`, `unavailable`) or a transport code.
final class SellerDeclarationFailure implements Exception {
  const SellerDeclarationFailure(this.code);

  final String code;

  @override
  String toString() => 'SellerDeclarationFailure($code)';
}

/// ADR 0023 (2026-11-08): the author's own seller declaration over the
/// `sellerDeclarationV1` callable. The transport adds the current Session;
/// the server resolves the user from it, never from this payload.
final class SellerDeclarationGateway {
  SellerDeclarationGateway(this._port, {String Function()? requestId})
    : _requestId =
          requestId ??
          (() => 'seller-${DateTime.now().toUtc().microsecondsSinceEpoch}');

  static const String callable = 'sellerDeclarationV1';

  final BookingCallablePort _port;
  final String Function() _requestId;

  Future<SellerDeclarationRecord> read() async {
    final Object? data = await _call(<String, Object?>{
      'schemaVersion': 1,
      'commandType': 'getSellerDeclaration',
      'requestId': _requestId(),
    });
    return _record(data);
  }

  Future<SellerDeclarationRecord> declare(
    SellerDeclaration declaration, {
    required int expectedRevision,
  }) async {
    final Object? data = await _call(<String, Object?>{
      'schemaVersion': 1,
      'commandType': 'declareSeller',
      'requestId': _requestId(),
      'expectedRevision': expectedRevision,
      'declaration': declaration.toJson(),
    });
    final SellerDeclarationRecord record = _record(data);
    if (record.declaration == null) {
      throw const SellerDeclarationFailure('unavailable');
    }
    return record;
  }

  Future<Object?> _call(Map<String, Object?> command) async {
    final Map<String, Object?> result;
    try {
      result = await _port.invoke(callable, command);
    } on BookingCallableFailure catch (error) {
      throw SellerDeclarationFailure(error.code);
    }
    if (result['schemaVersion'] != 1) {
      throw const SellerDeclarationFailure('unavailable');
    }
    if (result['kind'] == 'succeeded') return result['data'];
    final Object? code = result['code'];
    throw SellerDeclarationFailure(code is String ? code : 'unavailable');
  }

  static SellerDeclarationRecord _record(Object? data) {
    if (data == null) {
      return const SellerDeclarationRecord(declaration: null, revision: 0);
    }
    if (data is! Map || data['revision'] is! int) {
      throw const SellerDeclarationFailure('unavailable');
    }
    final SellerDeclaration? declaration = SellerDeclaration.fromJson(
      data['declaration'],
    );
    if (declaration == null) {
      throw const SellerDeclarationFailure('unavailable');
    }
    return SellerDeclarationRecord(
      declaration: declaration,
      revision: data['revision'] as int,
    );
  }
}
