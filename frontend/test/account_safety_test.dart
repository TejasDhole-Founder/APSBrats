import 'package:apsbrat_frontend/features/community/data/community_repository.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_models.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:apsbrat_frontend/features/profile/presentation/screens/profile_screen.dart';
import 'package:apsbrat_frontend/features/settings/data/block_repository.dart';
import 'package:apsbrat_frontend/features/settings/presentation/blocked_users_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Profile _profile({bool deleted = false}) => Profile(
  id: 'u1',
  username: deleted ? null : 'meera',
  fullName: 'Meera Iyer',
  bio: null,
  city: null,
  profession: null,
  phone: null,
  profilePicUrl: null,
  isVerified: false,
  isPrivate: false,
  currentStatus: 'ALUMNI',
  schools: const [],
  socials: const [],
  batchmatesCount: 0,
  schoolsCount: 0,
  connectedCount: 0,
  deleted: deleted,
);

void main() {
  test('Profile.fromJson reads the deleted flag (default false)', () {
    expect(Profile.fromJson({'id': 'a', 'fullName': 'X'}).deleted, isFalse);
    expect(
      Profile.fromJson({'id': 'a', 'fullName': 'X', 'deleted': true}).deleted,
      isTrue,
    );
  });

  test('reporting a user sends targetUserId, never targetId', () async {
    Map<String, dynamic>? sent;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          sent = Map<String, dynamic>.from(options.data as Map);
          handler.resolve(Response(requestOptions: options, statusCode: 200));
        },
      ),
    );
    final repo = CommunityRepository(dio);

    await repo.report('USER', 'user-1', 'SPAM');
    expect(sent, {
      'targetType': 'USER',
      'targetUserId': 'user-1',
      'reason': 'SPAM',
    });

    await repo.report('POST', 'post-1', 'SPAM');
    expect(sent, {
      'targetType': 'POST',
      'targetId': 'post-1',
      'reason': 'SPAM',
    });
  });

  testWidgets('a deleted profile shows the name as an unknown user', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider(
            'u1',
          ).overrideWith((ref) async => _profile(deleted: true)),
        ],
        child: const MaterialApp(home: ProfileScreen(userId: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Meera Iyer'), findsOneWidget);
    expect(find.text('Unknown user'), findsOneWidget);
    expect(find.text('This account was deleted'), findsOneWidget);
    // No actions on a deleted account.
    expect(find.byTooltip('More'), findsNothing);
    expect(find.text('Connect'), findsNothing);
  });

  testWidgets('blocked users: empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [blockedUsersProvider.overrideWith((ref) async => [])],
        child: const MaterialApp(home: BlockedUsersScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("You haven't blocked anyone"), findsOneWidget);
  });
}
