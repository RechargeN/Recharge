import 'package:flutter/foundation.dart';

import '../../domain/entities/route_draft_data.dart';
import '../../domain/repositories/route_gpx_file_picker_port.dart';
import '../../domain/repositories/route_gpx_repository.dart';
import '../../domain/usecases/export_route_gpx_usecase.dart';
import '../../domain/usecases/inspect_route_gpx_usecase.dart';

enum RouteGpxTransferStatus {
  idle,
  picking,
  preview,
  importing,
  exporting,
  exported,
  failed,
}

class RouteGpxTransferController extends ChangeNotifier {
  RouteGpxTransferController({
    required RouteGpxFilePickerPort filePicker,
    required RouteGpxRepository repository,
    required InspectRouteGpxUseCase inspectGpx,
    required ExportRouteGpxUseCase exportGpx,
  }) : _filePicker = filePicker,
       _repository = repository,
       _inspectGpx = inspectGpx,
       _exportGpx = exportGpx;

  final RouteGpxFilePickerPort _filePicker;
  final RouteGpxRepository _repository;
  final InspectRouteGpxUseCase _inspectGpx;
  final ExportRouteGpxUseCase _exportGpx;

  RouteGpxTransferStatus _status = RouteGpxTransferStatus.idle;
  RouteGpxInspection? _inspection;
  String? _selectedCandidateKey;
  bool _connectGapsConfirmed = false;
  bool _importWaypoints = false;
  String? _failureCode;

  RouteGpxTransferStatus get status => _status;
  RouteGpxInspection? get inspection => _inspection;
  String? get selectedCandidateKey => _selectedCandidateKey;
  bool get connectGapsConfirmed => _connectGapsConfirmed;
  bool get importWaypoints => _importWaypoints;
  String? get failureCode => _failureCode;
  bool get isBusy =>
      _status == RouteGpxTransferStatus.picking ||
      _status == RouteGpxTransferStatus.importing ||
      _status == RouteGpxTransferStatus.exporting;

  RouteGpxCandidateSummary? get selectedCandidate {
    final key = _selectedCandidateKey;
    if (key == null) return null;
    for (final candidate
        in _inspection?.candidates ?? const <RouteGpxCandidateSummary>[]) {
      if (candidate.selectionKey == key) return candidate;
    }
    return null;
  }

  bool get canImport {
    final candidate = selectedCandidate;
    return _status == RouteGpxTransferStatus.preview &&
        candidate != null &&
        (candidate.gapCount == 0 || _connectGapsConfirmed);
  }

  Future<void> chooseAndInspect() async {
    if (isBusy) return;
    await _discardInspection();
    _setStatus(RouteGpxTransferStatus.picking);
    try {
      final file = await _filePicker.pickForImport();
      if (file == null) {
        _setStatus(RouteGpxTransferStatus.idle);
        return;
      }
      try {
        final inspected = await _inspectGpx(file);
        _inspection = inspected;
        _selectedCandidateKey = inspected.candidates.length == 1
            ? inspected.candidates.single.selectionKey
            : null;
        _connectGapsConfirmed = false;
        _importWaypoints = false;
        _setStatus(RouteGpxTransferStatus.preview);
      } catch (_) {
        await _repository.discard(file);
        rethrow;
      }
    } on RouteGpxException catch (error) {
      _fail(error.code);
    } catch (_) {
      _fail('gpx_file_pick_failed');
    }
  }

  void selectCandidate(String key) {
    final inspection = _inspection;
    if (_status != RouteGpxTransferStatus.preview ||
        inspection == null ||
        !inspection.candidates.any(
          (candidate) => candidate.selectionKey == key,
        )) {
      return;
    }
    _selectedCandidateKey = key;
    _connectGapsConfirmed = false;
    notifyListeners();
  }

  void setConnectGapsConfirmed(bool value) {
    if (_status != RouteGpxTransferStatus.preview) return;
    _connectGapsConfirmed = value;
    notifyListeners();
  }

