import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/create/application/event_publication_controller.dart';
import '../../features/create/presentation/widgets/event_publication_section.dart';
import '../di/event_publication_composition.dart';

/// Default-off test page for the Event publication path (C3). It hosts the
/// section for the signed-in user's own Create Event draft and shows nothing
/// unless the test entry builds a controller.
class EventPublicationPage extends StatelessWidget {
  const EventPublicationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event publication (test)')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: EventPublicationPanel(),
      ),
    );
  }
}

class EventPublicationPanel extends ConsumerStatefulWidget {
  const EventPublicationPanel({super.key});

  @override
  ConsumerState<EventPublicationPanel> createState() =>
      _EventPublicationPanelState();
}

class _EventPublicationPanelState extends ConsumerState<EventPublicationPanel> {
  Future<EventPublicationController?>? _controller;
  EventPublicationController? _created;
  String? _userId;

  @override
  void dispose() {
    _created?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = ref.watch(authControllerProvider).state.user?.id;
    if (userId == null) {
      return const Text(
        'Sign in to publish your Event draft',
        key: Key('event-publication-signed-out'),
      );
    }
    if (_controller == null || _userId != userId) {
      _userId = userId;
      _created?.dispose();
      _created = null;
      _controller = createEventPublicationController(userId: userId).then((
        EventPublicationController? controller,
      ) {
        _created = controller;
        controller?.load();
        return controller;
      });
    }
    return FutureBuilder<EventPublicationController?>(
      future: _controller,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<EventPublicationController?> snapshot,
          ) {
            final EventPublicationController? controller = snapshot.data;
            if (controller == null) return const SizedBox.shrink();
            return EventPublicationSection(controller: controller);
          },
    );
  }
}
