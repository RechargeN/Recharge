import '../entities/rental_private_authoring_data.dart';

/// Physically separate storage boundary for Rental's private authoring
/// data (spec §7.3, AC 12) — deliberately not part of `CreateRepository`,
/// so the public draft/publish path can never read it, not even by
/// accident.
abstract class RentalPrivateAuthoringRepository {
  Future<RentalPrivateAuthoringData> read(String draftId);

  Future<void> write(String draftId, RentalPrivateAuthoringData data);

  Future<void> delete(String draftId);
}
