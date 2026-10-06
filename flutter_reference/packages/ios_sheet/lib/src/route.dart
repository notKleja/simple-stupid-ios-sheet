import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

import 'detents.dart';
import 'profile.dart';
import 'trace.dart';

const iosSheetSurfaceKey = ValueKey('ios-sheet-opaque-surface');

enum IosSheetContentInteraction { resizes, scrolls }

enum IosSheetKeyboardPolicy { resize, overlay }

/// Controls semantic detents without exposing normalized engine positions.
class IosSheetController extends ChangeNotifier {
  StupidSimpleIosSheetRoute<dynamic>? _route;

  bool get isAttached => _route != null;
  String? get selectedDetentIdentifier => _route?._selectedIdentifier;
  String? get targetDetentIdentifier => _route?._targetIdentifier;
  double get visibleHeight => _route?.visibleHeight ?? 0;
  bool get isModal => _route?.isModal ?? false;

  /// Capture after layout/paint, typically from a post-frame callback.
  IosSheetFrame captureFrame() {
    final route = _route;
    if (route == null) throw StateError('Sheet controller is detached');
    return route.captureFrame();
  }

  void selectDetent(String identifier) {
    final route = _route;
    if (route == null) throw StateError('Sheet controller is detached');
    route.selectDetent(identifier);
  }

  /// Explicit dismissal is allowed even when interactive dismissal is locked.
  void dismiss([Object? result]) {
    final route = _route;
    if (route == null) throw StateError('Sheet controller is detached');
    if (!route.isCurrent) throw StateError('Sheet is covered by another route');
    route.navigator?.pop(result);
  }

  void _attach(StupidSimpleIosSheetRoute<dynamic> route) {
    if (_route != null) throw StateError('Controller already has a sheet');
    _route = route;
  }

  void _changed() => notifyListeners();

