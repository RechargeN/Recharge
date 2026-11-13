import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Presentation-only building blocks shared by the seven Object / Offer
/// Details compositions. These widgets render supplied content and callbacks;
/// they never decide eligibility, availability, routing, or CTA behavior.

class ObjectOfferTypeBadge extends StatelessWidget {
  const ObjectOfferTypeBadge({
    super.key,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class ObjectOfferSingleImageHero extends StatelessWidget {
  const ObjectOfferSingleImageHero({
    super.key,
    required this.imageUrl,
    required this.imageSemanticLabel,
    required this.fallbackIcon,
    required this.fallbackColor,
    required this.typeLabel,
    required this.typeForegroundColor,
    required this.typeBackgroundColor,
  });

  final String imageUrl;
  final String imageSemanticLabel;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final String typeLabel;
  final Color typeForegroundColor;
  final Color typeBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: RechargeTheme.objectOfferHeroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (imageUrl.trim().isEmpty)
            _ObjectOfferHeroFallback(icon: fallbackIcon, color: fallbackColor)
          else
            Semantics(
              image: true,
              label: imageSemanticLabel,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ObjectOfferHeroFallback(
                  icon: fallbackIcon,
                  color: fallbackColor,
                ),
              ),
            ),
          Positioned(
            left: 16,
            bottom: 16,
            child: ObjectOfferTypeBadge(
              label: typeLabel,
              foregroundColor: typeForegroundColor,
              backgroundColor: typeBackgroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ObjectOfferHeroFallback extends StatelessWidget {
  const _ObjectOfferHeroFallback({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color),
      child: Center(
        child: Icon(icon, color: RechargeTheme.objectOfferOnHero, size: 64),
      ),
    );
  }
}

class ObjectOfferContentSheet extends StatelessWidget {
  const ObjectOfferContentSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -RechargeTheme.objectOfferSheetOverlap),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: RechargeTheme.objectOfferScreenBackground,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(RechargeTheme.objectOfferSheetTopRadius),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            RechargeTheme.objectOfferHorizontalPadding,
            28,
            RechargeTheme.objectOfferHorizontalPadding,
            24,
          ),
          child: child,
        ),
      ),
    );
  }
}

class ObjectOfferCard extends StatelessWidget {
  const ObjectOfferCard({
    super.key,
    required this.child,
    required this.padding,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(
      RechargeTheme.objectOfferPrimaryCardRadius,
    );
    final Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: RechargeTheme.objectOfferCardSurface,
        borderRadius: radius,
        border: Border.all(color: RechargeTheme.objectOfferSoftBorder),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: RechargeTheme.objectOfferCardShadow,
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: card),
    );
  }
}

class ObjectOfferMetricData {
  const ObjectOfferMetricData({
    required this.value,
    required this.label,
    this.semanticsLabel,
  });

  final String value;
  final String label;
  final String? semanticsLabel;
}

class ObjectOfferMetricsStrip extends StatelessWidget {
  const ObjectOfferMetricsStrip({super.key, required this.metrics})
    : assert(metrics.length > 1);

  final List<ObjectOfferMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RechargeTheme.objectOfferCardSurface,
        border: Border.all(color: RechargeTheme.objectOfferSoftBorder),
        borderRadius: BorderRadius.circular(
          RechargeTheme.objectOfferMetricsRadius,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: RechargeTheme.objectOfferCardShadow,
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 70),
        child: IntrinsicHeight(
          child: Row(
            children: <Widget>[
              for (int index = 0; index < metrics.length; index++) ...<Widget>[
                if (index > 0) const _ObjectOfferMetricDivider(),
                Expanded(child: _ObjectOfferMetricCell(data: metrics[index])),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ObjectOfferMetricDivider extends StatelessWidget {
  const _ObjectOfferMetricDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: VerticalDivider(
        width: 1,
        color: RechargeTheme.objectOfferMetricDivider,
      ),
    );
  }
}

class _ObjectOfferMetricCell extends StatelessWidget {
  const _ObjectOfferMetricCell({required this.data});

  final ObjectOfferMetricData data;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: data.semanticsLabel == null
          ? null
          : '${data.semanticsLabel}, ${data.label}',
      excludeSemantics: data.semanticsLabel != null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            data.value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: RechargeTheme.emerald900,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: RechargeTheme.objectOfferSecondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class ObjectOfferHeroActionButton extends StatelessWidget {
  const ObjectOfferHeroActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ObjectOfferHeroActionSurface(
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 21),
        color: RechargeTheme.objectOfferPrimaryText,
      ),
    );
  }
}

class ObjectOfferHeroActionSurface extends StatelessWidget {
  const ObjectOfferHeroActionSurface({
    super.key,
    required this.child,
    this.endPadding = 8,
  });

  final Widget child;
  final double endPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: endPadding),
      child: Material(
        color: RechargeTheme.objectOfferCardSurface,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: RechargeTheme.objectOfferHeroActionShadow,
        child: child,
      ),
    );
  }
}

class ObjectOfferUtilityActionData {
  const ObjectOfferUtilityActionData({
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
}

class ObjectOfferUtilityMenu extends StatelessWidget {
  const ObjectOfferUtilityMenu({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.actions,
  }) : assert(actions.length > 0);

  final String tooltip;
  final IconData icon;
  final List<ObjectOfferUtilityActionData> actions;

  @override
  Widget build(BuildContext context) {
    return ObjectOfferHeroActionSurface(
      endPadding: 12,
      child: PopupMenuButton<int>(
        tooltip: tooltip,
        icon: Icon(icon, size: 21),
        color: RechargeTheme.objectOfferCardSurface,
        onSelected: (int index) => actions[index].onSelected(),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
          for (int index = 0; index < actions.length; index++)
            PopupMenuItem<int>(
              value: index,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(actions[index].icon),
                title: Text(actions[index].label),
              ),
            ),
        ],
      ),
    );
  }
}

class ObjectOfferStickyActionShell extends StatelessWidget {
  const ObjectOfferStickyActionShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: RechargeTheme.objectOfferScreenBackground,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            RechargeTheme.objectOfferHorizontalPadding,
            14,
            RechargeTheme.objectOfferHorizontalPadding,
            14,
          ),
          child: SizedBox(
            height: RechargeTheme.objectOfferStickyActionHeight,
            child: child,
          ),
        ),
      ),
    );
  }
}
