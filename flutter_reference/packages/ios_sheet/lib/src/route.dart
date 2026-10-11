import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show precisionErrorTolerance;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:ios_sheet_engine/ios_sheet_engine.dart';
// Intentional private seam in the jointly maintained engine fork.
// ignore: implementation_imports
import 'package:ios_sheet_engine/src/controller_lifecycle_bridge.dart'
    as lifecycle;

import 'detents.dart';
import 'environment.dart';
import 'profile.dart';
import 'state.dart';
import 'motion.dart';
import 'presentation.dart';
import 'trace.dart';

const iosSheetSurfaceKey = ValueKey('ios-sheet-opaque-surface');

enum IosSheetContentInteraction { resizes, scrolls }

enum IosSheetKeyboardPolicy { resize, overlay }

/// Controls semantic detents without exposing normalized engine positions.
///
/// Supplied controllers remain caller-owned. Disposing an attached controller
/// fails its lifecycle waits and severs observation; Navigator still owns the
/// sheet route. Getters then expose detached defaults and later route events
/// cannot notify this controller. As with ChangeNotifier, disposal from inside
/// its own notification stack must be scheduled after that stack returns.
class IosSheetController extends ChangeNotifier {
  StupidSimpleIosSheetRoute<dynamic>? _route;
  _IosSheetAttachment? _attachment;
  int _generation = 0;
  bool _disposed = false;

  bool get isAttached => _route != null;
  String? get selectedDetentIdentifier => _route?._selectedIdentifier;

  /// Most recently accepted selection, not an inference from current geometry.
  String? get requestedDetentIdentifier => selectedDetentIdentifier;
  String? get targetDetentIdentifier => _route?._engineTargetIdentifier;

  /// Null while moving/dragging; based on engine status and extent tolerance.
  String? get restingDetentIdentifier => _route?._restingIdentifier;
  bool get isPresented => _route?._presented ?? false;
  double get unscaledTrajectoryHeight => _route?.unscaledTrajectoryHeight ?? 0;
  double get unscaledSurfaceHeight => _route?.unscaledSurfaceHeight ?? 0;

  /// Last laid-out surface height in window coordinates, including scale.
  double get renderedSurfaceHeight => _route?.renderedSurfaceHeight ?? 0;

  /// Last laid-out surface intersected with the viewport.
  double get renderedVisibleHeight => _route?.renderedVisibleHeight ?? 0;
  double get visibleHeight => renderedVisibleHeight;
  bool get isModal => _route?.isModal ?? false;

  /// Waits for the attached sheet's first settled presentation.
  ///
  /// Captures the current attachment, never a future attachment. Success means
  /// engine rest at a configured detent with no animation or sheet drag, not a
  /// final paint receipt or top-route visibility. Presentation remains latched
  /// during later motion or coverage. Already presented completes without
  /// another frame. Detached/disposed calls return a StateError future rather
  /// than throwing; removal before presentation or controller disposal also
  /// fails the captured wait. Future observers always run asynchronously.
  Future<void> whenPresented() {
    if (_disposed)
      return Future<void>.error(StateError('Sheet controller is disposed'));
    final attachment = _attachment;
    if (attachment == null)
      return Future<void>.error(StateError('Sheet controller is detached'));
    return attachment.whenPresented();
  }

  /// Waits until the attached sheet releases this controller at route disposal.
  ///
  /// Captures the current attachment. Coverage, accepted dismissal, and the
  /// Navigator pop-result future do not detach. Already detached completes
  /// without another frame; reuse cannot change an old wait's outcome.
  /// Disposing an attached controller fails this wait with StateError rather
  /// than claiming route disposal; disposed calls also return failed futures.
  /// Observers run asynchronously after synchronous detachment listeners and
  /// onDismissed have returned or thrown.
  Future<void> whenDetached() {
    if (_disposed)
      return Future<void>.error(StateError('Sheet controller is disposed'));
    return _attachment?.whenDetached() ?? Future<void>.value();
  }

  /// Capture after layout/paint, typically from a post-frame callback.
  IosSheetFrame captureFrame() {
    final route = _route;
    if (route == null) throw StateError('Sheet controller is detached');
    return route.captureFrame();
  }

  IosSheetState snapshotState() {
    final route = _route;
    if (route == null) throw StateError('Sheet controller is detached');
    return route.snapshotState();
  }

  void beginUnderlyingControlProbe({
    required String probeIdentifier,
    required String controlIdentifier,
    required Offset position,
  }) {
    final route = _route;
    if (route == null) throw StateError('Sheet controller is detached');
    route._beginUnderlyingProbe(probeIdentifier, controlIdentifier, position);
  }

  void recordUnderlyingControlActivation(String identifier) =>
      _route?._underlyingProbe?.recordControlActivation(identifier);
  IosSheetUnderlyingHitObservation? completeUnderlyingControlProbe() =>
      _route?._completeUnderlyingProbe();

  void selectDetent(String identifier) {
    final route = _route;
    if (route == null) throw StateError('Sheet controller is detached');
    route.selectDetent(identifier);
  }

  /// Accepts the same semantic selection as selectDetent and awaits its outcome.
  ///
  /// Getters and selection callbacks update synchronously. Returns true only
  /// while this request remains current, its ticker finishes without canceling,
  /// and the requested semantic identifier rests. A validated already-resting
  /// request succeeds without a ticker or another frame. Equal-height detents
  /// remain distinct identifiers.
  ///
  /// Returns false on accepted supersession, sheet drag ownership, coverage,
  /// dismissal, logical removal, detachment, disposal, or ticker cancellation.
  /// A command accepted during an existing sheet drag also returns false.
  /// False does not roll back selection or stop the underlying motion.
  ///
  /// Validation and trajectory construction failures throw synchronously in
  /// the same order as selectDetent. A rejected command preserves older motion
  /// unless user code reentrantly accepted another command. Future observers
  /// always run asynchronously; completion does not guarantee final paint.
  Future<bool> animateToDetent(String identifier) {
    final route = _route;
    if (route == null) throw StateError('Sheet controller is detached');
    return route._selectDetent(identifier, awaitable: true)!;
  }

