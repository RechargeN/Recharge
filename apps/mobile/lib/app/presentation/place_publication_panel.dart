import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/create/application/place_publication_controller.dart';
import '../../features/create/presentation/widgets/place_publication_section.dart';
import '../di/place_publication_composition.dart';

/// Default-off test page for the Place publication path (D3.1). It hosts the
/// section for the signed-in user's own Create Place draft and shows nothing
/// unless the test entry builds a controller.
class PlacePublicationPage extends StatelessWidget {
  const PlacePublicationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Place publication (test)')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: PlacePublicationPanel(),
      ),
    );
  }
}

class PlacePublicationPanel extends ConsumerStatefulWidget {
  const PlacePublicationPanel({super.key});

  @override
  ConsumerState<PlacePublicationPanel> createState() =>
      _PlacePublicationPanelState();
}

class _PlacePublicationPanelState extends ConsumerState<PlacePublicationPanel> {
  Future<PlacePublicationController?>? _controller;
  PlacePublicationController? _created;
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
        'Sign in to publish your Place draft',
        key: Key('place-publication-signed-out'),
      );
    }
    // A change of account builds a new controller bound to that account.
    if (_controller == null || _userId != userId) {
      _userId = userId;
      _created?.dispose();
      _created = null;
      _controller = createPlacePublicationController(userId: userId).then((
        PlacePublicationController? controller,
      ) {
        _created = controller;
        controller?.load();
        return controller;
      });
    }
    return FutureBuilder<PlacePublicationController?>(
      future: _controller,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<PlacePublicationController?> snapshot,
          ) {
            final PlacePublicationController? controller = snapshot.data;
            if (controller == null) return const SizedBox.shrink();
            return PlacePublicationSection(controller: controller);
          },
    );
  }
}
