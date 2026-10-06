# Synchronized Bilingual Simulator Video Design

## Intent

Produce a reviewable side-by-side video of two fresh iPhone 17 Pro simulators
running the same iOS 26.4.1 build: native UIKit on the left and Flutter on the
right. Both apps execute the same scenario timeline from one absolute host time,
switch from English/LTR to Arabic/RTL, and expose the scenario ID plus elapsed
time so synchronization is visible rather than assumed.

## Shared timeline

One JSON asset is the source of truth for duration, language, scene title, sheet
configuration, and absolute action offsets. Both apps parse that asset. The
first visual event is a synchronized three-step color/countdown marker used to
verify alignment in the composed video.

The first playlist covers:

1. Medium-to-large fluidity and return to medium.
2. Custom-height resizing through small, medium, and large detents.
3. Long scroll content and scroll-expands-first policy.
4. Scroll-content-first policy.
5. Undimmed-through-medium and modal-at-large property transition.
6. Interactive-dismissal-disabled versus explicit dismissal.
7. A component gallery with button, switch, segmented control, text field,
   fixed-height blocks, and list rows.
8. The same representative flow in Arabic with right-to-left layout.

Properties not yet implemented identically on both sides are labeled as a
demonstration or unresolved; the recording does not claim parity merely because
two frames look similar.

## Synchronization

The coordinator chooses `start_epoch_ms` at least eight seconds in the future,
launches both apps with that value in their process environments, starts two
`simctl io recordVideo` processes from one host command, and waits for both apps
to reach their armed screens. Each app derives scene and action state from
`Date.now - start_epoch_ms`; it does not chain relative delays. A visual elapsed
counter and scene ID appear in both recordings.

## Recording and composition

Two untouched H.264 simulator recordings are retained. FFmpeg normalizes their
start timestamps, pads them to equal duration, stacks them horizontally, and
adds a header and labels outside the simulator pixels. A run manifest records
simulator UDIDs, OS/build, device type, app revisions, timeline hash, launch
time, recording commands, output hashes, and observed duration/frame rate.

## Evidence boundary

The video proves simultaneous execution and visible behavior of the recorded
scenarios. It does not replace runtime traces or the numerical parity analyzer.
Programmatic scrolling is a deterministic visual example; it is not proof of
finger-driven scroll handoff. Keyboard focus is shown only if both simulators
present it reliably on the shared timeline.

