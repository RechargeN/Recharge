import 'package:flutter/material.dart';

import '../recharge_theme.dart';

/// Pill-shaped selectable chip used across Create-flow steps (weekdays,
/// amenities, language, experience, ...). Behaves like a `FilterChip`
/// (same `selected`/`onSelected` contract) with the flat, filled-pill look
/// from the Create-flow visual language instead of the Material default.
class CreateFlowChip extends StatelessWidget {
  const CreateFlowChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;

  /// Same contract as `FilterChip.onSelected`: pass `null` to render the
  /// chip disabled (dimmed, not tappable).
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onSelected != null;
    final Color background = selected
        ? RechargeTheme.emerald900
        : RechargeTheme.createSoftGray;
    final Color foreground = selected ? Colors.white : RechargeTheme.ink;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: background,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: enabled ? () => onSelected!(!selected) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              label,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
