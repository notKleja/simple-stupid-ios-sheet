import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

class DemoAction {
  const DemoAction({required this.atMs, required this.type, required this.data});
  final int atMs;
  final String type;
  final Map<String, Object?> data;
}

class DemoScene {
  const DemoScene({
    required this.id,
    required this.language,
    required this.direction,
    required this.kind,
    required this.startMs,
    required this.durationMs,
    required this.title,
    required this.subtitle,
    required this.configuration,
    required this.actions,
  });

  final String id;
  final String language;
  final TextDirection direction;
  final String kind;
  final int startMs;
  final int durationMs;
  final String title;
  final String subtitle;
  final Map<String, Object?> configuration;
  final List<DemoAction> actions;

  int get endMs => startMs + durationMs;

  factory DemoScene.fromJson(Map<String, Object?> json) {
    final rawActions = json['actions']! as List<Object?>;
    return DemoScene(
      id: json['id']! as String,
      language: json['language']! as String,
      direction: json['direction'] == 'rtl' ? TextDirection.rtl : TextDirection.ltr,
      kind: json['kind']! as String,
      startMs: json['start_ms']! as int,
      durationMs: json['duration_ms']! as int,
      title: json['title']! as String,
      subtitle: json['subtitle']! as String,
      configuration: Map<String, Object?>.from(
        (json['configuration'] as Map<Object?, Object?>?) ?? const {},
      ),
      actions: rawActions.map((raw) {
        final map = Map<String, Object?>.from(raw! as Map<Object?, Object?>);
        return DemoAction(atMs: map.remove('at_ms')! as int, type: map.remove('type')! as String, data: map);
      }).toList(growable: false),
    );
  }
}

class DemoTimeline {
  const DemoTimeline({required this.durationMs, required this.scenes});
  final int durationMs;
  final List<DemoScene> scenes;

  factory DemoTimeline.fromJson(Map<String, Object?> json) => DemoTimeline(
    durationMs: json['duration_ms']! as int,
    scenes: (json['scenes']! as List<Object?>)
        .map((scene) => DemoScene.fromJson(Map<String, Object?>.from(scene! as Map<Object?, Object?>)))
        .toList(growable: false),
  );

  DemoScene sceneAt(int elapsedMs) {
    if (elapsedMs <= scenes.first.startMs) return scenes.first;
    return scenes.lastWhere(
      (scene) => elapsedMs >= scene.startMs && elapsedMs < scene.endMs,
      orElse: () => scenes.last,
    );
  }

  List<DemoAction> actionsBetween(int previousMs, int currentMs) {
    final due = <(int, DemoAction)>[];
    for (final scene in scenes) {
      for (final action in scene.actions) {
        final absolute = scene.startMs + action.atMs;
        if (absolute > previousMs && absolute <= currentMs) due.add((absolute, action));
      }
    }
    due.sort((a, b) => a.$1.compareTo(b.$1));
    return due.map((entry) => entry.$2).toList(growable: false);
  }
}

class DemoStage extends StatelessWidget {
  const DemoStage({
    required this.timeline,
    required this.elapsedMs,
    required this.implementation,
    this.backgroundPulse = 0,
    this.child,
    super.key,
  });

  final DemoTimeline timeline;
  final int elapsedMs;
  final String implementation;
  final int backgroundPulse;
  final Widget? child;

