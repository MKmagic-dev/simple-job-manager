import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/core/files/photo_cropper.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';

// A valid 1x1 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Widget _host(Widget home) => MaterialApp(
  locale: const Locale('pl'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  testWidgets('the photo adjust screen explains itself and can be left', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Uint8List? result = Uint8List(0);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => result = await cropPhoto(context, _png),
                child: const Text('otwórz'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('otwórz'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('Dostosuj obraz'), findsOneWidget);
    expect(find.text('Użyj tego kadru'), findsOneWidget);
    expect(find.textContaining('Przesuń zdjęcie'), findsOneWidget);

    // Backing out (the close button of the full-screen page) returns nothing.
    await tester.tap(find.byType(CloseButton));
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}
