# UIKit motion construction recovery — 23G90

Status: recovered scalar construction; no production window-y phase promoted.

This report uses the exact iOS 26.6.2 (23G90) virtual-device images and the
complete Task 1 CALayer installation objects. It uses no recorded y trajectory,
video, screenshot, fitted coefficient, residual, phase alignment or corrective
term. The original Task 1 archive and loader behavior are preserved.

## Authenticated image identity

UIKitCore has UUID 0D94422F-FE7C-302E-B896-3BC5873C0CFC and SHA-256
6c93b6072b4033166bd6025f2a068961f687710a61f73db3ecfa6e40b49a9f4e.
Its extracted Mach-O __TEXT VM base is 0x189128000. QuartzCore has UUID
8F1E0B3F-ADD6-3710-A790-009333597AB4 and SHA-256
0c4e3dacb205fe1755db40502b4efa8afda2582ee69512caa3181706d3b41304,
with __TEXT VM base 0x183ed3000. These match Task 1's actual guest runtime UUIDs,
not host Simulator frameworks. The authenticated DeviceSupport extraction
paths are retained in ios26_function_evidence.json; Apple framework binaries
are not copied into the repository.

The object archive SHA-256 is
68789a0c5803bf8d6c776399c08a10c710bff2c87ab5ee5b9658699882c17e29.
The raw-object SHA-256 is
8caaed563c14f39bd5e812c1596cc1bf1a7730017e6d0df522579739c3d74dcd.
The installed probe UUID and hash, source revisions, ten completed run IDs,
scenario, environment, configuration and geometry come from the authenticated
Task 1 manifest. Recovery re-runs the complete loader and rejects a shortened
or modified incoming cohort, even if its elements have the Python dataclass type.

## Detent construction and ownership

The binary and captured executable return addresses identify this path:

```text
-[UISheetPresentationController _animateChanges:completion:]  0x18a96e38c
    BL _UISheetAnimateWithCompletion                       0x18a96e408
_UISheetAnimateWithCompletion                              0x189fc4c30
    BL _UISheetTransitionDuration                         0x189fc4c74
    BL _UISheetTransitionTimingCurve                      0x189fc4c7c
    initWithDuration:timingParameters:                     0x189fc4c98
    addAnimations:                                        0x189fc4cac
    startAnimation                                        0x189fc4ccc
```

The synchronous install backtrace contains the return addresses at image
relative offsets 0x184640c and 0xe9ccd0. Independent nlist symbolication maps
these to the two owner functions above, with their exact function bytes
hashed. The normalized offsets remain meaningful across guest ASLR slides.
Every captured UIKitCore and QuartzCore return address is symbolicated from
its authenticated executable-section nlist, with an explicit unresolved
verdict if a function range cannot be determined. Other authenticated image
frames remain in the complete source archive and are not renamed to sheet
owners.

The animation block at 0x18a96e42c obtains _layoutInfo and the previous active
index, calls the caller's mutation, compares the new index, then runs the
conditional animation wrapper and layout. No distance-based spring selection
exists in this recovered path.

The timing singleton block at 0x189fc4ba8 loads highSpeed=NO at 0x189fc4bcc
and zero X/Y velocity at 0x189fc4be4..0x189fc4be8. The default metrics block at
0x18a70d054 selects damping ratio 1 with FMOV/FCSEL and loads response from
0x18ae5fea0. Response bytes are e5ef07887506d63f (little endian), giving exactly
0.3441442326. Its preference-override branches are retained in disassembly;
the observed runtime object agrees with the default branch for this cohort.

The conversion function at 0x18955e47c loads 2*pi from 0x18ae56498, divides it
by response, squares it for stiffness, then takes sqrt(stiffness), doubles it,
and multiplies by damping ratio for damping. It writes mass=1. The resulting
values are:

```text
omega = 18.257418582058744
mass = 1
stiffness = 333.3333332805039
damping = 36.51483716411749
nominal UIView duration = 0.4
assigned CA duration = 0.5058237871186482
public CASpringAnimation settlingDuration = 0.6
```

