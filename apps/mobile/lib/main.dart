import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/google_maps_web_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeGoogleMapsWebImpl();
  await bootstrap();
  runApp(
    const ProviderScope(
      child: RechargeApp(),
    ),
  );
}
