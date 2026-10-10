# Native y-axis motion: remaining work

Zero phases are promoted. Presentation, fixed320-to-medium, medium-to-large,
large-to-medium and dismissal remain unavailable in the production manifest.
No fitted curves, recorded-position corrections or visual curves are used.

Completed OS findings on the exact iOS 26.6.2 / 23G90 vPhone family:

- Authenticated UIKit construction and Core Animation spring evaluation recover
  the critical spring equation, coefficients, assigned duration, timing flags
  and scalar additive interpolation. The ten-trial Task 1 archive is preserved.
- `Layer::commit_animations` writes the assigned animation begin time after
  layer-time conversion. The CAAnimation getter/setter use the same attribute
  identifier, 0x41, and double value type, 0x12. An observation timestamp is not
  an animation epoch.
- Authenticated `animationForKey:`, `removeAnimationForKey:`, `removeAllAnimations`,
  `Context::remove_animation` and UIKit removal functions identify the lookup
  and cleanup paths. Their exact function extents and bytes are provenance-bound.
- Native commit `de794a95488f3203b34144279ec8bcc67be0dac9` adds paired pre/post
  installation, one deferred model-only observation and discrete cleanup
  snapshots. Host contracts reject incomplete/duplicate pairs, unsupported
  paths and missing provenance. These helpers do not promote a window-y law.

Finish these jobs before implementing a production profile:

1. Recover private additive CATransform3D interpolation and composition order,
   including the selected interpolator and each simultaneous property channel.
2. Establish exact sheet-view/controller ownership and the reversible mapping
   from controller value through the layer hierarchy into window coordinates,
   including the local Jacobians.
3. Obtain a guaranteed coherent post-transaction model boundary, with the
   assigned epoch, final model endpoints, ordered ancestry and retained-fill/
   removal state paired to the same installation. A next-runloop callback alone
   does not guarantee this; authenticated transaction/cleanup breakpoints are
   the remaining evidence route when needed.
4. Implement the evidence-bound Dart profile and analytic simulation only after
   those OS prerequisites are complete, then freeze implementation/provenance
   and run mathematical, coordinate and paired post-freeze runtime tests.

Task 2A's current runtime cohort is unsealed and excluded from canonical
recovery and production artifacts. Static findings and passing fixture tests
do not establish a complete window-y law, runtime parity or physical-device
behavior. Further guest/debugger probing was stopped at the user's request.
