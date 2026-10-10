import 'dart:io';

import 'api_surface.dart';

void main(List<String> arguments) {
  if (arguments.length != 4) {
    stderr.writeln(
      'Usage: dart run tool/check_api_surface.dart <wrapper-index> <engine-index> <route-html> <baseline>',
    );
    exitCode = 64;
    return;
  }
  try {
    final current = readApiSurfaceInputs(arguments);
    final baseline = decodeApiSurface(File(arguments[3]).readAsStringSync());
    final diff = compareApiSurfaces(baseline, current);
    for (final symbol in diff.added) {
      stdout.writeln('Added: ${symbol.qualifiedName}');
    }
    for (final symbol in diff.removed) {
      stderr.writeln('Removed: ${symbol.qualifiedName}');
    }
    for (final symbol in diff.changed) {
      final old = baseline.singleWhere(
        (entry) => entry.qualifiedName == symbol.qualifiedName,
      );
      stderr.writeln(
        'Changed: ${symbol.qualifiedName}: kind ${old.kind} -> ${symbol.kind}, owner ${old.enclosingOwner} -> ${symbol.enclosingOwner}',
      );
    }
    exitCode = diff.hasBreakingChanges ? 1 : 0;
    stdout.writeln(
      'API check: ${current.length} symbols, ${diff.removed.length} removals, ${diff.changed.length} changes, ${diff.added.length} additions.',
    );
  } catch (error) {
    stderr.writeln('Cannot check API baseline: $error');
    exitCode = 1;
  }
}