  /// Explicit dismissal is allowed even when interactive dismissal is locked.
  void dismiss([Object? result]) {
    final route = _route;
    if (route == null) throw StateError('Sheet controller is detached');
    if (!route.isCurrent) throw StateError('Sheet is covered by another route');
    route._requireOpeningCompleted();
    route.navigator?.pop(result);
  }

  /// @nodoc
  @override
  void dispose() {
    // ChangeNotifier validates its notification-stack precondition first.
    // A rejected debug disposal must not abandon a still-live attachment.
    super.dispose();
    _disposed = true;
    final route = _route;
    final attachment = _attachment;
    _route = null;
    _attachment = null;
    if (route != null && attachment != null) {
      route._abandonController(this, attachment);
      attachment.abandon();
    }
  }

  _IosSheetAttachment _attach(StupidSimpleIosSheetRoute<dynamic> route) {
    if (_disposed) throw StateError('Sheet controller is disposed');
    if (_route != null) throw StateError('Controller already has a sheet');
    final attachment = _IosSheetAttachment(++_generation, route);
    _route = route;
    _attachment = attachment;
    return attachment;
  }

  bool _owns(
    _IosSheetAttachment attachment,
    StupidSimpleIosSheetRoute<dynamic> route,
  ) =>
      !_disposed &&
      identical(_route, route) &&
      identical(_attachment, attachment) &&
      attachment.generation == _generation;

  void _changed(StupidSimpleIosSheetRoute<dynamic> route) {
    if (!_disposed && identical(_route, route)) notifyListeners();
  }

  void _detach(StupidSimpleIosSheetRoute<dynamic> route) {
    if (!_disposed && identical(_route, route)) {
      final attachment = _attachment!;
      _route = null;
      _attachment = null;
      attachment.detach();
      notifyListeners();
    }
  }
}

// Error outcomes are stored without eagerly creating unobserved error futures.
// Each normal completer is allocated only when that attachment is observed.
class _IosSheetAttachment {
  _IosSheetAttachment(this.generation, this.route);
  final int generation;
  final StupidSimpleIosSheetRoute<dynamic> route;
  bool _presented = false;
  bool _detached = false;
  StateError? _presentationFailure;
  StateError? _detachmentFailure;
  Completer<void>? _presentation;
  Completer<void>? _detachment;

  Future<void> whenPresented() {
    final completer = _presentation ??= Completer<void>();
    if (!completer.isCompleted) {
      if (_presented) {
        completer.complete();
      } else if (_presentationFailure != null) {
        completer.completeError(_presentationFailure!);
      }
    }
    return completer.future;
  }

  Future<void> whenDetached() {
    final completer = _detachment ??= Completer<void>();
    if (!completer.isCompleted) {
      if (_detachmentFailure != null) {
        completer.completeError(_detachmentFailure!);
      } else if (_detached) {
        completer.complete();
      }
    }
    return completer.future;
  }

  void present() {
    if (_presented || _presentationFailure != null) return;
    _presented = true;
    _presentation?.complete();
  }

  void remove() {
    if (_presented || _presentationFailure != null) return;
    _presentationFailure = StateError('Sheet removed before presentation');
    _presentation?.completeError(_presentationFailure!);
  }

  void detach() {
    if (_detached || _detachmentFailure != null) return;
    _detached = true;
    remove();
    _detachment?.complete();
  }

  void abandon() {
    if (!_presented && _presentationFailure == null) {
      _presentationFailure = StateError('Sheet controller is disposed');
      _presentation?.completeError(_presentationFailure!);
    }
    if (!_detached && _detachmentFailure == null) {
      _detachmentFailure = StateError('Sheet controller is disposed');
      _detachment?.completeError(_detachmentFailure!);
    }
  }
}

class _IosSheetSelection {
  _IosSheetSelection(
    this.identifier,
    this.attachment,
    this.revision,
    this.preRest,
    this.awaitable,
  );
  final String identifier;
  final _IosSheetAttachment? attachment;
  int revision;
  final String? preRest;
  final bool awaitable;
  bool accepted = false;
  bool starting = true;
  _IosSheetMotion? operation;
}

class _IosSheetMotion {
  final Completer<bool> result = Completer<bool>();
  void settle(bool success) {
    if (!result.isCompleted) result.complete(success);
  }
}

// Arbitrary custom Simulation methods may reenter while animateWith samples
// its initial value. Fence that startup before Flutter can start an old ticker.
class _IosSheetStartupSimulation extends Simulation {
  _IosSheetStartupSimulation(this.inner, this.validate);
  final Simulation inner;
  final VoidCallback validate;
  @override
  double x(double time) {
    validate();
    final value = inner.x(time);
    validate();
    return value;
  }

  @override
  double dx(double time) {
    validate();
    final value = inner.dx(time);
    validate();
    return value;
  }

  @override
  bool isDone(double time) {
    validate();
    final done = inner.isDone(time);
    validate();
    return done;
  }
}

