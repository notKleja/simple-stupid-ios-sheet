import 'package:flutter/foundation.dart';

/// Fork-private lifecycle observation, absent from engine exports.
@immutable
class SheetControllerLifecycleCallbacks {
  /// Creates an immutable callback bundle for one route registration.
  const SheetControllerLifecycleCallbacks({
    this.onDragStart,
    this.onDragEnd,
    this.onDragCancel,
    this.onProgrammaticDetentStart,
  });

  /// Observes acquired sheet ownership before Navigator gesture callbacks.
  final VoidCallback? onDragStart;

  /// Observes coherent normal release after sheet ownership has cleared.
  final VoidCallback? onDragEnd;

  /// Observes recognizer cancellation or detector teardown after release.
  final VoidCallback? onDragCancel;

  /// Runs after construction and before engine mutation. False chooses the
  /// caller's validated already-resting shortcut; exceptions reject the start.
  final bool Function()? onProgrammaticDetentStart;
}

class _LifecycleRegistration {
  _LifecycleRegistration(this.callbacks);

  final token = Object();
  SheetControllerLifecycleCallbacks? callbacks;
}

// Expando owns weak route keys without an enumerable global route collection.
// Clearing a registration also drops its callback bundle while the route lives.
final _registrations =
    Expando<_LifecycleRegistration>('sheet controller lifecycle');

/// Replaces observation for [route] and returns token-scoped unregistration.
VoidCallback registerSheetControllerLifecycle(
  Object route,
  SheetControllerLifecycleCallbacks callbacks,
) {
  _registrations[route]?.callbacks = null;
  final current = _LifecycleRegistration(callbacks);
  _registrations[route] = current;
  return () {
    current.callbacks = null;
    if (identical(_registrations[route]?.token, current.token)) {
      _registrations[route] = null;
    }
  };
}

/// Invalidates all observation for [route] as a final teardown fallback.
void clearSheetControllerLifecycle(Object route) {
  _registrations[route]?.callbacks = null;
  _registrations[route] = null;
}

/// Dispatches acquired ownership to the current registration, if present.
void dispatchSheetDragStart(Object route) =>
    _registrations[route]?.callbacks?.onDragStart?.call();

/// Dispatches coherent normal release to the current registration.
void dispatchSheetDragEnd(Object route) =>
    _registrations[route]?.callbacks?.onDragEnd?.call();

/// Dispatches coherent cancellation to the current registration.
void dispatchSheetDragCancel(Object route) =>
    _registrations[route]?.callbacks?.onDragCancel?.call();

/// Returns whether constructed programmatic motion should start its ticker.
bool dispatchSheetProgrammaticDetentStart(Object route) =>
    _registrations[route]?.callbacks?.onProgrammaticDetentStart?.call() ?? true;
