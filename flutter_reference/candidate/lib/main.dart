import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';
import 'replay_timing.dart';

void main() => runApp(const IosSheetCandidateApp());

class IosSheetCandidateApp extends StatelessWidget {
  const IosSheetCandidateApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.blue),
    home: const SheetPlayground(),
  );
}

class SheetPlayground extends StatefulWidget {
  const SheetPlayground({super.key});
  @override
  State<SheetPlayground> createState() => _SheetPlaygroundState();
}

class _SheetPlaygroundState extends State<SheetPlayground>
    with TickerProviderStateMixin {
  static const _metadata = MethodChannel('sheet_reference/metadata');
  int _major = const int.fromEnvironment(
    'SHEET_PROFILE_MAJOR',
    defaultValue: 27,
  );
  bool _undimmed = false,
      _draggable = true,
      _dismissLocked = false,
      _scrollFirst = false,
      _grabber = true,
      _debug = false,
      _qualified = true,
      _busy = false;
  String _content = 'calibration', _detents = 'reference';
  IosSheetController? _active;
  IosSheetTraceRecorder? _recorder;
  IOSink? _sink;
  Ticker? _ticker;
  IosSheetFrame? _lastFrame;
  bool _firstVisible = false;
  int _backgroundTouches = 0;
  final List<String> _traceFiles = [];

  @override
  void initState() {
    super.initState();
    if (const bool.fromEnvironment('SHEET_AUTORUN')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runBatch());
    }
  }

  IosSheetProfile _profile() {
    final media = MediaQuery.of(context);
    final qualified =
        _qualified &&
        _content == 'calibration' &&
        _detents == 'reference' &&
        media.size == const Size(402, 874) &&
        media.viewPadding.top == 62 &&
        media.viewPadding.bottom == 34 &&
        media.devicePixelRatio == 3 &&
        media.viewInsets.bottom == 0;
    return qualified
        ? observedPage402x874Profile(_major)
        : IosSheetProfile.forMajorVersion(_major);
  }

  List<IosSheetDetent> _detentList() => switch (_detents) {
    'single' => [IosSheetDetent.large],
    'custom' => [
      IosSheetDetent.height('small', 240),
      IosSheetDetent.height('middle', 420),
      IosSheetDetent.large,
    ],
    'fraction' => [
      IosSheetDetent.fraction('third', 1 / 3),
      IosSheetDetent.large,
    ],
    _ => [
      IosSheetDetent.height('fixed320', 320),
      IosSheetDetent.medium,
      IosSheetDetent.large,
    ],
  };

  Future<void> _beginTrace(int trial) async {
    final metadata = await _metadata.invokeMapMethod<String, Object?>(
      'capture',
    );
    if (!mounted || metadata == null) return;
    final runId = '${DateTime.now().microsecondsSinceEpoch}-$trial';
    final path =
        '${metadata['documents_directory']}/'
        'native.medium_large.programmatic-$runId.jsonl';
    _sink = File(path).openWrite();
    _traceFiles.add(path);
    _recorder = IosSheetTraceRecorder(
      runId: runId,
      scenarioId: 'native.medium_large.programmatic',
      sink: (line) => _sink?.write(line),
      os: Map<String, Object?>.from(metadata['os'] as Map),
      device: Map<String, Object?>.from(metadata['device'] as Map),
      environment: Map<String, Object?>.from(metadata['environment'] as Map),
      configuration: iosPageReferenceConfiguration(
        trial: trial,
        grabber: _grabber,
        largestUndimmed: _undimmed ? 'medium' : null,
        modalInPresentation: _dismissLocked,
        scrollExpansion: !_scrollFirst,
      ),
      implementationProvenance: {
        'profile_major': _major,
        'profile_evidence': _profile().evidence,
        'content': 'calibration',
        'replay_anchor':
            'actual present.requested; independent absolute deadlines',
        'sheet_warmup': false,
      },
    );
    _firstVisible = false;
    _ticker = createTicker((elapsed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!(_active?.isAttached ?? false)) return;
        try {
          final frame = _active!.captureFrame();
          _lastFrame = frame;
          if (!_firstVisible &&
              (frame.metrics['sheet.visible_height'] ?? 0) > 0) {
            _firstVisible = true;
            _recorder?.event('present.first_visible', {
              'detector': 'first sampled positive visible height',
            });
          }
          _recorder?.frame(frame);
        } on StateError {
          // An installed route may not have its first layout yet.
        }
      });
    })..start();
  }

  Future<void> _finishTrace() async {
    _ticker?.dispose();
    _ticker = null;
    _recorder = null;
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }

  Future<void> _present({bool replay = false}) async {
    final controller = IosSheetController();
    _active = controller;
    final detents = _detentList();
    final initial = detents.any((e) => e.identifier == 'medium')
        ? 'medium'
        : detents.first.identifier;
    // UIKit prepares its controller/configuration before present.requested.
    // Keep route/content construction outside the timed command boundary too.
    final navigator = Navigator.of(context);
    final route = StupidSimpleIosSheetRoute<void>(
      profile: _profile(),
      controller: controller,
      detents: detents,
      initialDetentIdentifier: initial,
      largestUndimmedDetentIdentifier: _undimmed ? initial : null,
      draggable: _draggable,
      interactiveDismissDisabled: _dismissLocked,
      contentInteraction: _scrollFirst
          ? IosSheetContentInteraction.scrolls
          : IosSheetContentInteraction.resizes,
      onPresented: () => _recorder?.eventWithProvenance(
        'present.completed',
        implementationProvenance: {
          'detector': 'engine status; not native physical settling',
        },
      ),
      onDismissed: () => _recorder?.event('dismiss.completed'),
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          _sheetContent(controller),
          if (_grabber)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
            ),
          if (_debug)
            Positioned(
              top: 30,
              left: 12,
              right: 12,
              child: ListenableBuilder(
                listenable: controller,
                builder: (_, _) => ColoredBox(
                  color: Colors.black87,
                  child: Text(
                    'selected=${controller.selectedDetentIdentifier}\n'
                    'target=${controller.targetDetentIdentifier}\n'
                    'height=${controller.visibleHeight.toStringAsFixed(3)} '
                    'modal=${controller.isModal}\n${_lastFrame?.metrics ?? {}}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    late Future<void> popped;
    void requestPresentation() {
      _recorder?.event('present.requested');
      popped = navigator.push(route);
    }

    if (replay) {
      final clock = Stopwatch()..start();
      await ProgrammaticReplay(clock: () => clock.elapsed).run(
        present: requestPresentation,
        select: (identifier) {
          if (!controller.isAttached) {
            throw StateError('Sheet disappeared before replay command');
          }
          _recorder?.event('detent.requested', {'target': identifier});
          controller.selectDetent(identifier);
        },
        dismiss: () {
          if (!controller.isAttached) {
            throw StateError('Sheet disappeared before dismissal');
          }
          _recorder?.event('dismiss.requested');
          controller.dismiss();
        },
      );
    } else {
      requestPresentation();
    }
    await popped;
    while (controller.isAttached) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    _active = null;
    controller.dispose();
  }

  Future<void> _runBatch() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _detents = 'reference';
      _content = 'calibration';
      _draggable =
          true; // The paired native recipe has no nondraggable variant.
    });
    const trials = int.fromEnvironment('SHEET_TRIALS', defaultValue: 10);
    try {
      for (var trial = 1; trial <= trials; trial++) {
        await _beginTrace(trial);
        if (!mounted) return;
        await _present(replay: true);
        await _finishTrace();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    } on MissingPluginException {
      // The metadata bridge is only available in the native iOS candidate.
    } finally {
      await _finishTrace();
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _sheetContent(IosSheetController controller) => switch (_content) {
    'long_scroll' => ListView.builder(
      itemCount: 100,
      itemExtent: 50,
      itemBuilder: (_, i) => ListTile(title: Text('Row $i')),
    ),
    'short_scroll' => ListView(
      children: const [
        SizedBox(height: 100, child: Center(child: Text('Short content'))),
      ],
    ),
    'keyboard' => const Padding(
      padding: EdgeInsets.all(24),
      child: TextField(decoration: InputDecoration(labelText: 'Keyboard test')),
    ),
    'pager' => PageView(
      children: List.generate(
        3,
        (i) => Center(child: Text('Horizontal page $i')),
      ),
    ),
    _ => CalibrationContent(controller: controller),
  };

  Widget _switch(String title, bool value, ValueChanged<bool> update) =>
      SwitchListTile(
        title: Text(title),
        value: value,
        onChanged: (v) => setState(() => update(v)),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('iOS sheet reference')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Opaque surface. Native timing, gestures, keyboard and '
          'stacking remain under measurement.',
        ),
        DropdownButton<int>(
          value: _major,
          items: [26, 27]
              .map(
                (v) =>
                    DropdownMenuItem(value: v, child: Text('iOS $v profile')),
              )
              .toList(),
          onChanged: (v) => setState(() => _major = v!),
        ),
        DropdownButton<String>(
          value: _detents,
          items: ['reference', 'single', 'custom', 'fraction']
              .map(
                (v) => DropdownMenuItem(value: v, child: Text('Detents: $v')),
              )
              .toList(),
          onChanged: (v) => setState(() => _detents = v!),
        ),
        DropdownButton<String>(
          value: _content,
          items:
              [
                    'calibration',
                    'short_scroll',
                    'long_scroll',
                    'keyboard',
                    'pager',
                  ]
                  .map(
                    (v) =>
                        DropdownMenuItem(value: v, child: Text('Content: $v')),
                  )
                  .toList(),
          onChanged: (v) => setState(() => _content = v!),
        ),
        _switch('Undimmed initial detent', _undimmed, (v) => _undimmed = v),
        _switch('Draggable', _draggable, (v) => _draggable = v),
        _switch(
          'Disable interactive dismissal',
          _dismissLocked,
          (v) => _dismissLocked = v,
        ),
        _switch('Scroll content first', _scrollFirst, (v) => _scrollFirst = v),
        _switch('Grabber', _grabber, (v) => _grabber = v),
        _switch(
          'Qualified 402 × 874 geometry',
          _qualified,
          (v) => _qualified = v,
        ),
        _switch('Debug overlay', _debug, (v) => _debug = v),
        FilledButton(
          onPressed: _busy ? null : () => _present(),
          child: const Text('Present sheet'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : _runBatch,
          child: const Text('Record paired programmatic trials'),
        ),
        TextButton(
          onPressed: () => setState(() => _backgroundTouches++),
          child: Text('Background touches: $_backgroundTouches'),
        ),
        for (final path in _traceFiles) SelectableText(path),
      ],
    ),
  );

  @override
  void dispose() {
    _ticker?.dispose();
    _sink?.close();
    super.dispose();
  }
}

class CalibrationContent extends StatelessWidget {
  const CalibrationContent({required this.controller, super.key});
  final IosSheetController controller;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: CustomPaint(painter: _RulerPainter())),
      const Center(child: Text('Calibration center')),
      const Positioned(left: 16, top: 20, child: Text('Top marker')),
      Positioned(
        bottom: 20,
        left: 12,
        right: 12,
        child: Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (final id in ['medium', 'large'])
              TextButton(
                onPressed: () => controller.selectDetent(id),
                child: Text(id),
              ),
            TextButton(
              onPressed: controller.dismiss,
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    ],
  );
}

class _RulerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y++) {
      canvas.drawLine(Offset(0, y), Offset(y % 10 == 0 ? 24 : 8, y), paint);
    }
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
