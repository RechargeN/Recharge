import 'package:flutter/foundation.dart';
import '../domain/repositories/activity_place_link_repository.dart';

class ActivityPlaceLinkController extends ChangeNotifier {
  ActivityPlaceLinkController(this.repository, {String? selectedId}) {
    if (selectedId != null) Future<void>.microtask(() => resolve(selectedId));
  }
  final ActivityPlaceLinkRepository repository;
  List<ActivityPlaceCandidate> items = const [];
  ActivityPlaceCandidate? selected;
  String status = 'idle';
  String? nextCursor;
  String _text = '';
  int _searchVersion = 0, _selectionVersion = 0;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> search(String text, {bool more = false}) async {
    if (_disposed) return;
    final version = ++_searchVersion;
    final cursor = more ? nextCursor : null;
    _text = text;
    status = 'loading';
    if (!more) {
      items = const [];
      nextCursor = null;
    }
    _notify();
    ActivityPlacePage result;
    try {
      result = await repository.candidates(text, after: cursor);
    } catch (_) {
      result = const ActivityPlacePage(available: false);
    }
    if (_disposed || version != _searchVersion) return;
    status = result.available ? 'available' : 'unavailable';
    if (result.available) {
      items = List.unmodifiable(<ActivityPlaceCandidate>[
        if (more) ...items,
        ...result.items,
      ]);
      nextCursor = result.nextCursor;
    } else {
      items = const [];
      nextCursor = null;
    }
    _notify();
  }

  Future<void> more() => search(_text, more: true);
  Future<String?> resolve(String id) async {
    if (_disposed) return null;
    final version = ++_selectionVersion;
    selected = null;
    status = 'loading';
    _notify();
    ActivityPlaceResolution result;
    try {
      result = await repository.resolve(id);
    } catch (_) {
      result = const ActivityPlaceResolution('unavailable');
    }
    if (_disposed || version != _selectionVersion) return null;
    selected = result.status == 'eligible' ? result.place : null;
    status = result.status;
    _notify();
    return selected?.id;
  }

  void clear() {
    ++_selectionVersion;
    ++_searchVersion;
    selected = null;
    items = const [];
    nextCursor = null;
    status = 'idle';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_selectionVersion;
    ++_searchVersion;
    super.dispose();
  }
}

/// Missing runtime composition is an explicit unavailable dependency.
class UnavailableActivityPlaceLinkRepository
    implements ActivityPlaceLinkRepository {
  const UnavailableActivityPlaceLinkRepository();
  @override
  Future<ActivityPlaceResolution> resolve(String id) async =>
      const ActivityPlaceResolution('unavailable');
  @override
  Future<ActivityPlacePage> candidates(String text, {String? after}) async =>
      const ActivityPlacePage(available: false);
}
