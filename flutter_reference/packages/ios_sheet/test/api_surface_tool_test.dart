import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/api_surface.dart';

const _route = 'StupidSimpleIosSheetRoute';
const _transition = 'StupidSimpleSheetTransitionMixin';
const _controller = 'StupidSimpleSheetController';

Map<String, Object?> _entry(String name, int kind, {String? owner}) => {
  'name': name,
  'qualifiedName':
      'simple_stupid_ios_sheet.${owner == null ? '' : '$owner.'}$name',
  'kind': kind,
  'href': 'unstable/$name.html',
  'overriddenDepth': 0,
  if (owner != null) 'enclosedBy': {'name': owner, 'kind': 3},
};

final _wrapperIndex = <Object?>[
  _entry('IosSheetProfile', 3),
  _entry('ios27', 16, owner: 'IosSheetProfile'),
  _entry('profile', 16, owner: _route),
  _entry('motion', 16, owner: _route),
  _entry('animateToRelative', 10, owner: _route),
  _entry('overrideSnappingConfig', 10, owner: _route),
  _entry('navigator', 16, owner: _route),
  _entry('popDisposition', 16, owner: _route),
  _entry('maybeOf', 10, owner: _route),
];
final _engineIndex = <Object?>[
  _entry('motion', 16, owner: _transition),
  // Dartdoc labels SDK inheritance with an engine owner too.
  _entry('navigator', 16, owner: _transition),
  _entry('animateToRelative', 10, owner: _controller),
  _entry('overrideSnappingConfig', 10, owner: _controller),
  _entry('maybeOf', 10, owner: _controller),
];
const _routeHtml = '''
<section id="instance-properties"><dl>
<dt class="property" id="profile"></dt>
<dt id="motion" class="property"><a class="deprecated" href="motion.html">motion</a></dt>
<dt id="navigator" class="inherited property"></dt>
<dt id="popDisposition" class="property inherited extra"></dt>
</dl></section>
<section id="instance-methods"><dl>
<dt id="animateToRelative" class="callable inherited"></dt>
<dt id="overrideSnappingConfig" class="callable inherited"></dt>
<dt id="maybeOf" class="callable inherited"></dt>
</dl></section>
''';
const _engineHtml = <String, String>{
  _transition: '''
<section id="instance-properties"><dl>
<dt id="motion" class="property"></dt>
<dt id="navigator" class="property inherited"></dt>
</dl></section>
''',
  _controller: '''
<section id="instance-methods"><dl>
<dt id="animateToRelative" class="callable"></dt>
<dt class="callable" id="overrideSnappingConfig"></dt>
</dl></section>
<section class="summary" id="static-methods"><dl>
<dt id="maybeOf" class="callable"></dt>
</dl></section>
''',
};

