import 'package:flutter/material.dart';

import '../recharge_theme.dart';

/// Bottom action area for Create-flow steps: a single full-width primary
/// CTA, with an optional lightweight secondary action (e.g. "Save draft")
/// and an optional "back" action above it.
class CreateFlowBottomBar extends StatelessWidget {
  const CreateFlowBottomBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.primaryBusy = false,
    this.primaryIcon,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.backLabel,
    this.onBackPressed,
    this.backKey,
    this.secondaryKey,
    this.primaryKey,
  });

  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final bool primaryBusy;
  final IconData? primaryIcon;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final String? backLabel;
  final VoidCallback? onBackPressed;
  final Key? backKey;
  final Key? secondaryKey;
  final Key? primaryKey;

  @override
  Widget build(BuildContext context) {
    final bool hasTopRow = onBackPressed != null || secondaryLabel != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (hasTopRow) ...<Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              if (onBackPressed != null)
                TextButton.icon(
                  key: backKey,
                  onPressed: onBackPressed,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: Text(backLabel ?? 'Back'),
                  style: TextButton.styleFrom(
                    foregroundColor: RechargeTheme.mutedInk,
                  ),
                )
              else
                const SizedBox.shrink(),
              if (secondaryLabel != null)
                TextButton(
                  key: secondaryKey,
                  onPressed: onSecondaryPressed,
                  style: TextButton.styleFrom(
                    foregroundColor: RechargeTheme.emerald900,
                  ),
                  child: Text(secondaryLabel!),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            key: primaryKey,
            onPressed: primaryBusy ? null : onPrimaryPressed,
            style: FilledButton.styleFrom(
              backgroundColor: RechargeTheme.emerald900,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  RechargeTheme.createPillRadius,
                ),
              ),
            ),
            icon: primaryBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : (primaryIcon == null ? const SizedBox.shrink() : Icon(primaryIcon)),
            label: Text(
              primaryLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}
