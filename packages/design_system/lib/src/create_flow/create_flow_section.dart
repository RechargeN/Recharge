import 'package:flutter/material.dart';

import '../recharge_theme.dart';

/// Soft, minimally-bordered rounded card used to group a Create-flow step's
/// fields — the "Create a place" / "What is this place?" card pattern.
class CreateFlowSection extends StatelessWidget {
  const CreateFlowSection({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RechargeTheme.createSectionRadius),
        side: const BorderSide(color: RechargeTheme.createSoftGrayLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (title != null) ...<Widget>[
              Text(
                title!,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: RechargeTheme.mutedInk,
                  ),
                ),
              ],
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
