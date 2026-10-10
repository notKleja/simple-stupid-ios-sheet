import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';
import 'helpers/environment_fixture.dart';

void main() {
  test('four corners are clockwise TL TR BR BL and immutable', () {
    const radii = IosSheetCornerRadii(
      topLeft: Radius.circular(1),
      topRight: Radius.circular(2),
      bottomRight: Radius.circular(3),
      bottomLeft: Radius.circular(4),
    );
    expect(radii.clockwise, [
      const Radius.circular(1),
      const Radius.circular(2),
      const Radius.circular(3),
      const Radius.circular(4),
    ]);
    expect(() => radii.clockwise[0] = Radius.zero, throwsUnsupportedError);
  });
  test('unavailable corners require a nonempty reason', () {
    expect(
      () => IosSheetCornerResolution.unavailable(reason: ''),
      throwsArgumentError,
    );
  });
  test(
    'resolved corners reject invalid numerical radii and empty provenance',
    () {
      const invalid = IosSheetCornerRadii(
        topLeft: Radius.circular(-1),
        topRight: Radius.zero,
        bottomRight: Radius.zero,
        bottomLeft: Radius.zero,
      );
      expect(
        () =>
            IosSheetCornerResolution.resolved(invalid, provenance: 'synthetic'),
        throwsArgumentError,
      );
      const valid = IosSheetCornerRadii(
        topLeft: Radius.zero,
        topRight: Radius.zero,
        bottomRight: Radius.zero,
        bottomLeft: Radius.zero,
      );
      expect(
        () => IosSheetCornerResolution.resolved(valid, provenance: ''),
        throwsArgumentError,
      );
    },
  );
  test('bridge rejects responses for a different physical frame', () async {
    final request = IosSheetCornerRequest(
      environment: environmentFixture(),
      frame: const Rect.fromLTWH(10, 20, 100, 200),
    );
    await expectLater(
      IosSheetCornerBridge(
        resolver: _WrongFrameResolver(),
      ).resolveBatch([request]),
      throwsStateError,
    );
  });
  test('corner frame keys use physical pixel edges and environment', () {
    final request = IosSheetCornerRequest(
      environment: environmentFixture(),
      frame: const Rect.fromLTWH(10, 20, 100, 200),
    );
    expect(
      [
        request.key.left,
        request.key.top,
        request.key.right,
        request.key.bottom,
      ],
      [30, 60, 330, 660],
    );
    final nearby = IosSheetCornerRequest(
      environment: environmentFixture(),
      frame: const Rect.fromLTWH(10.01, 20.01, 100, 200),
    );
    expect(nearby.key, request.key);
    final changed = IosSheetCornerRequest(
      environment: environmentFixture(avoidance: 300),
      frame: request.frame,
    );
    expect(changed.key, isNot(request.key));
  });
  test(
    'unconnected async bridge returns explicit unavailable, never a radius',
    () async {
      final request = IosSheetCornerRequest(
        environment: environmentFixture(),
        frame: const Rect.fromLTWH(10, 20, 100, 200),
      );
      final result = await IosSheetCornerBridge().resolveBatch([request]);
      expect(result[request.key]!.status, IosSheetCornerStatus.unavailable);
      expect(result[request.key]!.radii, isNull);
      expect(result[request.key]!.reason, isNotEmpty);
      expect(() => result.clear(), throwsUnsupportedError);
    },
  );
  test(
    'bridge deduplicates quantized requests and marks omitted responses unavailable',
    () async {
      final first = IosSheetCornerRequest(
        environment: environmentFixture(),
        frame: const Rect.fromLTWH(10, 20, 100, 200),
      );
      final same = IosSheetCornerRequest(
        environment: environmentFixture(),
        frame: const Rect.fromLTWH(10.01, 20.01, 100, 200),
      );
      final omitted = IosSheetCornerRequest(
        environment: environmentFixture(),
        frame: const Rect.fromLTWH(20, 20, 100, 200),
      );
      final resolver = _PartialResolver();
      final result = await IosSheetCornerBridge(
        resolver: resolver,
      ).resolveBatch([first, same, omitted]);
      expect(resolver.observedBatchSize, 2);
      expect(result.length, 2);
      expect(result[first.key]!.radii!.bottomLeft, const Radius.circular(4));
      expect(result[omitted.key]!.status, IosSheetCornerStatus.unavailable);
      expect(result[omitted.key]!.radii, isNull);
    },
  );
}

class _PartialResolver implements IosSheetCornerResolver {
  int? observedBatchSize;
  @override
  Future<Map<IosSheetCornerKey, IosSheetCornerResolution>> resolveBatch(
    List<IosSheetCornerRequest> requests,
  ) async {
    observedBatchSize = requests.length;
    expect(() => requests.clear(), throwsUnsupportedError);
    return {
      requests.first.key: IosSheetCornerResolution.resolved(
        const IosSheetCornerRadii(
          topLeft: Radius.circular(1),
          topRight: Radius.circular(2),
          bottomRight: Radius.circular(3),
          bottomLeft: Radius.circular(4),
        ),
        provenance: 'synthetic resolver control, not native evidence',
      ),
    };
  }
}

class _WrongFrameResolver implements IosSheetCornerResolver {
  @override
  Future<Map<IosSheetCornerKey, IosSheetCornerResolution>> resolveBatch(
    List<IosSheetCornerRequest> requests,
  ) async {
    final wrong = IosSheetCornerRequest(
      environment: requests.first.environment,
      frame: const Rect.fromLTWH(99, 99, 1, 1),
    );
    return {
      wrong.key: IosSheetCornerResolution.unavailable(
        reason: 'synthetic wrong-frame response',
      ),
    };
  }
}
