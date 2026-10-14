import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/di/content_server_path_composition.dart';
import 'app/google_maps_web_loader.dart';
import 'features/create/application/content_server_path.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeGoogleMapsWebImpl();
  await bootstrap();
  runApp(
    ProviderScope(
      overrides: [
        // M1 stage 3 (3-Б): the Create form learns from the publication
        // test-entry guards whether a type's server path is on.
        contentServerPathProvider.overrideWithValue(contentServerPathFromDi()),
      ],
      child: const RechargeApp(),
    ),
  );
}
