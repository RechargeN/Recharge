import 'package:flutter/widgets.dart';

/// The padding of a page's main scroll list that keeps its end clear of the
/// system navigation bar.
///
/// An explicit `ListView.padding` replaces the automatic safe-area padding,
/// and on edge-to-edge Android (15+) the last control then sits under the
/// navigation bar (N4b, A34 2026-11-15: Settings → Sign out). Inside a shell
/// Scaffold with a bottom navigation bar the inset is already consumed, so this
/// adds nothing there.
EdgeInsets pageListPadding(BuildContext context, EdgeInsets padding) => padding
    .copyWith(bottom: padding.bottom + MediaQuery.paddingOf(context).bottom);
