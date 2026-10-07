# Core Animation equation recovery — 23G90

Status: authenticated mathematical instruction transcription; window-y
production profiles remain unresolved.

The binary UUID/hash set, all 34 primary function ranges, exact VM/file offsets,
function SHA-256 values and constant bytes are in ios26_function_evidence.json.
Full instruction excerpts are in ios26_quartzcore_disassembly.txt and
ios26_uikit_disassembly.txt.
recover_os_motion recomputes every primary function range/hash and rejects a
changed range, binary byte, UUID, static bundle or object cohort. The report
and production manifest are canonical output from that recovery.

## Recovered functions

```text
State::update              0x183f7d484, 164 bytes
State::eval                0x183f6c58c, 228 bytes
State::eval_derivative     0x18401d6f8, 288 bytes
SpringAnimation::time_function 0x183f72a5c, 36 bytes
Timing::map_parent_to_active   0x183edd488, 196 bytes
Timing::map_active_to_local    0x183edd54c, 144 bytes
Animation::map_time            0x183edcbe8, 376 bytes
Animation::check_should_remove 0x183edd108, 40 bytes
PropertyAnimation::interpolate_vector 0x183ee53a8, 68 bytes
BasicAnimation0::apply         0x183ee53ec, 1724 bytes
Layer::commit_animations      0x183fa846c, 1412 bytes
```

## Branches and equations

State::update computes omega=sqrt(k/m) and zeta=c/(2*sqrt(k*m)). It stores
the allowsOverdamping selector and branches at +40, +84 and +92.
For zeta<1, write beta=zeta*omega, wd=omega*sqrt(1-zeta*zeta),
B=(beta-v0)/wd. The literal update/eval path gives:

```text
q(t)=1-exp(-beta*t)*(cos(wd*t)+B*sin(wd*t))
```

For zeta==1, or any zeta>=1 with allowsOverdamping=false, write B=omega-v0:

```text
q(t)=1-(1+B*t)*exp(-omega*t)
q'(t)=(omega*(1+B*t)-B)*exp(-omega*t)
q''(t)=(2*omega*B-omega^2*(1+B*t))*exp(-omega*t)
```

For zero initial velocity this is the recovered sheet law:

```text
q(t)=1-(1+omega*t)*exp(-omega*t)
q'(t)=omega^2*t*exp(-omega*t)
q''(t)=omega^2*(1-omega*t)*exp(-omega*t)
```

The observed presentation/dismissal tuple has nominal zeta>1 but
allowsOverdamping=false. It therefore follows the same critical branch with
omega=sqrt(1000/3), not the conventional overdamped response using c=500.
The detent tuple uses omega=18.257418582058744 and nominal zeta=1.

The allowed-overdamping branch is a material discrepancy with the earlier
analytic audit. The exact instruction sequence stores gamma=omega*sqrt(zeta^2-1),
A=(beta+v0+gamma)/(2*gamma) at +0x18 and
B=(gamma-beta-v0)/(2*gamma) at +0x20. State::eval loads A with the fast
exponential and B with the slow exponential:

```text
q(t)=1-A*exp(-(beta+gamma)*t)-B*exp((gamma-beta)*t)
```

This coefficient ordering differs from the conventional zero-velocity
second-order solution quoted in the prior audit. For the independent m=1,
k=2, c=3, v0=0 fixture, the literal path is
q(t)=1-2*exp(-2*t)+exp(-t); at t=ln(2), q=1, q'=.5, q''=-1.5.
No captured sheet object selects allowsOverdamping=true. This branch is an
explicit static transcription only, with no runtime promotion or claim that
its nominal initial velocity has the conventional interpretation. ARM fused
instruction signs were checked against the
[Arm instruction reference](https://documentation-service.arm.com/static/6245c734b059dc5ff9a8bdab);
parameters and coefficient ordering come exclusively from the authenticated
QuartzCore bytes. This unusual branch warrants independent runtime validation
before any future production use.

## Clock mapping

At Timing::map_parent_to_active +112..+128, the path subtracts beginTime,
loads speed as a 32-bit float, converts speed to double, then uses FMADD with
timeOffset. Interior active time is (parent-begin)*float32(speed)+timeOffset.
The helper rejects the installation beginTime=0 sentinel. It never treats a
request timestamp or the install logger's transaction_time as beginTime.

The active-to-local path contains repeat folding and autoreverse handling.
Animation::map_time normalizes local time by assigned duration.
SpringAnimation::time_function +24 multiplies normalized time by the assigned
duration before tail-calling State::eval. A spring is therefore evaluated
in seconds; replacing these seconds with UIView's nominal .4 duration or
public settlingDuration .6 produces a different equation in time.

Layer::commit_animations +356..+696 checks beginTimeMode and zero beginTime,
obtains commit-layer timing, calls TimingList::map_time and setBeginTime.
The complete installation objects precede these writes. The actual committed
epoch cannot be recovered by choosing a timestamp from those objects.

## Coordinate interpolation and terminal boundary

PropertyAnimation::interpolate_vector +24..+44 subtracts from from to and uses
FMADD with progress. For scalar/vector values the mathematical law is
from+(to-from)*q; additive values then compose with the base value. Direction
belongs in to-from. A negative window-y delta moves upward, but the object's
position.y additive offset is not itself window top y.

The installed multilayer root simultaneously changes position, bounds.size
and transform. A top point must pass through its anchor, bounds, transform,
ancestor transform and parent sublayer transforms. Static ancestry snapshots
identify these fields but are not a coherent animated endpoint state.
CATransform3D values must not be interpolated as 16 unrelated scalar channels
without recovering the chosen ValueInterpolator and additive matrix order.

Timing::map_parent_to_active applies fill bounds and
Animation::check_should_remove tests a removal flag. Actual objects have
fillMode=both and removedOnCompletion=false. Thus the scalar response at the
assigned duration is not an authenticated exact-target cutoff. At
.5058237871186482 seconds the analytic critical q is .9990014634632299, with
nonzero derivative. Task 2's helper does not force q=1 or velocity=0 there.
The timing path's boundary epsilon/folding and UIKit explicit animation cleanup
remain unresolved for production terminal semantics.

## Conformance evidence and limits

Tests use independent hand-derived critical, undamped and literal allowed-over
fixtures, initial values and velocity signs, excess-damping branch selection,
property sign/additive composition, float32 media speed and the exact UIKit
critical duration approximation. Provenance tests reject changed binary bytes,
wrong binaries, incomplete/mutated cohorts, manual profile edits and extra
fit/trace/residual fields. Committed JSON regenerates byte-for-byte.

This is host mathematical conformance, not guest instruction/libm bit identity,
a measured runtime error budget, coherent window-y parity, or physical-device
behavior. All production phases and interruption remain unresolved. No
trajectory file, video or screenshot supplies the implementation or profile;
no per-trial residual is computed.
