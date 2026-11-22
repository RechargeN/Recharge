import 'dart:async';

import 'package:flutter/material.dart';

/// Shows the in-app banner for a push only once a page can present it.
///
/// A34 2026-11-22: a push arrived ~1.7 s after launch, while the router had
/// no page yet, and `showSnackBar` failed ("no descendant Scaffolds"). The
/// banner now waits a few seconds for a page and is dropped without one; the
/// inbox is reloaded either way, so nothing is lost.
class PushAnnouncer {
  PushAnnouncer(
    this._messenger, {
    this.retry = const Duration(milliseconds: 300),
    this.attempts = 10,
  });

  final GlobalKey<ScaffoldMessengerState> _messenger;
  final Duration retry;
  final int attempts;

  void announce(SnackBar Function(BuildContext context) banner) =>
      _tryShow(banner, attempts);

  void _tryShow(SnackBar Function(BuildContext context) banner, int left) {
    final ScaffoldMessengerState? messenger = _messenger.currentState;
    if (messenger == null || !messenger.mounted) return;
    if (_hasScaffold(messenger.context)) {
      messenger.showSnackBar(banner(messenger.context));
      return;
    }
    if (left <= 0) return;
    Timer(retry, () => _tryShow(banner, left - 1));
  }

  static bool _hasScaffold(BuildContext context) {
    bool found = false;
    void visit(Element element) {
      if (found) return;
      if (element is StatefulElement && element.state is ScaffoldState) {
        found = true;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }
}
