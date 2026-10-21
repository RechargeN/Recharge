import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/create/application/route_content_publication_controller.dart';
import '../../features/create/domain/entities/publisher_ref.dart';
import '../../features/create/presentation/widgets/route_content_publication_section.dart';
import '../application/active_create_publisher_provider.dart';
import '../di/route_content_publication_composition.dart';

/// Default-off test page for the Route publication path (J2). It hosts the
/// section for the signed-in user's own Create Route and shows nothing unless
/// the test entry builds a controller.
class RouteContentPublicationPage extends StatelessWidget {
  const RouteContentPublicationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route publication (test)')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: RouteContentPublicationPanel(),
      ),
    );
  }
}

class RouteContentPublicationPanel extends ConsumerStatefulWidget {
  const RouteContentPublicationPanel({super.key});

  @override
  ConsumerState<RouteContentPublicationPanel> createState() =>
      _RouteContentPublicationPanelState();
}

class _RouteContentPublicationPanelState
    extends ConsumerState<RouteContentPublicationPanel> {
  Future<RouteContentPublicationController?>? _controller;
  RouteContentPublicationController? _created;
  String? _key;

  @override
  void dispose() {
    _created?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = ref.watch(authControllerProvider).state.user?.id;
    final PublisherRef? publisher = ref.watch(activeCreatePublisherProvider);
    if (userId == null) {
      return const Text(
        'Sign in to publish your Route',
        key: Key('route-publication-signed-out'),
      );
    }
    // A change of account or workspace builds a new controller bound to it.
    final String key = '$userId:${publisher?.type.wireName}:${publisher?.id}';
    if (_controller == null || _key != key) {
      _key = key;
      _created?.dispose();
      _created = null;
      _controller =
          createRouteContentPublicationController(
            userId: userId,
            publisherRef: publisher,
          ).then((RouteContentPublicationController? controller) {
            _created = controller;
            controller?.load();
            return controller;
          });
    }
    return FutureBuilder<RouteContentPublicationController?>(
      future: _controller,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<RouteContentPublicationController?> snapshot,
          ) {
            final RouteContentPublicationController? controller = snapshot.data;
            if (controller == null) return const SizedBox.shrink();
            return RouteContentPublicationSection(controller: controller);
          },
    );
  }
}
