import 'dart:convert';
import 'dart:io';

const _routeOwner = 'StupidSimpleIosSheetRoute';
const _engineOwners = {
  'StupidSimpleSheetTransitionMixin',
  'StupidSimpleSheetController',
};

/// Stable dartdoc identity. URLs and SDK inheritance depth are not API fields.
final class ApiSymbol implements Comparable<ApiSymbol> {
  const ApiSymbol({
    required this.qualifiedName,
    required this.kind,
    required this.enclosingOwner,
  });

  final String qualifiedName;
  final int kind;
  final String? enclosingOwner;

  Map<String, Object?> toJson() => {
    'qualifiedName': qualifiedName,
    'kind': kind,
    'enclosingOwner': enclosingOwner,
  };

  @override
  int compareTo(ApiSymbol other) {
    final name = qualifiedName.compareTo(other.qualifiedName);
    if (name != 0) return name;
    final type = kind.compareTo(other.kind);
    if (type != 0) return type;
    return (enclosingOwner ?? '').compareTo(other.enclosingOwner ?? '');
  }
}

// Dartdoc member rows have stable dt IDs and class tokens. Attribute order,
// deprecated anchors inside a row, and additional classes do not affect these.
Map<String, bool> _memberRows(String html, {bool instanceOnly = false}) {
  if (instanceOnly) {
    html = html.replaceAllMapped(
      RegExp(
        r'<section\b[^>]*\bid="(?:static-[^"]+|constants)"[^>]*>[\s\S]*?</section>',
      ),
      (_) => '',
    );
  }
  final rows = <String, bool>{};
  for (final match in RegExp(r'<dt\b([^>]*)>').allMatches(html)) {
    final attributes = match.group(1)!;
    final id = RegExp(r'\bid="([^"]+)"').firstMatch(attributes)?.group(1);
    final classes = RegExp(
      r'\bclass="([^"]*)"',
    ).firstMatch(attributes)?.group(1);
    if (id != null && classes != null) {
      rows[id] = classes.split(RegExp(r'\s+')).contains('inherited');
    }
  }
  return rows;
}

/// Keeps wrapper declarations and inherited instance API declared by the engine.
/// Engine index ownership alone includes SDK members, so each name must also
/// have a non-inherited row in its engine owner's mixin HTML.
List<ApiSymbol> normalizeApiSurface({
  required List<Object?> wrapperIndex,
  required List<Object?> engineIndex,
  required String routeHtml,
  required Map<String, String> engineOwnerHtml,
}) {
  final declaredByOwner = <String, Set<String>>{};
  for (final owner in _engineOwners) {
    final html = engineOwnerHtml[owner];
    if (html == null) throw FormatException('Missing engine HTML for $owner');
    final allRows = _memberRows(html);
    if (allRows.isEmpty) {
      throw FormatException('No usable engine HTML member rows for $owner');
    }
    for (final entry in engineIndex.whereType<Map<String, Object?>>()) {
      final entryOwner = entry['enclosedBy'] as Map<String, Object?>?;
      if (entryOwner?['name'] == owner) {
        final name = entry['name'] as String;
        if (!allRows.containsKey(name)) {
          throw FormatException('Missing engine HTML row for $owner.$name');
        }
      }
    }
    final rows = _memberRows(html, instanceOnly: true);
    declaredByOwner[owner] = rows.entries
        .where((row) => !row.value)
        .map((row) => row.key)
        .toSet();
  }
  final engineNames = <String>{};
  for (final entry in engineIndex.whereType<Map<String, Object?>>()) {
    final owner = entry['enclosedBy'] as Map<String, Object?>?;
    final name = entry['name'] as String?;
    if (name != null &&
        (declaredByOwner[owner?['name']]?.contains(name) ?? false)) {
      engineNames.add(name);
    }
  }
  final routeRows = _memberRows(routeHtml);
  final symbols = <ApiSymbol>[];
  for (final entry in wrapperIndex.whereType<Map<String, Object?>>()) {
    final owner = entry['enclosedBy'] as Map<String, Object?>?;
    final ownerName = owner?['name'] as String?;
    final name = entry['name'] as String;
    if (ownerName == _routeOwner) {
      final inherited = routeRows[name];
      if (inherited == null)
        throw FormatException('Missing route HTML row for $name');
      if (inherited && !engineNames.contains(name)) continue;
    }
    symbols.add(
      ApiSymbol(
        qualifiedName: entry['qualifiedName'] as String,
        kind: entry['kind'] as int,
        enclosingOwner: ownerName,
      ),
    );
  }
  return symbols..sort();
}

String encodeApiSurface(List<ApiSymbol> symbols) =>
    '${const JsonEncoder.withIndent('  ').convert((List<ApiSymbol>.of(symbols)..sort()).map((symbol) => symbol.toJson()).toList())}\n';

List<ApiSymbol> decodeApiSurface(String source) =>
    (jsonDecode(source) as List)
        .map(
          (entry) => ApiSymbol(
            qualifiedName: entry['qualifiedName'] as String,
            kind: entry['kind'] as int,
            enclosingOwner: entry['enclosingOwner'] as String?,
          ),
        )
        .toList()
      ..sort();

final class ApiSurfaceDiff {
  const ApiSurfaceDiff({
    required this.removed,
    required this.changed,
    required this.added,
  });
  final List<ApiSymbol> removed;
  final List<ApiSymbol> changed;
  final List<ApiSymbol> added;
  bool get hasBreakingChanges => removed.isNotEmpty || changed.isNotEmpty;
}

ApiSurfaceDiff compareApiSurfaces(
  List<ApiSymbol> baseline,
  List<ApiSymbol> current,
) {
  final before = {for (final symbol in baseline) symbol.qualifiedName: symbol};
  final after = {for (final symbol in current) symbol.qualifiedName: symbol};
  return ApiSurfaceDiff(
    removed:
        baseline
            .where((symbol) => !after.containsKey(symbol.qualifiedName))
            .toList()
          ..sort(),
    changed: current.where((symbol) {
      final old = before[symbol.qualifiedName];
      return old != null &&
          (old.kind != symbol.kind ||
              old.enclosingOwner != symbol.enclosingOwner);
    }).toList()..sort(),
    added:
        current
            .where((symbol) => !before.containsKey(symbol.qualifiedName))
            .toList()
          ..sort(),
  );
}

/// CLI input: wrapper index, engine index, route HTML, then output/baseline.
/// Finds mixin HTML relative to the engine index, supporting package renames.
List<ApiSymbol> readApiSurfaceInputs(List<String> arguments) {
  final wrapperIndex =
      jsonDecode(File(arguments[0]).readAsStringSync()) as List;
  final engineFile = File(arguments[1]).absolute;
  final engineIndex = jsonDecode(engineFile.readAsStringSync()) as List;
  final ownerHtml = <String, String>{};
  for (final owner in _engineOwners) {
    final entry = engineIndex.whereType<Map<String, Object?>>().singleWhere(
      (entry) =>
          entry['name'] == owner &&
          (entry['href'] as String? ?? '').endsWith('-mixin.html'),
      orElse: () =>
          throw FormatException('Missing engine mixin index entry for $owner'),
    );
    ownerHtml[owner] = File.fromUri(
      engineFile.parent.uri.resolve(entry['href'] as String),
    ).readAsStringSync();
  }
  return normalizeApiSurface(
    wrapperIndex: wrapperIndex.cast<Object?>(),
    engineIndex: engineIndex.cast<Object?>(),
    routeHtml: File(arguments[2]).readAsStringSync(),
    engineOwnerHtml: ownerHtml,
  );
}