  void setImportWaypoints(bool value) {
    if (_status != RouteGpxTransferStatus.preview) return;
    _importWaypoints = value;
    notifyListeners();
  }

  RouteGpxImportSelection? buildImportSelection() {
    final current = _inspection;
    final candidate = selectedCandidate;
    if (!canImport || current == null || candidate == null) return null;
    final gaps = <String, RouteGpxGapResolution>{
      for (var index = 1; index < candidate.segmentCount; index++)
        '${candidate.selectionKey}:gap:${index - 1}:$index':
            RouteGpxGapResolution.direct,
    };
    final waypointDecisions = <int, RouteGpxWaypointDecision>{
      if (_importWaypoints)
        for (final waypoint in current.waypoints)
          waypoint.sourceIndex: RouteGpxWaypointDecision.keepOffTrack,
    };
    return RouteGpxImportSelection(
      file: current.file,
      candidateKeys: <String>[candidate.selectionKey],
      mergeTracks: false,
      importWaypoints: _importWaypoints,
      stripTimestamps: true,
      stripPrivateMetadata: true,
      gapResolutions: gaps,
      waypointDecisions: waypointDecisions,
    );
  }

  void beginImport() {
    if (canImport) _setStatus(RouteGpxTransferStatus.importing);
  }

  void completeImport({required bool accepted, String? failureCode}) {
    _inspection = null;
    _selectedCandidateKey = null;
    _connectGapsConfirmed = false;
    _importWaypoints = false;
    if (accepted) {
      _failureCode = null;
      _setStatus(RouteGpxTransferStatus.idle);
    } else {
      _failureCode = failureCode ?? 'gpx_import_failed';
      _setStatus(RouteGpxTransferStatus.failed, clearFailure: false);
    }
  }

  Future<bool> exportRoute({
    required String routeId,
    required String routeVersionId,
    required RouteDraftData route,
    required bool includeElevation,
    required bool includeWaypoints,
  }) async {
    if (isBusy) return false;
    _setStatus(RouteGpxTransferStatus.exporting);
    RouteSafeFileRef? exported;
    try {
      exported = await _exportGpx(
        RouteGpxExportRequest(
          routeId: routeId,
          routeVersionId: routeVersionId,
          route: route,
          includeElevation: includeElevation,
          includeWaypoints: includeWaypoints,
        ),
      );
      final saved = await _filePicker.saveExport(exported);
      if (!saved) {
        _fail('gpx_export_destination_unavailable');
        return false;
      }
      _setStatus(RouteGpxTransferStatus.exported);
      return true;
    } on RouteGpxException catch (error) {
      _fail(error.code);
      return false;
    } catch (_) {
      _fail('gpx_export_failed');
      return false;
    } finally {
      if (exported != null) await _repository.discard(exported);
    }
  }

  Future<void> cancelPreview() async {
    if (isBusy) return;
    await _discardInspection();
    _setStatus(RouteGpxTransferStatus.idle);
  }

  void clearResult() {
    if (isBusy) return;
    _setStatus(RouteGpxTransferStatus.idle);
  }

  Future<void> _discardInspection() async {
    final file = _inspection?.file;
    _inspection = null;
    _selectedCandidateKey = null;
    _connectGapsConfirmed = false;
    _importWaypoints = false;
    if (file != null) await _repository.discard(file);
  }

  void _fail(String code) {
    _failureCode = code;
    _setStatus(RouteGpxTransferStatus.failed, clearFailure: false);
  }

  void _setStatus(RouteGpxTransferStatus value, {bool clearFailure = true}) {
    _status = value;
    if (clearFailure) _failureCode = null;
    notifyListeners();
  }

  @override
  void dispose() {
    final file = _inspection?.file;
    if (file != null) {
      _inspection = null;
      _repository.discard(file);
    }
    super.dispose();
  }
}
