import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ios_sheet_candidate/replay_timing.dart';

void main() {
  test('command processing cannot accumulate into later replay deadlines', () {
    fakeAsync((time) {
      final delivered = <int>[];
      final replay = ProgrammaticReplay(clock: () => time.elapsed);
      replay.run(
        present: () {
          delivered.add(time.elapsed.inMilliseconds);
          time.elapseBlocking(const Duration(milliseconds: 75));
        },
        select: (_) {
          delivered.add(time.elapsed.inMilliseconds);
          time.elapseBlocking(const Duration(milliseconds: 75));
        },
        dismiss: () => delivered.add(time.elapsed.inMilliseconds),
      );
      time.elapse(const Duration(seconds: 5));
      expect(delivered, [0, 1500, 3000, 4500]);
    });
  });

  test(
    'overdue real commands execute immediately without invented timestamps',
    () {
      fakeAsync((time) {
        final delivered = <int>[];
        final replay = ProgrammaticReplay(clock: () => time.elapsed);
        replay.run(
          present: () {
            time.elapseBlocking(const Duration(milliseconds: 1700));
          },
          select: (_) => delivered.add(time.elapsed.inMilliseconds),
          dismiss: () => delivered.add(time.elapsed.inMilliseconds),
        );
        time.elapse(const Duration(seconds: 4));
        expect(delivered, [1700, 3000, 4500]);
      });
    },
  );
}
