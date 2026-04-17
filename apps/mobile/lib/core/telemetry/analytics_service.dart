import 'dart:developer' as developer;

abstract class AnalyticsService {
  void track(
    String eventName, {
    Map<String, Object?> params = const <String, Object?>{},
  });
}

class ConsoleAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {
    developer.log(
      'analytics_event',
      name: eventName,
      error: params,
    );
  }
}
