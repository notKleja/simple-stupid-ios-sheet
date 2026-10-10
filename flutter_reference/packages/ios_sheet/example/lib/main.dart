import 'package:flutter/cupertino.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

void main() => runApp(const Ios26SheetExampleApp());

/// A minimal app demonstrating the public iOS 26 sheet helper.
class Ios26SheetExampleApp extends StatelessWidget {
  const Ios26SheetExampleApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const CupertinoApp(title: 'iOS 26 sheet example', home: _ExampleHome());
}

class _ExampleHome extends StatefulWidget {
  const _ExampleHome();

  @override
  State<_ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<_ExampleHome> {
  final _controller = IosSheetController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(
      middle: Text('iOS 26 sheet example'),
    ),
    child: Center(
      child: CupertinoButton.filled(
        onPressed: () async {
          await showIos26Sheet<void>(
            context: context,
            controller: _controller,
            detents: const [IosSheetDetent.medium, IosSheetDetent.large],
            initialDetentIdentifier: 'medium',
            builder: (_) => ExampleSheetContent(controller: _controller),
          );
        },
        child: const Text('Show iOS 26 sheet'),
      ),
    ),
  );
}

/// Sheet content with semantic detent controls and explicit dismissal.
class ExampleSheetContent extends StatelessWidget {
  const ExampleSheetContent({required this.controller, super.key});

  /// The controller owned by the presenting page.
  final IosSheetController controller;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('iOS 26 sheet content'),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: controller,
            builder: (_, _) =>
                Text('Selected detent: ${controller.selectedDetentIdentifier}'),
          ),
          CupertinoButton(
            onPressed: () => controller.selectDetent('medium'),
            child: const Text('Medium'),
          ),
          CupertinoButton(
            onPressed: () => controller.selectDetent('large'),
            child: const Text('Large'),
          ),
          CupertinoButton(
            onPressed: controller.dismiss,
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}
