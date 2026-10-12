/// Public facts of one immutable Activity revision from Catalog.
class ActivityCatalogFacts {
  const ActivityCatalogFacts({
    required this.durationMinMinutes,
    required this.durationMaxMinutes,
    this.linkedPlaceId,
    this.linkedPlaceTitle,
    this.suggestedGroupMin,
    this.suggestedGroupMax,
    this.fullDescription = '',
    this.addressLine = '',
    this.accessNotes = '',
    this.isInformal = false,
    this.cautionNote = '',
    this.timeOfDay,
    this.season,
    this.contributionKind,
    this.contributionNote,
    this.amountMinor,
    this.currencyCode,
    this.galleryMediaIds = const <String>[],
  });
  final String? linkedPlaceId, linkedPlaceTitle;
  final int durationMinMinutes;
  final int durationMaxMinutes;
  final int? suggestedGroupMin;
  final int? suggestedGroupMax;
  final String fullDescription;
  final String addressLine;
  final String accessNotes;
  final bool isInformal;
  final String cautionNote;
  final String? timeOfDay;
  final String? season;
  final String? contributionKind;
  final String? contributionNote;
  final int? amountMinor;
  final String? currencyCode;
  final List<String> galleryMediaIds;
  String get durationLabel => durationMinMinutes == durationMaxMinutes
      ? '$durationMinMinutes min'
      : '$durationMinMinutes–$durationMaxMinutes min';
}