void main() {
  test(
    'keeps declarations and actual engine inheritance, excluding SDK and static entries',
    () {
      final symbols = normalizeApiSurface(
        wrapperIndex: _wrapperIndex,
        engineIndex: _engineIndex,
        routeHtml: _routeHtml,
        engineOwnerHtml: _engineHtml,
      );
      expect(symbols.map((e) => e.qualifiedName), [
        'simple_stupid_ios_sheet.IosSheetProfile',
        'simple_stupid_ios_sheet.IosSheetProfile.ios27',
        'simple_stupid_ios_sheet.$_route.animateToRelative',
        'simple_stupid_ios_sheet.$_route.motion',
        'simple_stupid_ios_sheet.$_route.overrideSnappingConfig',
        'simple_stupid_ios_sheet.$_route.profile',
      ]);
      final ios27 = symbols.singleWhere(
        (e) => e.qualifiedName.endsWith('.ios27'),
      );
      expect(ios27.kind, 16);
      expect(ios27.enclosingOwner, 'IosSheetProfile');
    },
  );

  test('fails closed when ownership HTML or a route row is missing', () {
    expect(
      () => normalizeApiSurface(
        wrapperIndex: _wrapperIndex,
        engineIndex: _engineIndex,
        routeHtml: _routeHtml,
        engineOwnerHtml: const {},
      ),
      throwsFormatException,
    );
    expect(
      () => normalizeApiSurface(
        wrapperIndex: [_entry('missing', 16, owner: _route)],
        engineIndex: _engineIndex,
        routeHtml: _routeHtml,
        engineOwnerHtml: _engineHtml,
      ),
      throwsFormatException,
    );
  });

  test(
    'serializes stable fields in sorted order without changing the input',
    () {
      final symbols = [
        const ApiSymbol(qualifiedName: 'b.B', kind: 16, enclosingOwner: 'B'),
        const ApiSymbol(qualifiedName: 'a.A', kind: 3, enclosingOwner: null),
      ];
      expect(jsonDecode(encodeApiSurface(symbols)), [
        {'qualifiedName': 'a.A', 'kind': 3, 'enclosingOwner': null},
        {'qualifiedName': 'b.B', 'kind': 16, 'enclosingOwner': 'B'},
      ]);
      expect(symbols.first.qualifiedName, 'b.B');
      expect(encodeApiSurface(symbols), isNot(contains('href')));
      expect(encodeApiSurface(symbols), isNot(contains('overriddenDepth')));
    },
  );

  test(
    'reports removals and kind or owner changes as breaking, and additions separately',
    () {
      final baseline = [
        const ApiSymbol(
          qualifiedName: 'removed',
          kind: 3,
          enclosingOwner: null,
        ),
        const ApiSymbol(qualifiedName: 'kind', kind: 16, enclosingOwner: 'A'),
        const ApiSymbol(qualifiedName: 'owner', kind: 16, enclosingOwner: 'A'),
      ];
      final current = [
        const ApiSymbol(qualifiedName: 'added', kind: 3, enclosingOwner: null),
        const ApiSymbol(qualifiedName: 'kind', kind: 10, enclosingOwner: 'A'),
        const ApiSymbol(qualifiedName: 'owner', kind: 16, enclosingOwner: 'B'),
      ];
      final diff = compareApiSurfaces(baseline, current);
      expect(diff.removed.map((e) => e.qualifiedName), ['removed']);
      expect(diff.changed.map((e) => e.qualifiedName), ['kind', 'owner']);
      expect(diff.added.map((e) => e.qualifiedName), ['added']);
      expect(diff.hasBreakingChanges, isTrue);
      expect(compareApiSurfaces([], current).hasBreakingChanges, isFalse);
    },
  );

  test(
    'update and check CLIs enforce compatibility using real files',
    () async {
      final temporary = Directory.systemTemp.createTempSync(
        'ios-sheet-api-test-',
      );
      addTearDown(() => temporary.deleteSync(recursive: true));
      File write(String name, String content) =>
          File('${temporary.path}/$name')..writeAsStringSync(content);
      final wrapper = write('wrapper.json', jsonEncode(_wrapperIndex));
      final engine = write(
        'engine.json',
        jsonEncode([
          ..._engineIndex,
          {'name': _transition, 'href': 'transition-mixin.html'},
          {'name': _controller, 'href': 'controller-mixin.html'},
        ]),
      );
      final route = write('route.html', _routeHtml);
      write('transition-mixin.html', _engineHtml[_transition]!);
      write('controller-mixin.html', _engineHtml[_controller]!);
      final baseline = File('${temporary.path}/baseline.json');
      final packagePath = Directory('packages/ios_sheet').existsSync()
          ? Directory('packages/ios_sheet').absolute.path
          : Directory.current.path;
      Future<ProcessResult> run(String script) => Process.run('dart', [
        '$packagePath/tool/$script',
        wrapper.path,
        engine.path,
        route.path,
        baseline.path,
      ]);
      final update = await run('update_api_surface.dart');
      expect(update.exitCode, 0, reason: '${update.stdout}\n${update.stderr}');
      final original = baseline.readAsStringSync();
      final check = await run('check_api_surface.dart');
      expect(check.exitCode, 0, reason: '${check.stdout}\n${check.stderr}');
      wrapper.writeAsStringSync(
        jsonEncode([..._wrapperIndex, _entry('NewApi', 3)]),
      );
      final addition = await run('check_api_surface.dart');
      expect(addition.exitCode, 0);
      expect(addition.stdout, contains('NewApi'));
      expect(baseline.readAsStringSync(), original);
      wrapper.writeAsStringSync(
        jsonEncode(
          _wrapperIndex.where((e) => (e! as Map)['name'] != 'ios27').toList(),
        ),
      );
      final removal = await run('check_api_surface.dart');
      expect(removal.exitCode, 1);
      expect('${removal.stdout}${removal.stderr}', contains('ios27'));
      wrapper.writeAsStringSync(
        jsonEncode([
          for (final entry in _wrapperIndex)
            if ((entry! as Map)['name'] == 'ios27')
              {...(entry as Map), 'kind': 10}
            else
              entry,
        ]),
      );
      final kindChange = await run('check_api_surface.dart');
      expect(kindChange.exitCode, 1);
      expect('${kindChange.stdout}${kindChange.stderr}', contains('ios27'));
    },
  );
}
