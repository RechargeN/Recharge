import 'package:flutter/material.dart';

import '../recharge_theme.dart';

/// Dark-brand AppBar for Create-flow pages: back action, centered title and
/// an optional status pill (e.g. "Draft" / "Saved") on the trailing edge.
class CreateFlowAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CreateFlowAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.statusLabel,
    this.statusIcon = Icons.edit_note,
  });

  final String title;
  final VoidCallback? onBack;
  final String? statusLabel;
  final IconData statusIcon;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: RechargeTheme.emerald900,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: onBack == null
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              color: Colors.white,
              onPressed: onBack,
            ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
      actions: statusLabel == null
          ? null
          : <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _StatusPill(label: statusLabel!, icon: statusIcon),
              ),
            ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(RechargeTheme.createPillRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
