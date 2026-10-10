/// Opaque Flutter sheets with iOS 26 as the sole native-reference scope.
///
/// Use [showIos26Sheet] for common presentation and construct
/// [StupidSimpleIosSheetRoute] directly for advanced profile and research seams.
/// The default [IosSheetProfile.ios26] is an explicitly unmeasured fallback,
/// not a claim of complete observed or accepted native parity.
library;

export 'src/detents.dart';
export 'src/environment.dart';
export 'src/state.dart';
export 'src/presentation.dart';
export 'src/motion.dart';
export 'src/corner_bridge.dart';
export 'src/measured_corners.dart';
export 'src/profile.dart' hide legacyIosSheetProfileForMajorVersion;
export 'src/route.dart';
export 'src/show_sheet.dart';
export 'src/trace.dart';
export 'src/comparison_contract.dart';
export 'src/observed_profiles.dart';
export 'package:ios_sheet_engine/ios_sheet_engine.dart'
    show
        Motion,
        SpringMotion,
        CupertinoMotion,
        CurvedMotion,
        SnapPhysics,
        AbsoluteSnapPhysics,
        RelativeSnapPhysics,
        FlingSnapPhysics,
        FrictionSnapPhysics,
        SheetDragHandoff,
        RouteSnapshotMode;
