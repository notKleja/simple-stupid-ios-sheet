import 'package:flutter_test/flutter_test.dart';
import 'package:ios_sheet_engine/src/controller_lifecycle_bridge.dart';

void main() {
  test('unregistered routes proceed without invoking lifecycle callbacks', () {
    final route = Object();
    dispatchSheetDragStart(route);
    dispatchSheetDragEnd(route);
    dispatchSheetDragCancel(route);
    expect(dispatchSheetProgrammaticDetentStart(route), isTrue);
  });

  test('registration dispatches only its route and unregister is idempotent',
      () {
    final route = Object();
    final events = <String>[];
    final unregister = registerSheetControllerLifecycle(
      route,
      SheetControllerLifecycleCallbacks(
        onDragStart: () => events.add('start'),
        onDragEnd: () => events.add('end'),
        onDragCancel: () => events.add('cancel'),
        onProgrammaticDetentStart: () {
          events.add('motion');
          return false;
        },
      ),
    );
    dispatchSheetDragStart(Object());
    dispatchSheetDragStart(route);
    dispatchSheetDragEnd(route);
    dispatchSheetDragCancel(route);
    expect(dispatchSheetProgrammaticDetentStart(route), isFalse);
    expect(events, ['start', 'end', 'cancel', 'motion']);
    unregister();
    unregister();
    dispatchSheetDragStart(route);
    dispatchSheetDragEnd(route);
    dispatchSheetDragCancel(route);
    expect(dispatchSheetProgrammaticDetentStart(route), isTrue);
    expect(events, ['start', 'end', 'cancel', 'motion']);
  });

  test('stale unregister cannot remove replacement registration', () {
    final route = Object();
    final events = <String>[];
    final old = registerSheetControllerLifecycle(
      route,
      SheetControllerLifecycleCallbacks(onDragStart: () => events.add('old')),
    );
    final current = registerSheetControllerLifecycle(
      route,
      SheetControllerLifecycleCallbacks(onDragStart: () => events.add('new')),
    );
    old();
    dispatchSheetDragStart(route);
    expect(events, ['new']);
    current();
    dispatchSheetDragStart(route);
    expect(events, ['new']);
  });

  test('cleanup invalidates callbacks and retained unregister is harmless', () {
    final route = Object();
    final events = <String>[];
    final unregister = registerSheetControllerLifecycle(
      route,
      SheetControllerLifecycleCallbacks(onDragStart: () => events.add('start')),
    );
    clearSheetControllerLifecycle(route);
    clearSheetControllerLifecycle(route);
    dispatchSheetDragStart(route);
    expect(dispatchSheetProgrammaticDetentStart(route), isTrue);
    unregister();
    expect(events, isEmpty);
  });

  test('unregister from callback prevents subsequent dispatch', () {
    final route = Object();
    final events = <String>[];
    late final void Function() unregister;
    unregister = registerSheetControllerLifecycle(
      route,
      SheetControllerLifecycleCallbacks(
        onDragStart: () {
          events.add('start');
          unregister();
          dispatchSheetDragEnd(route);
        },
        onDragEnd: () => events.add('end'),
      ),
    );
    dispatchSheetDragStart(route);
    expect(events, ['start']);
  });
}