  String get _time {
    final clamped = elapsedMs.clamp(0, timeline.durationMs);
    final seconds = clamped ~/ 1000;
    final milliseconds = clamped % 1000;
    return '${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scene = timeline.sceneAt(elapsedMs);
    final introPulse = scene.kind == 'intro' ? (elapsedMs ~/ 1000) % 3 : backgroundPulse % 3;
    final colors = [const Color(0xFFF4F7FB), const Color(0xFFE6F5EE), const Color(0xFFFFF2D9)];
    return Directionality(
      textDirection: scene.direction,
      child: ColoredBox(
        color: colors[introPulse],
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: child ?? const SizedBox.shrink()),
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .82), borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('$implementation  •  ${scene.language.toUpperCase()}  •  $_time s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        const SizedBox(height: 3),
                        Text(scene.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(scene.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(scene.id, textAlign: TextAlign.end, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DemoComponentGallery extends StatelessWidget {
  const DemoComponentGallery({
    required this.language,
    required this.toggleValue,
    required this.onToggle,
    super.key,
  });

  final String language;
  final bool toggleValue;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 28),
      children: [
        Text(language == 'ar' ? 'معرض المكونات' : 'Component gallery', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        FilledButton(onPressed: () {}, child: Text(language == 'ar' ? 'زر أساسي' : 'Primary button')),
        SwitchListTile(value: toggleValue, onChanged: onToggle, title: Text(language == 'ar' ? 'مفتاح تبديل' : 'Toggle switch')),
        SegmentedButton<int>(segments: [ButtonSegment(value: 0, label: Text(language == 'ar' ? 'الأول' : 'First')), ButtonSegment(value: 1, label: Text(language == 'ar' ? 'الثاني' : 'Second'))], selected: {toggleValue ? 1 : 0}, onSelectionChanged: (_) {}),
        const SizedBox(height: 12),
        TextField(decoration: InputDecoration(border: const OutlineInputBorder(), labelText: language == 'ar' ? 'حقل نص' : 'Text field')),
        const SizedBox(height: 14),
        for (var index = 0; index < 3; index++) Container(height: 54, margin: const EdgeInsets.only(bottom: 8), alignment: Alignment.center, decoration: BoxDecoration(color: Colors.blue.withValues(alpha: .08 + index * .05), borderRadius: BorderRadius.circular(12)), child: Text(language == 'ar' ? 'كتلة ${index + 1}' : 'Fixed block ${index + 1}')),
      ],
    ),
  );
}

class SynchronizedDemoBootstrap extends StatefulWidget {
  const SynchronizedDemoBootstrap({required this.fallback, super.key});
  final Widget fallback;

  @override
  State<SynchronizedDemoBootstrap> createState() => _SynchronizedDemoBootstrapState();
}

class _SynchronizedDemoBootstrapState extends State<SynchronizedDemoBootstrap> {
  static const _metadata = MethodChannel('sheet_reference/metadata');
  Widget? _resolved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final metadata = await _metadata.invokeMapMethod<String, Object?>('capture');
      final demo = Map<String, Object?>.from((metadata?['demo'] as Map<Object?, Object?>?) ?? const {});
      if (demo['enabled'] == true) {
        final raw = await rootBundle.loadString('assets/synchronized_bilingual_demo.json');
        final timeline = DemoTimeline.fromJson(jsonDecode(raw) as Map<String, Object?>);
        final start = demo['start_epoch_ms']! as int;
        if (mounted) setState(() => _resolved = SynchronizedDemoApp(timeline: timeline, startEpochMs: start));
        return;
      }
    } on MissingPluginException {
      // Widget tests and non-iOS hosts use the playground.
    }
    if (mounted) setState(() => _resolved = widget.fallback);
  }

  @override
  Widget build(BuildContext context) => _resolved ?? const ColoredBox(color: Colors.white, child: Center(child: CircularProgressIndicator()));
}

class SynchronizedDemoApp extends StatelessWidget {
  const SynchronizedDemoApp({required this.timeline, required this.startEpochMs, super.key});
  final DemoTimeline timeline;
  final int startEpochMs;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: child!,
    ),
    home: _LiveDemo(timeline: timeline, startEpochMs: startEpochMs),
  );
}

class _LiveDemo extends StatefulWidget {
  const _LiveDemo({required this.timeline, required this.startEpochMs});
  final DemoTimeline timeline;
  final int startEpochMs;

  @override
  State<_LiveDemo> createState() => _LiveDemoState();
}

