import 'package:flutter/foundation.dart';

import '../../../../core/telemetry/analytics_service.dart';
import '../../domain/entities/discover_item_entity.dart';
import '../../domain/repositories/discover_repository.dart';
import '../../domain/usecases/get_discover_feed_usecase.dart';
import '../state/discover_feed_state.dart';

class DiscoverFeedController extends ChangeNotifier {
  DiscoverFeedController({
    required GetDiscoverFeedUseCase getDiscoverFeedUseCase,
    required AnalyticsService analyticsService,
  })  : _getDiscoverFeedUseCase = getDiscoverFeedUseCase,
        _analyticsService = analyticsService;

  final GetDiscoverFeedUseCase _getDiscoverFeedUseCase;
  final AnalyticsService _analyticsService;

  DiscoverFeedState _state = const DiscoverFeedState.initial();
  DiscoverFeedState get state => _state;

  bool _requestedOnce = false;

  Future<void> ensureLoaded() async {
    if (_requestedOnce) return;
    _requestedOnce = true;
    await loadFeed();
  }

  Future<void> loadFeed() async {
    if (_state.status == DiscoverFeedStatus.loading) return;
    _analyticsService.track(
      'discover_feed_load_started',
      params: <String, Object?>{
        'source_screen': 'discover_hub',
      },
    );

    _setState(
      _state.copyWith(
        status: DiscoverFeedStatus.loading,
        clearMessage: true,
      ),
    );

    try {
      final List<DiscoverItemEntity> items = await _getDiscoverFeedUseCase();

      if (items.isEmpty) {
        _analyticsService.track(
          'discover_feed_loaded',
          params: <String, Object?>{
            'result': 'empty',
            'item_count': 0,
          },
        );
        _setState(
          _state.copyWith(
            status: DiscoverFeedStatus.empty,
            items: const <DiscoverItemEntity>[],
            message: 'Пока в ленте ничего не найдено',
          ),
        );
        return;
      }

      _setState(
        _state.copyWith(
          status: DiscoverFeedStatus.success,
          items: items,
          clearMessage: true,
        ),
      );
      _analyticsService.track(
        'discover_feed_loaded',
        params: <String, Object?>{
          'result': 'success',
          'item_count': items.length,
        },
      );
    } on DiscoverException catch (e) {
      _analyticsService.track(
        'discover_feed_load_failed',
        params: <String, Object?>{
          'error_code': e.code,
          'error_group': _errorGroup(e.code),
        },
      );
      _setState(
        _state.copyWith(
          status: DiscoverFeedStatus.error,
          items: const <DiscoverItemEntity>[],
          message: _messageForErrorCode(e.code),
        ),
      );
    } on Exception {
      _analyticsService.track(
        'discover_feed_load_failed',
        params: const <String, Object?>{
          'error_code': 'UNEXPECTED',
          'error_group': 'server',
        },
      );
      _setState(
        _state.copyWith(
          status: DiscoverFeedStatus.error,
          items: const <DiscoverItemEntity>[],
          message: 'Не удалось загрузить ленту. Попробуйте снова.',
        ),
      );
    }
  }

  String _messageForErrorCode(String code) {
    switch (code) {
      case 'DISCOVER_NOT_FOUND':
        return 'Данные недоступны';
      case 'NETWORK_UNAVAILABLE':
        return 'Нет подключения к интернету';
      default:
        return 'Не удалось загрузить ленту. Попробуйте снова.';
    }
  }

  String _errorGroup(String code) {
    if (code.contains('NETWORK')) return 'network';
    if (code.contains('NOT_FOUND')) return 'data';
    return 'server';
  }

  void _setState(DiscoverFeedState state) {
    _state = state;
    notifyListeners();
  }
}
