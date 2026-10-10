import 'package:flutter/cupertino.dart';

import 'detents.dart';
import 'profile.dart';
import 'route.dart';

/// Presents a sheet using the explicit iOS 26 profile.
///
/// The supplied [controller] remains owned by the caller. Use
/// [StupidSimpleIosSheetRoute] directly for advanced trajectory or hit probes.
Future<T?> showIos26Sheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
  List<IosSheetDetent> detents = const [IosSheetDetent.large],
  String? initialDetentIdentifier,
  String? largestUndimmedDetentIdentifier,
  IosSheetController? controller,
  IosSheetContentInteraction contentInteraction =
      IosSheetContentInteraction.resizes,
  IosSheetKeyboardPolicy keyboardPolicy = IosSheetKeyboardPolicy.resize,
  bool draggable = true,
  bool dismissible = true,
  bool interactiveDismissDisabled = false,
  Color backgroundColor = CupertinoColors.systemBackground,
  Color modalBarrierColor = const Color.fromRGBO(0, 0, 0, .2),
  String? barrierLabel,
  ValueChanged<String>? onSelectedDetentChanged,
  VoidCallback? onPresented,
  VoidCallback? onDismissed,
}) {
  final route = StupidSimpleIosSheetRoute<T>(
    child: Builder(builder: builder),
    profile: IosSheetProfile.ios26,
    detents: detents,
    initialDetentIdentifier: initialDetentIdentifier,
    largestUndimmedDetentIdentifier: largestUndimmedDetentIdentifier,
    controller: controller,
    contentInteraction: contentInteraction,
    keyboardPolicy: keyboardPolicy,
    draggable: draggable,
    dismissible: dismissible,
    interactiveDismissDisabled: interactiveDismissDisabled,
    backgroundColor: backgroundColor,
    modalBarrierColor: modalBarrierColor,
    barrierLabel: barrierLabel,
    onSelectedDetentChanged: onSelectedDetentChanged,
    onPresented: onPresented,
    onDismissed: onDismissed,
    settings: routeSettings,
  );
  return Navigator.of(context, rootNavigator: useRootNavigator).push(route);
}
