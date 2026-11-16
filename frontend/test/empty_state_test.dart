import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the empty-inbox illustration loads on a phone-sized screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EmptyState(
              icon: HugeIcons.strokeRoundedMessage01,
              image: kEmptyInboxImage,
              title: 'No messages yet',
              message: 'Your chats will show up here.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('No messages yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
