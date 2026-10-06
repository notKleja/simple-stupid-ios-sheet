# Native/candidate comparison contract v2

The JSONL envelope remains schema_version1. New emitters declare
`native_contract_version:2` on the session. Comparison metadata must match
exactly in scenario_id, os, device, environment and configuration. Source
profiles, clocks, renderer notes and software resting observations are outside
those comparison objects, under provenance.

Configuration has exactly these13 keys: trial, detents, surface, grabber,
page_sizing, modal_in_presentation, largest_undimmed, presentation_style,
preferred_content_size, placement, edge_attached_in_compact_height,
width_follows_preferred_content_size, scroll_expansion. The paired page recipe
uses fixed320/medium/large, opaque.white, page_sheet, preferred320×320, automatic
placement, no compact edge attachment/preferred-width following. This recipe
description does not claim unimplemented form/placement families work in
Flutter. Unsupported families remain declared in ARCHITECTURE.md.

System IDs are medium/large, not raw UIKit strings. Custom IDs remain exact.
Native SDK raw IDs and implementation inputs are preserved separately. The
logical selected ID changes on an accepted programmatic request; it is not a
resting-position estimator. A configured engine snap target is synchronized
before candidate frame emission. Closing has no configured target: null with
an explicit reason. Candidate resting_detent is a software observation in
provenance, not a native settling claim. Gesture none/touch means observed
delivered input; candidate observation currently covers sheet content only.

The programmatic comparison sequence is present.requested,
present.first_visible, present.completed, detent.requested(large),
detent.requested(medium), dismiss.requested, dismiss.completed. first_visible
uses the first sampled positive visible height. Completion is the operation's
completion callback/status, not physical settling. Native detent.changed is a
user-selection delegate event; candidate programmatic selection does not invent
such an event. Resolver probes and terminal run provenance require an explicit
approved auxiliary policy; they never become timing or settling boundaries.

Fixed-surface presentation currently rejects retargeting/dismissal and ignores
content input while opening. Rejection precedes state mutation; it prevents
the former medium-to-large completion jump. This is an explicit unsupported
interruption family, not native interaction parity. Generic engine routes keep
their existing interruption path.

Height API names distinguish unscaledTrajectoryHeight (engine position),
unscaledSurfaceHeight (layout envelope), renderedSurfaceHeight (last laid-out
scaled window bounds) and renderedVisibleHeight (viewport intersection).
visibleHeight is the rendered/clipped value. Recorders use the observed
rendered values, not the unscaled detent/trajectory model.