  void _detach(StupidSimpleIosSheetRoute<dynamic> route) {
    if (identical(_route, route)) {
      _route = null;
      notifyListeners();
    }
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
    this.onSelectedDetentChanged,
    this.onPresented,
    this.onDismissed,
    super.settings,
  }) : detents = List.unmodifiable(detents),
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
  final IosSheetController? _sheetController;
  final IosSheetContentInteraction contentInteraction;
  final IosSheetKeyboardPolicy keyboardPolicy;
  @override
  final bool draggable;
  final bool dismissible;
  final bool interactiveDismissDisabled;
  final Color backgroundColor;
  final Color modalBarrierColor;
  final ValueChanged<String>? onSelectedDetentChanged;
  final VoidCallback? onPresented;
  final VoidCallback? onDismissed;

  String? _selectedIdentifier;
  String? _targetIdentifier;
  bool _presented = false;
  double? _dismissStartExtent;
  final _surfaceProbe = GlobalKey();

  IosSheetGeometry get currentGeometry => profile.geometry(
    IosSheetGeometryContext(
      environment: environment,
      visibleHeight: _layoutExtent * _referenceHeight,
      progress: _layoutExtent,
      velocity: controller?.velocity ?? 0,
    ),
  );

  double get _layoutExtent {
    if (!profile.fixedSurfaceDuringTransition) return controller?.value ?? 0;
    return _dismissStartExtent ??
        (!_presented ? snappingConfig.initialSnap : controller!.value);
  }

  IosSheetFrame captureFrame() {
    final box = _surfaceProbe.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      throw StateError('Sheet has not completed layout');
    }
    final topLeft = box.localToGlobal(Offset.zero);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
    final size = bottomRight - topLeft;
    final env = environment;
    final geometry = currentGeometry;
    final selected = resolvedDetents
        .where((e) => e.identifier == _selectedIdentifier)
        .firstOrNull;
    return IosSheetFrame(
      metrics: {
        'sheet.x': topLeft.dx,
        'sheet.y': topLeft.dy,
        'sheet.width': size.dx,
        'sheet.height': size.dy,
        'sheet.visible_height': math.max(
          0,
          math.min(bottomRight.dy, env.availableSize.height) -
              math.max(0, topLeft.dy),
        ),
        'sheet.top': topLeft.dy,
        'sheet.bottom': bottomRight.dy,
        'sheet.left_inset': topLeft.dx,
        'sheet.right_inset': env.availableSize.width - bottomRight.dx,
        'sheet.bottom_inset': env.availableSize.height - bottomRight.dy,
        'sheet.detent_height': selected?.height,
        'sheet.radius': geometry.shape == null
            ? geometry.cornerRadius * geometry.scale
            : null,
        'sheet.relative_progress': controller!.value,
        'barrier.alpha': isModal ? modalBarrierColor.a : 0,
        'sheet.velocity_y': null,
        'finger.velocity_y': null,
        'scroll.offset': null,
      },
      state: {
        'selected_detent': _selectedIdentifier,
        'target_detent': _targetIdentifier,
        'gesture': isUserDragging ? 'dragging' : 'idle',
        'scroll_owner': null,
        'underlying_hit_test': null,
        'dismissed': !isActive,
        'surface': 'opaque',
        'shape': geometry.shape == null ? 'rounded_superellipse' : 'custom',
      },
      unavailable: {
        'sheet.velocity_y': 'derive from consecutive observed screen positions',
        'finger.velocity_y': 'pointer recorder not attached',
        'scroll.offset': 'scroll recorder not attached',
        'scroll_owner': 'gesture ownership instrumentation pending',
        'underlying_hit_test': 'no real background touch probe in this frame',
        if (geometry.shape != null)
          'sheet.radius': 'custom shape cannot be represented by one scalar',
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
      displayScale: media.devicePixelRatio,
    );
    return IosSheetEnvironment(
      availableSize: base.availableSize,
      maximumDetentHeight: profile.maximumDetentHeight(base),
      safeArea: base.safeArea,
      keyboardHeight: base.keyboardHeight,
      displayScale: base.displayScale,
    );
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

  double get visibleHeight => (controller?.value ?? 0) * _referenceHeight;

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
    return visibleHeight > thresholdHeight + 0.000001;
  }

  @override
  Motion get motion => profile.motion;
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
  String get barrierLabel => 'Dismiss sheet';
  @override
  bool get maintainState => true;
  @override
  RoutePopDisposition get popDisposition =>
      dismissible && !interactiveDismissDisabled
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
    _sheetController?._attach(this);
    controller!.addListener(_animationChanged);
    controller!.addStatusListener(_statusChanged);
  }

  void _statusChanged(AnimationStatus _) => _animationChanged();

  void _animationChanged() {
    if (!controller!.isAnimating && isActive) {
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
        if (_selectedIdentifier != selected.identifier) {
          _selectedIdentifier = selected.identifier;
          onSelectedDetentChanged?.call(selected.identifier);
        }
        _targetIdentifier = selected.identifier;
        if (!_presented) {
          _presented = true;
          onPresented?.call();
        }
      }
    }
    _sheetController?._changed();
  }

  void selectDetent(String identifier) {
    final resolved = resolvedDetents.where((e) => e.identifier == identifier);
    if (resolved.isEmpty) throw ArgumentError('Unknown detent: $identifier');
    _targetIdentifier = identifier;
    animateToRelative(_engineExtent(resolved.single));
  }

  @override
  Widget buildContent(BuildContext context) => MediaQuery.removePadding(
    context: context,
    removeTop: true,
    child: SizedBox.expand(child: child),
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
        final fraction = fixedTransition && layoutExtent > 0
            ? (controller!.value / layoutExtent).clamp(0.0, 1.0)
            : 1.0;
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
        );
      },
    );
  }

  @override
  Widget buildModalBarrier() => AnimatedBuilder(
    animation: controller!,
    builder: (context, _) => IgnorePointer(
      ignoring: !isModal,
      child: ExcludeSemantics(
        excluding: !isModal,
        child: ModalBarrier(
          color: isModal ? barrierColor : null,
          dismissible: barrierDismissible,
          semanticsLabel: barrierLabel,
          onDismiss: () => navigator?.maybePop(),
        ),
      ),
    ),
  );

  @override
  bool didPop(T? result) {
    if (profile.fixedSurfaceDuringTransition) {
      _dismissStartExtent = controller!.value;
    }
    return super.didPop(result);
  }

  @override
  void dispose() {
    controller?.removeListener(_animationChanged);
    controller?.removeStatusListener(_statusChanged);
    _sheetController?._detach(this);
    onDismissed?.call();
    super.dispose();
  }
}
