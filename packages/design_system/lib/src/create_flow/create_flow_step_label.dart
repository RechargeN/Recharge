import 'package:flutter/material.dart';

import '../recharge_theme.dart';

/// "Step X of N · Title" caption with an optional description line, used
/// under [CreateFlowProgressBar] on Create-flow pages.
class CreateFlowStepLabel extends StatelessWidget {
  const CreateFlowStepLabel({
    super.key,
    required this.stepNumber,
    required this.stepCount,
    required this.title,
    this.description,
  });

  final int stepNumber;
  final int stepCount;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final TextStyle? captionStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(
      color: RechargeTheme.mutedInk,
      fontWeight: FontWeight.w700,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Step $stepNumber of $stepCount · $title', style: captionStyle),
        if (description != null && description!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            description!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: RechargeTheme.mutedInk),
          ),
        ],
      ],
    );
  }
}