The duration function uses the constant bytes at 0x18ae56068 (epsilon .001)
and 0x18ae62778..0x18ae62790 (.3361, -.0042, -.0201, -5.950609937518595).
The recovered fixed approximation is transcribed directly in
uikit_critical_duration; it does not optimize a root or fit sampled motion.
The UIView duration table at 0x18ae62718 supplies .4 for index 8.

## Object configuration and correction of the prior audit

The root layer is run-local layer.6, class _UIMultiLayer, in all ten runs.
For fixed320-to-medium, medium-to-large and large-to-medium it receives
CASpringAnimation objects on position, bounds.size and transform. Every
root object has the exact same solver and timing configuration; recovery
checks all captured flags without averaging. Their from/to objects differ.
For medium-to-large, position goes from additive offset (0,184.5) to (0,0)
and bounds.size from additive offset (0,-369) to (0,0). These are property
coordinates; 184.5 is not a fitted window-y displacement.

Actual root objects explicitly contain a linear timing function with all four
points ((0,0),(0,0),(1,1),(1,1)), speed 1, timeOffset 0, beginTime 0, no repeats,
no autoreverse, additive=true, cumulative=false, fillMode=both, and
removedOnCompletion=false. The prior audit's nil/default-removal description
applies only to an earlier factory stage and cannot be substituted for these
final installed objects. The factory at 0x1895f3880 sets mass, stiffness,
damping, velocity and allowsOverdamping. The wrapper at 0x1898109cc passes
allowsOverdamping=false. The UIView animation-state attribute setter later
sets duration, timing function, begin-time mode, fill and repeat/autoreverse.
Its full supplementary disassembly is included in
ios26_uikit_attributes_disassembly.txt, together with the default spring loader,
UISpringTimingParameters settlingDuration and property-animator factory.

The supplementary disassembly SHA-256 is
c7b5995eb72e9ec60161f147b85e0b50bf38bb2adef3df638949b9d88f570a6f.
Its exact UIKitCore function ranges, independently recomputed from the same
authenticated nlist and Mach-O VM-to-file mapping, are:

| Function address | Length | SHA-256 |
| --- | ---: | --- |
| 0x1891e04cc | 232 | 7d72c000ca1ce0cc1389e6ba001f715fa016558fc0f3d39c982ffaf77c6825da |
| 0x1891e05b4 | 848 | 4ce34d5c577fb9345b5695aa02373d82b3dbaedee6b37d569b51b844be1e0c70 |
| 0x189402884 | 412 | 3497da02288e7b7cc6ab116b1a13195f0110ef25b4f25624defc6ec98e33cd65 |
| 0x189403168 | 264 | 579cecd9f25c8e2eef4e6a2b6e166a6eb201431278022e835198890d66efb4f5 |
| 0x1896cc414 | 664 | 6aae1c3614ee06257056350c0637b8666cf045c2811789b935509d02c37d5972 |

These supplementary functions are read-only diagnostic evidence, separate
from the pinned 34-function recovery bundle consumed by the generator.

Presentation/dismissal objects instead expose mass=3, stiffness=1000,
damping=500, velocity=0, allowsOverdamping=false and duration=.5. The default
spring loader has explicit default mass=3 and duration=.5 branches; the
captured objects authenticate the chosen values. Presentation can install
multiple additive position animations on the same root layer. Their complete
ownership/ordering/window-coordinate path is not assigned the detent profile.

## Promotion decision

All five phases remain unresolved. Scalar equation and configuration reuse
are recovered, but distance scaling is not promoted. The missing pieces are:

- post-commit beginTime and ancestor timing; installation beginTime=0 is a
  sentinel, not the logged request or transaction timestamp;
- one coherent model state after the whole transaction: at position installation
  for medium-to-large, captured bounds.height is still 504; it becomes 873 at
  the bounds/transform installation;
- the CATransform3D interpolation and additive matrix composition actually used
  by the private multilayer root;
- an explicit mapping from the captured target layer to the presented sheet
  view, beyond its class and ancestry;
- UIKit's explicit cleanup of retained-fill objects and terminal presentation
  commit behavior.

No nonzero-velocity interruption, arbitrary custom endpoint, other OS build,
Simulator, physical device or configuration is accepted. The production
manifest has profiles=[] and phase-specific unresolved reasons. No Flutter or
Dart motion implementation is changed by Task 2.
