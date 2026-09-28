import '../../../../shared/models/catalog_object_ref.dart';
import '../../domain/entities/published_class_workshop_discovery_entity.dart';
import '../../domain/repositories/published_class_workshop_discovery_port.dart';
import '../../domain/repositories/details_lookup_port.dart';
import '../../domain/repositories/timezone_repository.dart';

class ClassWorkshopDetailsLookup implements DetailsLookupPort {
  const ClassWorkshopDetailsLookup(this._port, this._timezone);
  final PublishedClassWorkshopDiscoveryPort _port;
  final TimezoneRepository _timezone;

  @override
  Future<PublishedClassWorkshopDiscoveryEntity?> lookup(String objectId) async {
    final value = await _port.getActiveClassWorkshop(objectId);
    if (value == null || value.offeringId != objectId) return null;
    if (value.schedule case ClassWorkshopAnnouncedSchedule(
      :final occurrences,
    )) {
      if (occurrences.any(
        (row) => !_timezone.isValidTimezone(row.timezoneId),
      )) {
        return null;
      }
    }
    return value;
  }

  @override
  CatalogObjectType classify(Object projection) =>
      CatalogObjectType.classWorkshop;
}