class _LiveDemoState extends State<_LiveDemo> {
  Timer? _timer;
  int _elapsedMs = -1;
  int _previousMs = -1;
  int _backgroundPulse = 0;
  bool _toggle = false;
  IosSheetController? _sheet;
  ScrollController? _scroll;
  DemoScene? _presentedScene;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    _tick();
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = now - widget.startEpochMs;
    if (current < 0) {
      setState(() => _elapsedMs = current);
      return;
    }
    final capped = current.clamp(0, widget.timeline.durationMs);
    final actions = widget.timeline.actionsBetween(_previousMs, capped);
    _previousMs = capped;
    setState(() => _elapsedMs = capped);
    for (final action in actions) {
      _perform(action);
    }
    if (current > widget.timeline.durationMs + 500) _timer?.cancel();
  }

  Future<void> _perform(DemoAction action) async {
    switch (action.type) {
      case 'present':
        await _present(action.data['detent']! as String);
      case 'select':
        _sheet?.selectDetent(action.data['detent']! as String);
      case 'scroll':
        await _scroll?.animateTo((action.data['offset']! as num).toDouble(), duration: const Duration(milliseconds: 900), curve: Curves.easeInOutCubic);
      case 'background_pulse':
        if (mounted) setState(() => _backgroundPulse++);
      case 'toggle':
        if (mounted) setState(() => _toggle = !_toggle);
      case 'dismiss_attempt':
        // Property demonstration only; interactive input proof remains in native traces.
        if (mounted) setState(() => _backgroundPulse++);
      case 'dismiss':
        _sheet?.dismiss();
    }
  }

  List<IosSheetDetent> _detents(DemoScene scene) => scene.configuration['detents'] == 'custom'
      ? [IosSheetDetent.height('small', 240), IosSheetDetent.height('middle', 420), IosSheetDetent.large]
      : [IosSheetDetent.height('fixed320', 320), IosSheetDetent.medium, IosSheetDetent.large];

  Future<void> _present(String initial) async {
    final scene = widget.timeline.sceneAt(_elapsedMs);
    _presentedScene = scene;
    _scroll = scene.configuration['content'] == 'long_scroll' ? ScrollController() : null;
    final controller = IosSheetController();
    _sheet = controller;
    if (!mounted) return;
    final route = StupidSimpleIosSheetRoute<void>(
      profile: observedPage402x874Profile(26),
      controller: controller,
      detents: _detents(scene),
      initialDetentIdentifier: initial,
      largestUndimmedDetentIdentifier: scene.configuration['largest_undimmed'] as String?,
      interactiveDismissDisabled: scene.configuration['dismissal_locked'] == true,
      contentInteraction: scene.configuration['scroll_expansion'] == false ? IosSheetContentInteraction.scrolls : IosSheetContentInteraction.resizes,
      backgroundColor: Colors.white,
      child: Material(color: Colors.white, child: Directionality(textDirection: scene.direction, child: _content(scene))),
    );
    await Navigator.of(context).push(route);
    _sheet = null;
    _presentedScene = null;
    _scroll?.dispose();
    _scroll = null;
    controller.dispose();
  }

  Widget _content(DemoScene scene) {
    if (scene.configuration['content'] == 'long_scroll') {
      return ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 42, 20, 28),
        itemCount: 30,
        itemBuilder: (_, index) => Card(child: ListTile(leading: CircleAvatar(child: Text('${index + 1}')), title: Text(scene.language == 'ar' ? 'عنصر القائمة ${index + 1}' : 'List row ${index + 1}'), subtitle: Text(scene.language == 'ar' ? 'محتوى قابل للتمرير' : 'Scrollable content'))),
      );
    }
    if (scene.configuration['content'] == 'components') {
      return DemoComponentGallery(
        language: scene.language,
        toggleValue: _toggle,
        onToggle: (value) => setState(() => _toggle = value),
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _DemoRulerPainter())),
        Center(child: Text(scene.language == 'ar' ? 'علامة المنتصف' : 'Calibration center', style: const TextStyle(color: Colors.black, fontSize: 16))),
        Positioned(left: 20, right: 20, bottom: 24, child: Text(scene.language == 'ar' ? 'المعرف: ${scene.id}' : 'Scenario: ${scene.id}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 14))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DemoStage(
      timeline: widget.timeline,
      elapsedMs: _elapsedMs,
      implementation: 'FLUTTER',
      backgroundPulse: _backgroundPulse,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 118, left: 24, right: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.layers_rounded, size: 72, color: Colors.blue),
              const SizedBox(height: 16),
              Text(_presentedScene?.language == 'ar' ? 'خلفية التطبيق قابلة للملاحظة' : 'Live application background', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              Text('pulse=$_backgroundPulse  toggle=${_toggle ? 'on' : 'off'}', style: const TextStyle(fontFamily: 'monospace')),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _timer?.cancel();
    _scroll?.dispose();
    super.dispose();
  }
}

class _DemoRulerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black12..strokeWidth = 1;
    for (double y = .5; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(y % 64 < 1 ? 28 : 10, y), paint);
      canvas.drawLine(Offset(size.width - (y % 64 < 1 ? 28 : 10), y), Offset(size.width, y), paint);
    }
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
