import '../entities/seller_declaration.dart';

/// A refused or failed declaration call. `code` is the server result code
/// (`invalid_contract`, `revision_conflict`, `account_inactive`,
/// `unauthenticated`, `unavailable`) or a transport code.
final class SellerDeclarationFailure implements Exception {
  const SellerDeclarationFailure(this.code);

  final String code;

  @override
  String toString() => 'SellerDeclarationFailure($code)';
}

/// ADR 0023 (2026-11-08): the author's own DSA Art. 30 seller declaration.
abstract interface class SellerDeclarationRepository {
  Future<SellerDeclarationRecord> read();

  Future<SellerDeclarationRecord> declare(
    SellerDeclaration declaration, {
    required int expectedRevision,
  });
}
