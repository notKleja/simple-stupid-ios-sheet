/// Canonical IDs are shared with native_reference, independent of UIKit's raw
/// identifier strings. Custom identifiers retain their exact spelling.
String? canonicalIosDetentIdentifier(String? identifier) =>
    switch (identifier) {
      'com.apple.UIKit.medium' => 'medium',
      'com.apple.UIKit.large' => 'large',
      _ => identifier,
    };

const iosSheetComparisonConfigurationKeys = {
  'trial',
  'detents',
  'surface',
  'grabber',
  'page_sizing',
  'modal_in_presentation',
  'largest_undimmed',
  'presentation_style',
  'preferred_content_size',
  'placement',
  'edge_attached_in_compact_height',
  'width_follows_preferred_content_size',
  'scroll_expansion',
};

/// Configuration v2: actual semantic recipe inputs only. Implementation
/// profiles, evidence, diagnostics and clocks belong in provenance.
Map<String, Object?> canonicalIosSheetConfiguration(
  Map<String, Object?> input,
) {
  if (input.keys
          .toSet()
          .difference(iosSheetComparisonConfigurationKeys)
          .isNotEmpty ||
      iosSheetComparisonConfigurationKeys
          .difference(input.keys.toSet())
          .isNotEmpty) {
    throw ArgumentError(
      'Comparison configuration must contain exactly the '
      'v2 native keys; put implementation details in provenance',
    );
  }
  final rawDetents = input['detents'];
  if (rawDetents is! List ||
      rawDetents.isEmpty ||
      rawDetents.any((value) => value is! String || value.isEmpty)) {
    throw ArgumentError('Detents must be nonempty identifiers');
  }
  final detents = rawDetents
      .map((id) => canonicalIosDetentIdentifier(id as String)!)
      .toList(growable: false);
  if (detents.toSet().length != detents.length)
    throw ArgumentError('Duplicate detents');
  final undimmed = input['largest_undimmed'];
  if (undimmed != null && undimmed is! String)
    throw ArgumentError('Invalid undimmed ID');
  final largest = canonicalIosDetentIdentifier(undimmed as String?);
  if (largest != null && !detents.contains(largest))
    throw ArgumentError('Unknown undimmed ID');
  return Map.unmodifiable({
    ...input,
    'detents': List.unmodifiable(detents),
    'largest_undimmed': largest,
  });
}

/// The supported paired page recipe. This is a harness configuration, not a
/// claim of general form/placement/edge adaptation in the Flutter engine.
Map<String, Object?> iosPageReferenceConfiguration({
  required int trial,
  bool grabber = true,
  bool modalInPresentation = false,
  String? largestUndimmed,
  bool scrollExpansion = true,
}) => canonicalIosSheetConfiguration({
  'trial': trial,
  'detents': ['fixed320', 'medium', 'large'],
  'surface': 'opaque.white',
  'grabber': grabber,
  'page_sizing': true,
  'modal_in_presentation': modalInPresentation,
  'largest_undimmed': largestUndimmed,
  'presentation_style': 'page_sheet',
  'preferred_content_size': {'width': 320, 'height': 320},
  'placement': 'automatic',
  'edge_attached_in_compact_height': false,
  'width_follows_preferred_content_size': false,
  'scroll_expansion': scrollExpansion,
});
