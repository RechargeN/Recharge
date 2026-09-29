import 'package:flutter/material.dart';

import '../recharge_theme.dart';

/// Segmented step-progress indicator used across Create-flow pages.
///
/// Segments up to and including [currentStep] are filled with the brand
/// color; the remaining segments render as soft-gray tracks.
class CreateFlowProgressBar extends StatelessWidget {
  const CreateFlowProgressBar({
    super.key,
    required this.stepCount,
    required this.currentStep,
    this.height = 6,
  });

  final int stepCount;
  final int currentStep;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${currentStep + 1} of $stepCount',
      child: Row(
        children: List<Widget>.generate(stepCount, (int index) {
          final bool filled = index <= currentStep;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == stepCount - 1 ? 0 : 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(height),
                child: SizedBox(
                  height: height,
                  child: ColoredBox(
                    color: filled
                        ? RechargeTheme.emerald900
                        : RechargeTheme.createSoftGray,
                  ),
                ),
              ),
            ),
          );
        }, growable: false),
      ),
    );
  }
}
