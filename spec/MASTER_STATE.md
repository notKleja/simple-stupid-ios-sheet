# Master state

## Accepted facts

- Native iOS runtime measurement outranks package defaults and visual judgment.
- iOS 26 and iOS 27 require independent profiles when behavior differs.
- The shipping surface is opaque; Liquid Glass is excluded.
- `stupid_simple_sheet` 1.0.0-dev.4 is the initial upstream foundation.

## Architecture

- A native UIKit/SwiftUI harness and Flutter harness share scenario IDs.
- Both emit a versioned JSONL measurement schema.
- A trace analyzer aligns on recorded event boundaries and produces numerical
  parity results.
- The Flutter implementation is an opinionated native-iOS layer over the
  package's generic route engine, extending the engine only when measured
  behavior cannot be represented.

## Unresolved questions

- Available iOS 26 and iOS 27 vPhone runtimes, builds, devices, and automation
  interfaces.
- Measured geometry, motion, gesture, keyboard, stacking, and adaptivity values.
- Which upstream engine seams require extension for velocity continuity and
  true nonmodal hit testing.

## Active pull requests

- None.

## Current parity score

- Not measured.

## Next three highest-value tasks

1. Inventory accessible vPhone runtimes and establish the first native trace.
2. Audit the upstream route, controller, snapping, and gesture architecture.
3. Implement and validate the common trace schema and analyzer baseline.

