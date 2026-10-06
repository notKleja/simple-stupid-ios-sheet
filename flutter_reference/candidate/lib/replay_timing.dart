import 'dart:async';

/// Native recipe offsets anchored to the actual presentation request. Handler
/// or frame work may delay delivery; observed receipt times are never replaced
/// by scheduled deadlines. No native motion constants are encoded here.
class ProgrammaticReplay {
  ProgrammaticReplay({required this.clock});
  final Duration Function() clock;

  Future<void> run({
    required void Function() present,
    required void Function(String) select,
    required void Function() dismiss,
  }) async {
    final boundary = clock();
    present();
    Future<void> at(Duration offset, void Function() command) async {
      final remaining = boundary + offset - clock();
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      command();
    }

    await Future.wait([
      at(const Duration(milliseconds: 1500), () => select('large')),
      at(const Duration(milliseconds: 3000), () => select('medium')),
      at(const Duration(milliseconds: 4500), dismiss),
    ]);
  }
}
