import 'package:flutter/material.dart';

import '../theme/app_appearance.dart';

/// Extra scroll extent for pages shown behind the compact floating navigation.
///
/// The page itself still paints and scrolls beneath the glass capsule. Only the
/// end of the scrollable gets this transparent tail, so its final action can be
/// moved completely above the controls.
double floatingNavigationScrollClearance(BuildContext context) {
  final appearance =
      Theme.of(context).extension<AppSurfaceTheme>()?.settings ??
      const AppAppearanceSettings();
  if (!appearance.floatingNavigation ||
      MediaQuery.sizeOf(context).width >= 760) {
    return 0;
  }
  return 82 + MediaQuery.viewPaddingOf(context).bottom;
}
