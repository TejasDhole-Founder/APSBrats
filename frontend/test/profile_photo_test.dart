import 'package:apsbrat_frontend/features/auth/data/auth_models.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:apsbrat_frontend/features/profile/presentation/widgets/profile_photo.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

import 'hugeicon_finder.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    AuthUser? me, {
    String? initials,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [meProvider.overrideWith((ref) async => me)],
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: ProfilePhotoButton(initials: initials)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  AuthUser user({String? photo}) => AuthUser.fromJson({
    'id': 'u1',
    'email': 'a@example.com',
    'needsOnboarding': false,
    'profilePicUrl': ?photo,
  });

  testWidgets('no photo yet: initials, and it offers to add one', (
    tester,
  ) async {
    await show(tester, user(), initials: 'AS');
    expect(find.text('AS'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Add a profile photo')),
      findsOneWidget,
    );
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('with a photo: shows it, and offers to change it', (
    tester,
  ) async {
    await show(tester, user(photo: '/media/avatars/u1.jpg'), initials: 'AS');
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(find.text('AS'), findsNothing);
    expect(find.bySemanticsLabel('Change profile photo'), findsOneWidget);
  });

  testWidgets('always shows the camera badge', (tester) async {
    await show(tester, user());
    expect(hugeIcon(HugeIcons.strokeRoundedCamera01), findsOneWidget);
  });
}
