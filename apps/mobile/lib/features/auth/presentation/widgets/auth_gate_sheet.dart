import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/localization/l10n_context.dart';
import '../../application/auth_providers.dart';
import '../../application/controllers/auth_controller.dart';

Future<void> showAuthGateSheet(
  BuildContext context, {
  required ProtectedAction action,
  required String sourceScreen,
  required String sourceAction,
  required String originRoute,
  required VoidCallback onContinueAsGuest,
  bool allowGuest = true,
}) {
  // Round 1 (owner 2026-11-20): offline the user is still signed in; the
  // action needs the server, not a new sign-in.
  final bool offline = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(authControllerProvider).state.isOffline;
  if (offline) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.authOfflineNeedsConnection)),
    );
    return Future<void>.value();
  }
  final parentContext = context;
  return showModalBottomSheet<void>(
    context: parentContext,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              allowGuest
                  ? context.l10n.authSignInHeadline
                  : context.l10n.authSignInToContinue,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              allowGuest
                  ? context.l10n.authSignInBody
                  : context.l10n.authScenarioRequiresSignIn,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final uri = Uri(
                  path: RouteNames.signIn,
                  queryParameters: <String, String>{
                    'originRoute': originRoute,
                    'originAction': action.name,
                    'sourceScreen': sourceScreen,
                    'sourceAction': sourceAction,
                  },
                );
                context.pop();
                parentContext.push(uri.toString());
              },
              child: Text(context.l10n.commonSignIn),
            ),
            if (allowGuest) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  onContinueAsGuest();
                  context.pop();
                },
                child: Text(context.l10n.commonContinueAsGuest),
              ),
            ],
          ],
        ),
      );
    },
  );
}
