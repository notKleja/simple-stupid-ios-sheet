import 'dart:io';

import 'api_surface.dart';

void main(List<String> arguments) {
  if (arguments.length != 4) {
    stderr.writeln(
      'Usage: dart run tool/update_api_surface.dart <wrapper-index> <engine-index> <route-html> <output>',
    );
    exitCode = 64;
    return;
  }
  try {
    final symbols = readApiSurfaceInputs(arguments);
    File(arguments[3]).writeAsStringSync(encodeApiSurface(symbols));
    stdout.writeln('Updated API baseline: ${symbols.length} symbols.');
  } catch (error) {
    stderr.writeln('Cannot update API baseline: $error');
    exitCode = 1;
  }
}