/// Opaque iOS semantics over the flexible upstream transition engine.
///
/// Profile defaults are explicit, unmeasured research fallbacks. This route
/// never invokes the glass route or its rendering implementation.
class StupidSimpleIosSheetRoute<T> extends PopupRoute<T>
    with StupidSimpleSheetTransitionMixin<T>, StupidSimpleSheetController<T> {
  StupidSimpleIosSheetRoute({
    required this.child,
    required this.profile,
    List<IosSheetDetent> detents = const [IosSheetDetent.large],
    this.initialDetentIdentifier,
    this.largestUndimmedDetentIdentifier,
    IosSheetController? controller,
    this.contentInteraction = IosSheetContentInteraction.resizes,
    this.keyboardPolicy = IosSheetKeyboardPolicy.resize,
    this.draggable = true,
    this.dismissible = true,
    this.interactiveDismissDisabled = false,
    this.backgroundColor = CupertinoColors.systemBackground,
    this.modalBarrierColor = const Color.fromRGBO(0, 0, 0, .2),
    String? barrierLabel,
    this.onSelectedDetentChanged,
    this.onPresented,
    this.onDismissed,
    this.trajectoryModel,
    this.onUnderlyingHitObserved,
    super.settings,
  }) : detents = List.unmodifiable(detents),
       _barrierLabel = barrierLabel,
       _sheetController = controller {
    if (detents.isEmpty) throw ArgumentError('At least one detent is required');
    final ids = detents.map((e) => e.identifier).toSet();
    for (final identifier in [
      initialDetentIdentifier,
      largestUndimmedDetentIdentifier,
    ]) {
      if (identifier != null && !ids.contains(identifier)) {
        throw ArgumentError('Unknown detent: $identifier');
      }
    }
  }

  final Widget child;
  final IosSheetProfile profile;
  final List<IosSheetDetent> detents;
  final String? initialDetentIdentifier;
  final String? largestUndimmedDetentIdentifier;
  IosSheetController? _sheetController;
  _IosSheetAttachment? _attachment;
  VoidCallback? _unregisterLifecycle;
  Object? _lifecycleToken;
  final IosSheetContentInteraction contentInteraction;
  final IosSheetKeyboardPolicy keyboardPolicy;
  @override
  final bool draggable;
  final bool dismissible;
  final bool interactiveDismissDisabled;
  final Color backgroundColor;
  final Color modalBarrierColor;
  final String? _barrierLabel;
  final ValueChanged<String>? onSelectedDetentChanged;
  final VoidCallback? onPresented;
  final VoidCallback? onDismissed;
  final IosSheetTrajectoryModel? trajectoryModel;
  final ValueChanged<IosSheetUnderlyingHitObservation>? onUnderlyingHitObserved;
  IosSheetUnderlyingControlProbe? _underlyingProbe;
  IosSheetUnderlyingHitObservation? _underlyingObservation;
  IosSheetMotionRequest? _motionRequest;
  IosSheetTrajectory? _trajectory;
  _IosSheetSelection? _selectionAttempt;
  _IosSheetMotion? _detentMotion;
  int _selectionRevision = 0;

  String? _selectedIdentifier;
  String? _targetIdentifier;
  bool _presented = false;
  double? _dismissStartExtent;
  bool _dismissing = false;
  bool _removing = false;
  bool _disposing = false;
  Object? _popAttempt;
  final _activePointers = <int>{};
  final _surfaceProbe = GlobalKey();
  _IosSheetRenderedSurface? _renderedSurface;

  double get _transitionFraction {
    final fixedTransition =
        profile.fixedSurfaceDuringTransition &&
        (!_presented || _dismissStartExtent != null);
    final extent = _layoutExtent;
    return fixedTransition && extent > 0
        ? (controller!.value / extent).clamp(0.0, 1.0)
        : 1;
  }

  IosSheetGeometry get currentGeometry => profile.geometry(
    IosSheetGeometryContext(
      environment: environment,
      visibleHeight: _layoutExtent * _referenceHeight,
      progress: _layoutExtent,
      velocity: controller?.velocity ?? 0,
      transitionFraction: _transitionFraction,
    ),
  );

  double get _layoutExtent {
    if (!profile.fixedSurfaceDuringTransition) return controller?.value ?? 0;
    return _dismissStartExtent ??
        (!_presented ? snappingConfig.initialSnap : controller!.value);
  }

  bool get _openingLocked =>
      profile.fixedSurfaceDuringTransition && !_presented;

  void _requireOpeningCompleted() {
    if (_openingLocked) {
      throw StateError(
        'This profile does not support retargeting or dismissal '
        'during fixed-surface presentation',
      );
    }
  }

  String? _identifierAt(double? extent) {
    if (extent == null) return null;
    final matches = resolvedDetents.where(
      (e) => (_engineExtent(e) - extent).abs() < 0.000001,
    );
    return matches
            .where((e) => e.identifier == _targetIdentifier)
            .firstOrNull
            ?.identifier ??
        matches.firstOrNull?.identifier;
  }

  String? get _engineTargetIdentifier => _dismissing || isUserDragging
      ? null
      : _identifierAt(targetRelativePosition);

  String? get _restingIdentifier =>
      controller == null ||
          controller!.isAnimating ||
          isUserDragging ||
          !_presented ||
          _dismissing
      ? null
      : _identifierAt(controller!.value);

  void _synchronizeEngineSelection() {
    _targetIdentifier = _engineTargetIdentifier;
    if (_targetIdentifier != null && _selectedIdentifier != _targetIdentifier) {
      _selectedIdentifier = _targetIdentifier;
      onSelectedDetentChanged?.call(_selectedIdentifier!);
    }
  }

  Rect? get _renderedRect => _renderedSurface?.bounds;

  double get renderedSurfaceHeight => _renderedRect?.height ?? 0;
  double get renderedVisibleHeight {
    final bounds = _renderedRect;
    if (bounds == null) return 0;
    return math.max(
      0,
      math.min(
            bounds.bottom,
            _renderedSurface!.environment.availableSize.height,
          ) -
          math.max(0, bounds.top),
    );
  }

  /// Pure observation. Semantic synchronization remains in animation handling.
  IosSheetState snapshotState() {
    final bounds = _renderedRect;
    if (bounds == null) {
      throw StateError('Sheet has not completed layout');
    }
    final rendered = _renderedSurface!;
    final corners = rendered.geometry.cornerResolution;
    return IosSheetState(
      frame: bounds,
      velocity: null,
      phase: _dismissing
          ? IosSheetPhase.dismissing
          : !isActive
          ? IosSheetPhase.dismissed
          : !_presented
          ? IosSheetPhase.presenting
          : isUserDragging
          ? IosSheetPhase.dragging
          : controller!.isAnimating
          ? IosSheetPhase.snapping
          : IosSheetPhase.presented,
      selectedDetent: _selectedIdentifier,
      targetDetent: _engineTargetIdentifier,
      restingDetent: _restingIdentifier,
      gesture: _activePointers.isEmpty
          ? IosSheetGestureState.none
          : IosSheetGestureState.touch,
      sheetDragging: isUserDragging,
      scroll: const IosSheetScrollObservation(),
      environment: rendered.environment,
      motionRequest: _motionRequest,
      motionTargetPoints: _trajectory?.targetPoints,
      presentation: presentationState,
      capabilities: {
        'rendered_frame': IosSheetCapabilityStatus.observed,
        'profile': profile.isMeasured
            ? IosSheetCapabilityStatus.accepted
            : IosSheetCapabilityStatus.fallback,
        'motion': _trajectory?.capability ?? IosSheetCapabilityStatus.fallback,
        'corners': corners?.radii == null
            ? IosSheetCapabilityStatus.unavailable
            : IosSheetCapabilityStatus.observed,
        'rendered_contour': IosSheetCapabilityStatus.unavailable,
        'velocity': IosSheetCapabilityStatus.unavailable,
        'scroll': IosSheetCapabilityStatus.unavailable,
      },
      provenance: {
        ...profile.evidence,
        if (_trajectory != null) 'motion': _trajectory!.provenance,
        'frame':
            'geometry and window bounds atomically observed at completed Flutter surface paint; not compositor pixels',
        'velocity':
            'screen velocity not observed; normalized engine velocity is not substituted',
        'corners':
            corners?.provenance ??
            corners?.reason ??
            'four-corner resolver not connected; legacy shape remains a fallback',
        'rendered_contour':
            'Flutter continuous shape approximation; native rendered contour unresolved',
        'scroll': 'scroll observation adapter not attached',
        'keyboard':
            'MediaQuery obscured inset observed; full keyboard frame unavailable',
        'traits':
            'size classes/content category/stack depth unavailable without platform or stack adapters',
      },
    );
  }

  IosSheetFrame captureFrame() {
    final observed = snapshotState();
    final bounds = observed.frame;
    final topLeft = bounds.topLeft;
    final bottomRight = bounds.bottomRight;
    final size = bounds.size;
    final env = observed.environment;
    // Trace exactly the last painted geometry, not a recomputed live-controller
    // shape paired with an older laid-out surface rectangle.
    final geometry = _renderedSurface!.geometry;
    final corners = geometry.cornerResolution;
    final radii = corners?.radii;
    final selected = resolvedDetents
        .where((e) => e.identifier == observed.selectedDetent)
        .firstOrNull;
    return IosSheetFrame(
      metrics: {
        'sheet.x': topLeft.dx,
        'sheet.y': topLeft.dy,
        'sheet.width': size.width,
        'sheet.height': size.height,
        'sheet.visible_height': renderedVisibleHeight,
        'sheet.top': topLeft.dy,
        'sheet.bottom': bottomRight.dy,
        'sheet.left_inset': topLeft.dx,
        'sheet.right_inset': env.availableSize.width - bottomRight.dx,
        'sheet.bottom_inset': env.availableSize.height - bottomRight.dy,
        'sheet.detent_height': selected?.height,
        'sheet.radius': geometry.shape == null
            ? geometry.cornerRadius * geometry.scale
            : null,
        'sheet.radius.top_left': radii?.topLeft.x,
        'sheet.radius.top_right': radii?.topRight.x,
        'sheet.radius.bottom_right': radii?.bottomRight.x,
        'sheet.radius.bottom_left': radii?.bottomLeft.x,
        'sheet.relative_progress': controller!.value,
        'sheet.trajectory_height_unscaled': unscaledTrajectoryHeight,
        'sheet.surface_height_unscaled': unscaledSurfaceHeight,
        'barrier.alpha': observed.presentation!.effectiveBarrierAlpha,
        'sheet.velocity_y': null,
        'finger.velocity_y': null,
        'scroll.offset': null,
      },
      state: {
        'selected_detent': observed.selectedDetent,
        'target_detent': observed.targetDetent,
        'gesture': observed.gesture == IosSheetGestureState.none
            ? 'none'
            : 'touch',
        'scroll_owner': null,
        'underlying_hit_test': _underlyingObservation?.activated,
        'dismissed': !isActive,
        'surface': 'opaque',
        'shape': geometry.shape == null ? 'rounded_superellipse' : 'custom',
      },
      unavailable: {
        'sheet.velocity_y': 'derive from consecutive observed screen positions',
        'finger.velocity_y': 'pointer recorder not attached',
        'scroll.offset': 'scroll recorder not attached',
        'scroll_owner': 'gesture ownership instrumentation pending',
        if (_underlyingObservation == null)
          'underlying_hit_test':
              'no completed actually delivered underlying control probe',
        if (observed.targetDetent == null)
          'target_detent': _dismissing
              ? 'Dismissal has no configured detent target'
              : 'No committed configured snap target while dragging or retargeting',
        if (geometry.shape != null)
          'sheet.radius': 'custom shape cannot be represented by one scalar',
        if (radii == null)
          for (final corner in [
            'top_left',
            'top_right',
            'bottom_right',
            'bottom_left',
          ])
            'sheet.radius.$corner':
                corners?.reason ??
                'Native four-corner model unavailable; legacy shape fallback only',
      },
      implementationProvenance: {
        'corner_model_status': corners?.status.name ?? 'unavailable',
        'corner_model_units': 'logical_points_model_configuration',
        if (corners?.provenance != null) 'corner_model': corners!.provenance,
        if (radii == null)
          'corner_fallback':
              'visible configured upstream radius${geometry.cornerRadius}; not native measured',
        'rendered_contour_status': 'unavailable',
        'rendered_contour_reason':
            'closest supported Flutter continuous four-corner shape; native contour unresolved',
        'resting_detent': observed.restingDetent,
        'resting_detector': 'engine not animating, no drag, extent epsilon1e-6',
        'sheet_gesture': observed.sheetDragging ? 'dragging' : 'idle',
        'pointer_observation_scope': 'delivered pointers inside sheet content',
        if (_underlyingObservation != null)
          'underlying_hit_test_scope':
              'last completed delivered tap/control activation probe, not a continuous mask',
      },
    );
  }

  IosSheetEnvironment get environment {
    final media = MediaQuery.of(navigator!.context);
    final renderObject = navigator!.context.findRenderObject();
    final size = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.size
        : media.size;
    final keyboard = keyboardPolicy == IosSheetKeyboardPolicy.resize
        ? media.viewInsets.bottom
        : 0.0;
    final base = IosSheetEnvironment(
      availableSize: size,
      maximumDetentHeight: math.max(
        1,
        size.height - media.padding.top - keyboard,
      ),
      safeArea: media.viewPadding,
      keyboardHeight: keyboard,
      observedKeyboardHeight: media.viewInsets.bottom,
      displayScale: media.devicePixelRatio,
      orientation: size.width == size.height
          ? IosSheetOrientation.unknown
          : size.height > size.width
          ? IosSheetOrientation.portrait
          : IosSheetOrientation.landscape,
      textScale:
          media.textScaler == TextScaler.linear(media.textScaler.scale(1))
          ? media.textScaler.scale(1)
          : null,
      reduceMotion: media.disableAnimations,
      platformBrightness: media.platformBrightness,
      locale: Localizations.maybeLocaleOf(navigator!.context),
      textDirection: Directionality.maybeOf(navigator!.context),
      stack: IosSheetStackContext(isTopmost: isCurrent),
    );
    return base.withMaximumDetentHeight(profile.maximumDetentHeight(base));
  }

  double get _referenceHeight => profile.detentToVisibleHeight(
    environment.maximumDetentHeight,
    environment,
  );

  double _engineExtent(ResolvedIosDetent detent) =>
      profile.detentToVisibleHeight(detent.height, environment) /
      _referenceHeight;

  List<ResolvedIosDetent> get resolvedDetents =>
      resolveIosDetents(detents, environment: environment, profile: profile);

  double get unscaledTrajectoryHeight =>
      (controller?.value ?? 0) * _referenceHeight;
  double get unscaledSurfaceHeight => _layoutExtent * _referenceHeight;
  double get visibleHeight => renderedVisibleHeight;

  bool get isModal {
    final identifier = largestUndimmedDetentIdentifier;
    if (identifier == null) return true;
    final threshold = resolvedDetents.firstWhere(
      (e) => e.identifier == identifier,
    );
    final thresholdHeight = profile.detentToVisibleHeight(
      threshold.height,
      environment,
    );
    return unscaledTrajectoryHeight > thresholdHeight + 0.000001;
  }

  IosSheetPresentationState get presentationState => IosSheetPresentationState(
    effectiveBarrierAlpha: isModal ? modalBarrierColor.a : 0,
    underlyingPointerEligible: !isModal,
    underlyingSemanticsEligible: !isModal,
    sheetBounds: _renderedRect,
    capability: IosSheetCapabilityStatus.fallback,
    provenance:
        'existing largest-undimmed threshold and configured alpha; unmeasured fallback, no native curve',
  );
  void _beginUnderlyingProbe(
    String probeIdentifier,
    String controlIdentifier,
    Offset position,
  ) {
    if (_underlyingProbe != null)
      throw StateError('Underlying control probe already active');
    _underlyingProbe = IosSheetUnderlyingControlProbe(
      probeIdentifier: probeIdentifier,
      controlIdentifier: controlIdentifier,
      position: position,
      viewId: View.of(navigator!.context).viewId,
    );
  }

  IosSheetUnderlyingHitObservation? _completeUnderlyingProbe() {
    final observed = _underlyingProbe?.complete();
    _underlyingProbe = null;
    if (observed != null) {
      _underlyingObservation = observed;
      onUnderlyingHitObserved?.call(observed);
    }
    return observed;
  }

  @override
  Motion get motion => profile.motion;

  @override
  Simulation createSheetSimulation({
    required SheetSimulationPhase phase,
    required double start,
    required double end,
    required double velocity,
    double? dragReleaseVelocity,
  }) {
    final attempt = phase == SheetSimulationPhase.detentSnap
        ? _selectionAttempt
        : null;
    final height = _referenceHeight;
    final currentPosition = controller?.value ?? start;
    final currentVelocity = controller?.velocity ?? velocity;
    final request = IosSheetMotionRequest(
      kind: switch (phase) {
        SheetSimulationPhase.presentation => IosSheetMotionKind.presentation,
        SheetSimulationPhase.detentSnap => IosSheetMotionKind.detentSnap,
        SheetSimulationPhase.overdragReturn =>
          IosSheetMotionKind.overdragReturn,
        SheetSimulationPhase.dismissal => IosSheetMotionKind.dismissal,
      },
      positionPoints: currentPosition * height,
      velocityPointsPerSecond:
          (dragReleaseVelocity ?? currentVelocity) * height,
      targetPoints: end * height,
      referenceHeightPoints: height,
      dragReleaseVelocityPointsPerSecond: dragReleaseVelocity == null
          ? null
          : dragReleaseVelocity * height,
      velocitySource: dragReleaseVelocity == null
          ? IosSheetVelocitySource.controller
          : IosSheetVelocitySource.dragRelease,
      environment: environment,
    );
    final trajectory =
        (trajectoryModel ?? FallbackIosSheetTrajectoryModel(motion))
            .createTrajectory(request);
    final initialPosition = trajectory.simulation.x(0);
    final initialVelocity = trajectory.simulation.dx(0);
    if (attempt != null) _requireSelectionOwner(attempt);
    if (trajectory.targetPoints != request.targetPoints ||
        !initialPosition.isFinite ||
        !initialVelocity.isFinite ||
        (initialPosition - request.positionPoints).abs() >
            precisionErrorTolerance ||
        (initialVelocity - request.velocityPointsPerSecond).abs() >
            precisionErrorTolerance) {
      throw StateError(
        'Trajectory must preserve the requested target, initial position, '
        'and initial velocity',
      );
    }
    _motionRequest = request;
    _trajectory = trajectory;
    final normalized = normalizeIosSheetTrajectory(trajectory, height);
    if (attempt == null) return normalized;
    // Controller-less legacy route commands need no persistent registration.
    if (_lifecycleToken == null) _acceptSelection(attempt);
    return _IosSheetStartupSimulation(normalized, () {
      if (attempt.starting) _requireSelectionOwner(attempt);
    });
  }

  @override
  bool get resistBoundaryCrossing => profile.dragResistance != null;
  @override
  double resistedDragDelta(double delta, double position, double boundary) {
    final resolver = profile.dragResistance;
    if (resolver == null)
      return super.resistedDragDelta(delta, position, boundary);
    return resolver(
          IosSheetResistanceContext(
            positionPoints: position * _referenceHeight,
            boundaryPoints: boundary * _referenceHeight,
            input: delta * _referenceHeight,
            referenceHeight: _referenceHeight,
          ),
        ) /
        _referenceHeight;
  }

  @override
  double resistedReleaseVelocity(
    double velocity,
    double position,
    double boundary,
    double maxExtent,
  ) {
    final resolver = profile.releaseResistance;
    if (resolver == null)
      return super.resistedReleaseVelocity(
        velocity,
        position,
        boundary,
        maxExtent,
      );
    return resolver(
          IosSheetResistanceContext(
            positionPoints: position * _referenceHeight,
            boundaryPoints: boundary * _referenceHeight,
            input: velocity * _referenceHeight,
            referenceHeight: _referenceHeight,
          ),
        ) /
        _referenceHeight;
  }

  @override
  bool get expandsWhenScrolledToEdge =>
      contentInteraction == IosSheetContentInteraction.resizes;
  @override
  DismissalMode get dismissalMode => DismissalMode.shrink;
  @override
  bool get originateAboveBottomViewInset =>
      keyboardPolicy == IosSheetKeyboardPolicy.resize;
  @override
  bool get clearBarrierImmediately => false;
  @override
  Color get barrierColor => modalBarrierColor;
  @override
  bool get barrierDismissible => dismissible && !interactiveDismissDisabled;
  @override
  String get barrierLabel => _barrierLabel ?? 'Dismiss sheet';
  @override
  bool get maintainState => true;
  @override
  RoutePopDisposition get popDisposition =>
      dismissible && !interactiveDismissDisabled && !_openingLocked
      ? super.popDisposition
      : RoutePopDisposition.doNotPop;

  @override
  SheetSnappingConfig get snappingConfig {
    final resolved = resolvedDetents;
    final initial = initialDetentIdentifier == null
        ? resolved.first
        : resolved.firstWhere((e) => e.identifier == initialDetentIdentifier);
    return SheetSnappingConfig(
      resolved.map(_engineExtent).toList(),
      initialSnap: _engineExtent(initial),
      physics: profile.snapPhysics,
    );
  }

  @override
  void install() {
    super.install();
    _selectedIdentifier =
        initialDetentIdentifier ?? resolvedDetents.first.identifier;
    _targetIdentifier = _selectedIdentifier;
    final attachment = _sheetController?._attach(this);
    _attachment = attachment;
    if (attachment != null) _registerLifecycle(attachment);
    controller!.addListener(_animationChanged);
    controller!.addStatusListener(_statusChanged);
  }

  void _statusChanged(AnimationStatus _) => _animationChanged();

  void _animationChanged() {
    if (_disposing) return;
    _synchronizeEngineSelection();
    _reducePresentation();
    _sheetController?._changed(this);
  }

  void _reducePresentation() {
    if (!controller!.isAnimating &&
        !isUserDragging &&
        isActive &&
        !_removing &&
        !_disposing &&
        _popAttempt == null &&
        !_dismissing) {
      final extent = controller!.value;
      final matches = resolvedDetents.where(
        (e) => (_engineExtent(e) - extent).abs() < 0.000001,
      );
      if (matches.isNotEmpty) {
        // Prefer the requested semantic ID if two detents resolve equally.
        final selected =
            matches
                .where((e) => e.identifier == _targetIdentifier)
                .firstOrNull ??
            matches.first;
        _targetIdentifier = selected.identifier;
        if (!_presented) {
          _presented = true;
          _attachment?.present();
          onPresented?.call();
        }
      }
    }
  }

  void _registerLifecycle(_IosSheetAttachment attachment) {
    final token = Object();
    _lifecycleToken = token;
    bool ownsRegistration() =>
        identical(_lifecycleToken, token) &&
        identical(_attachment, attachment) &&
        identical(attachment.route, this) &&
        (_sheetController?._owns(attachment, this) ?? false) &&
        !_removing &&
        !_disposing;
    void observeRest() {
      if (ownsRegistration()) {
        _reducePresentation();
      }
    }

    _unregisterLifecycle = lifecycle.registerSheetControllerLifecycle(
      this,
      lifecycle.SheetControllerLifecycleCallbacks(
        onDragStart: () {
          if (ownsRegistration()) _interruptSelection();
        },
        onDragEnd: observeRest,
        // Detector teardown can precede route disposal while Navigator's
        // inherited-widget context is inactive. Recheck ownership after that
        // synchronous teardown stack, before resolving environment geometry.
        onDragCancel: () => scheduleMicrotask(observeRest),
        onProgrammaticDetentStart: () {
          if (!ownsRegistration()) return true;
          final attempt = _selectionAttempt;
          if (attempt == null) {
            _interruptSelection();
            return true;
          }
          return _acceptSelection(attempt);
        },
      ),
    );
  }

  void _clearLifecycle() {
    _lifecycleToken = null;
    final unregister = _unregisterLifecycle;
    _unregisterLifecycle = null;
    unregister?.call();
  }

  void _abandonController(
    IosSheetController sheetController,
    _IosSheetAttachment attachment,
  ) {
    if (identical(_sheetController, sheetController) &&
        identical(_attachment, attachment)) {
      _interruptSelection();
      _clearLifecycle();
      _sheetController = null;
      _attachment = null;
    }
  }

  void selectDetent(String identifier) => _selectDetent(identifier);

  bool _selectionOwns(_IosSheetSelection attempt) =>
      attempt.revision == _selectionRevision &&
      identical(attempt.attachment, _attachment) &&
      (attempt.attachment == null ||
          (_sheetController?._owns(attempt.attachment!, this) ?? false)) &&
      isCurrent &&
      !_dismissing &&
      !_removing &&
      !_disposing &&
      _popAttempt == null;

  void _requireSelectionOwner(_IosSheetSelection attempt) {
    if (!_selectionOwns(attempt)) {
      throw StateError('Sheet selection was superseded during construction');
    }
  }

  void _interruptSelection() {
    _selectionRevision++;
    final operation = _detentMotion;
    _detentMotion = null;
    operation?.settle(false);
  }

  bool _acceptSelection(_IosSheetSelection attempt) {
    _requireSelectionOwner(attempt);
    _interruptSelection();
    attempt.revision = _selectionRevision;
    attempt.accepted = true;
    if (attempt.awaitable) {
      final operation = _IosSheetMotion();
      attempt.operation = operation;
      _detentMotion = operation;
      if (isUserDragging) {
        _detentMotion = null;
        operation.settle(false);
      } else if (attempt.preRest == attempt.identifier &&
          _restingIdentifier == attempt.identifier) {
        _detentMotion = null;
        operation.settle(true);
        return false;
      }
    }
    return true;
  }

  Future<bool>? _selectDetent(String identifier, {bool awaitable = false}) {
    final resolved = resolvedDetents.where((e) => e.identifier == identifier);
    if (resolved.isEmpty) throw ArgumentError('Unknown detent: $identifier');
    _requireOpeningCompleted();
    if (!isCurrent || _dismissing || _removing || _disposing)
      throw StateError('Sheet is not current');
    final previousSelection = _selectedIdentifier;
    final previousTarget = _targetIdentifier;
    final previousRequest = _motionRequest;
    final previousTrajectory = _trajectory;
    final previousAttempt = _selectionAttempt;
    final attempt = _IosSheetSelection(
      identifier,
      _attachment,
      _selectionRevision,
      _restingIdentifier,
      awaitable,
    );
    _selectionAttempt = attempt;
    _targetIdentifier = identifier;
    _selectedIdentifier = identifier;
    try {
      final ticker = animateToRelative(_engineExtent(resolved.single));
      attempt.starting = false;
      final operation = attempt.operation;
      if (operation != null) {
        ticker.orCancel
            .then<void>(
              (_) {
                final success =
                    identical(_detentMotion, operation) &&
                    _selectionOwns(attempt) &&
                    _restingIdentifier == identifier;
                if (identical(_detentMotion, operation)) _detentMotion = null;
                operation.settle(success);
              },
              onError: (Object error, StackTrace stack) {
                if (identical(_detentMotion, operation)) _detentMotion = null;
                operation.settle(false);
              },
            )
            .ignore();
      }
    } catch (_) {
      attempt.starting = false;
      if (!attempt.accepted && _selectionOwns(attempt)) {
        _selectedIdentifier = previousSelection;
        _targetIdentifier = previousTarget;
        _motionRequest = previousRequest;
        _trajectory = previousTrajectory;
      }
      attempt.operation?.settle(false);
      if (identical(_detentMotion, attempt.operation)) _detentMotion = null;
      rethrow;
    } finally {
      if (identical(_selectionAttempt, attempt))
        _selectionAttempt = previousAttempt;
    }
    if (_selectionOwns(attempt) && previousSelection != identifier)
      onSelectedDetentChanged?.call(identifier);
    if (_selectionOwns(attempt)) _sheetController?._changed(this);
    return attempt.operation?.result.future;
  }

  @override
  Widget buildContent(BuildContext context) => MediaQuery.removePadding(
    context: context,
    removeTop: true,
    child: Listener(
      onPointerDown: (event) => _activePointers.add(event.pointer),
      onPointerUp: (event) => _activePointers.remove(event.pointer),
      onPointerCancel: (event) => _activePointers.remove(event.pointer),
      child: SizedBox.expand(child: child),
    ),
  );

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => AnimatedBuilder(
    animation: controller!,
    child: super.buildPage(context, animation, secondaryAnimation),
    builder: (_, child) =>
        IgnorePointer(ignoring: _openingLocked, child: child),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AnimatedBuilder(
      animation: controller!,
      child: child,
      builder: (context, child) {
        final env = environment;
        final geometry = currentGeometry;
        final fixedTransition =
            profile.fixedSurfaceDuringTransition &&
            (!_presented || _dismissStartExtent != null);
        final layoutExtent = _layoutExtent;
        final fraction = _transitionFraction;
        final transitionOffset =
            (1 - fraction) *
            (layoutExtent * _referenceHeight * geometry.scale +
                geometry.bottomInset);
        final shape =
            geometry.shape ??
            RoundedSuperellipseBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(geometry.cornerRadius),
              ),
            );
        return Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top,
            left: geometry.sideInset,
            right: geometry.sideInset,
            bottom: env.keyboardHeight,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: Offset(0, transitionOffset - geometry.bottomInset),
              child: Transform.scale(
                alignment: Alignment.bottomCenter,
                scale: geometry.scale,
                child: _IosSheetSurfaceObserver(
                  geometry: geometry,
                  environment: env,
                  onPainted: (rendered) => _renderedSurface = rendered,
                  child: DecoratedBox(
                    key: iosSheetSurfaceKey,
                    decoration: ShapeDecoration(
                      shape: shape,
                      color: CupertinoDynamicColor.resolve(
                        backgroundColor,
                        context,
                      ),
                    ),
                    child: ClipPath(
                      key: _surfaceProbe,
                      clipper: ShapeBorderClipper(shape: shape),
                      child: SheetDismissalTransition(
                        animation: fixedTransition
                            ? AlwaysStoppedAnimation(layoutExtent)
                            : controller!,
                        dismissalMode: dismissalMode,
                        child: maybeSnapshotChild(child!),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget buildModalBarrier() => AnimatedBuilder(
    animation: controller!,
    builder: (context, _) => IosSheetLiveBarrierRouting(
      presentation: () => presentationState,
      child: ExcludeSemantics(
        excluding: presentationState.underlyingSemanticsEligible,
        child: ModalBarrier(
          color: presentationState.effectiveBarrierAlpha > 0
              ? barrierColor
              : null,
          dismissible: barrierDismissible,
          semanticsLabel: barrierLabel,
          onDismiss: () => navigator?.maybePop(),
        ),
      ),
    ),
  );

  @override
  bool didPop(T? result) {
    if (_openingLocked) return false;
    final attempt = Object();
    final previousDismissing = _dismissing;
    final previousTarget = _targetIdentifier;
    final previousExtent = _dismissStartExtent;
    _popAttempt = attempt;
    _dismissing = true;
    _targetIdentifier = null;
    if (profile.fixedSurfaceDuringTransition) {
      _dismissStartExtent = controller!.value;
    }
    void rollback() {
      if (!_removing && identical(_popAttempt, attempt)) {
        _dismissing = previousDismissing;
        _targetIdentifier = previousTarget;
        _dismissStartExtent = previousExtent;
      }
    }

    try {
      final accepted = super.didPop(result);
      if (!accepted) rollback();
      return accepted;
    } catch (_) {
      rollback();
      rethrow;
    } finally {
      if (identical(_popAttempt, attempt)) _popAttempt = null;
    }
  }

  /// @nodoc
  @override
  void didComplete(T? result) {
    _interruptSelection();
    _removing = true;
    _dismissing = true;
    _targetIdentifier = null;
    _attachment?.remove();
    super.didComplete(result);
  }

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    super.didChangeNext(nextRoute);
    if (nextRoute != null || !isCurrent) _interruptSelection();
    _reducePresentation();
  }

  @override
  void didPopNext(Route<dynamic> nextRoute) {
    super.didPopNext(nextRoute);
    _reducePresentation();
  }

  @override
  void dispose() {
    _disposing = true;
    _interruptSelection();
    _clearLifecycle();
    final sheetController = _sheetController;
    final attachment = _attachment;
    _sheetController = null;
    _attachment = null;
    try {
      _underlyingProbe?.dispose();
      _underlyingProbe = null;
      controller?.removeListener(_animationChanged);
      controller?.removeStatusListener(_statusChanged);
      attachment?.remove();
      sheetController?._detach(this);
      onDismissed?.call();
    } finally {
      super.dispose();
    }
  }
}

/// One completed Flutter paint receipt, not a live build-time geometry sample.
/// Atomic assignment prevents mixing a new shape with stale layout bounds.
class _IosSheetRenderedSurface {
  const _IosSheetRenderedSurface({
    required this.geometry,
    required this.bounds,
    required this.environment,
  });
  final IosSheetGeometry geometry;
  final Rect bounds;
  final IosSheetEnvironment environment;
}

class _IosSheetSurfaceObserver extends SingleChildRenderObjectWidget {
  const _IosSheetSurfaceObserver({
    required this.geometry,
    required this.environment,
    required this.onPainted,
    required super.child,
  });
  final IosSheetGeometry geometry;
  final IosSheetEnvironment environment;
  final ValueChanged<_IosSheetRenderedSurface> onPainted;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _IosSheetSurfaceRenderObserver(geometry, environment, onPainted);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _IosSheetSurfaceRenderObserver renderObject,
  ) => renderObject.update(geometry, environment, onPainted);
}

class _IosSheetSurfaceRenderObserver extends RenderProxyBox {
  _IosSheetSurfaceRenderObserver(
    this._geometry,
    this._environment,
    this._onPainted,
  );
  IosSheetGeometry _geometry;
  IosSheetEnvironment _environment;
  ValueChanged<_IosSheetRenderedSurface> _onPainted;
  void update(
    IosSheetGeometry geometry,
    IosSheetEnvironment environment,
    ValueChanged<_IosSheetRenderedSurface> onPainted,
  ) {
    _geometry = geometry;
    _environment = environment;
    _onPainted = onPainted;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    _onPainted(
      _IosSheetRenderedSurface(
        geometry: _geometry,
        environment: _environment,
        bounds: Rect.fromPoints(
          localToGlobal(Offset.zero),
          localToGlobal(size.bottomRight(Offset.zero)),
        ),
      ),
    );
  }
}
