import 'package:apsbrat_frontend/core/media/photos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'server photo addresses get the server in front; full links are kept',
    () {
      expect(
        mediaUrl('/media/uploads/u/p.jpg'),
        'http://localhost:8080/media/uploads/u/p.jpg',
      );
      expect(
        mediaUrl('https://cdn.example/p.jpg'),
        'https://cdn.example/p.jpg',
      );
    },
  );

  Future<void> showSlider(WidgetTester tester, List<String> urls) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 320, child: PhotoSlider(urls: urls)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('one photo: no counter or dots', (tester) async {
    await showSlider(tester, ['/media/a.jpg']);
    expect(find.text('1/1'), findsNothing);
    expect(find.byType(AnimatedContainer), findsNothing);
  });

  testWidgets('several photos: swipe moves the counter and the dots', (
    tester,
  ) async {
    await showSlider(tester, ['/media/a.jpg', '/media/b.jpg', '/media/c.jpg']);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNWidgets(3));
    expect(find.bySemanticsLabel('Photo 1 of 3'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
    expect(find.bySemanticsLabel('Photo 2 of 3'), findsOneWidget);
  });

  testWidgets('every slider keeps the same 4:5 frame', (tester) async {
    await showSlider(tester, ['/media/a.jpg', '/media/b.jpg']);
    final size = tester.getSize(find.byType(AspectRatio));
    expect(size.width / size.height, closeTo(0.8, 0.001));
  });
}
