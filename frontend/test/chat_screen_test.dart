import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/core/network/paged_result.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_models.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_repository.dart';
import 'package:apsbrat_frontend/features/chat/presentation/screens/chat_screen.dart';
import 'package:dio/dio.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _rohit = Person(
  id: 'rohit',
  username: 'rohit',
  initials: 'RS',
  name: 'Rohit Singh',
  school: 'APS Pune',
  detail: '',
  city: null,
  job: null,
  currentStatus: 'ALUMNI',
  profilePicUrl: null,
  online: true,
  tags: [],
);

ChatMessage _msg(
  String id,
  String body, {
  required bool mine,
  required DateTime at,
  String? photo,
}) => ChatMessage(
  id: id,
  conversationId: 'c1',
  senderId: mine ? 'me' : 'rohit',
  body: body,
  imageUrl: photo,
  mine: mine,
  createdAt: at,
);

class FakeChatRepo extends ChatRepository {
  FakeChatRepo(this.history) : super(Dio());

  final List<ChatMessage> history;
  final sent = <String>[];

  @override
  Future<List<Conversation>> conversations() async => [
    Conversation(
      id: 'c1',
      person: _rohit,
      preview: null,
      time: null,
      unread: false,
      unreadCount: 0,
    ),
  ];

  @override
  Future<PagedResult<ChatMessage>> messages(
    String conversationId, {
    String? cursor,
    int limit = 30,
  }) async => PagedResult(items: history, nextCursor: null, hasMore: false);

  @override
  Future<ChatMessage> send(
    String conversationId,
    String body, {
    String? imageUrl,
  }) async {
    sent.add(body);
    return _msg('s${sent.length}', body, mine: true, at: DateTime.now());
  }

  @override
  Future<void> markRead(String conversationId) async {}
}

void main() {
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));

  group('rows', () {
    test(
      'a date chip starts each day; a change of sender starts a new group',
      () {
        final rows = buildChatRows([
          _msg('1', 'hi', mine: false, at: yesterday),
          _msg(
            '2',
            'there',
            mine: false,
            at: yesterday.add(const Duration(minutes: 1)),
          ),
          _msg('3', 'hey!', mine: true, at: now),
        ]);
        expect(rows.map((r) => r.runtimeType.toString()).toList(), [
          'ChatDateRow',
          'ChatMessageRow',
          'ChatMessageRow',
          'ChatDateRow',
          'ChatMessageRow',
        ]);
        expect((rows[1] as ChatMessageRow).firstOfGroup, isTrue);
        expect((rows[2] as ChatMessageRow).firstOfGroup, isFalse);
        expect((rows[4] as ChatMessageRow).firstOfGroup, isTrue);
      },
    );

    test('day labels read like WhatsApp', () {
      final n = DateTime(2026, 10, 4, 12);
      expect(chatDayLabel(n, now: n), 'Today');
      expect(chatDayLabel(DateTime(2026, 10, 3), now: n), 'Yesterday');
      expect(chatDayLabel(DateTime(2026, 9, 30), now: n), 'Wednesday');
      expect(chatDayLabel(DateTime(2026, 8, 15), now: n), '15 August 2026');
    });
  });

  Future<FakeChatRepo> open(
    WidgetTester tester,
    List<ChatMessage> history,
  ) async {
    final repo = FakeChatRepo(history);
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ChatScreen(conversationId: 'c1')),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets(
    'header, messages, date chips; no voice, payment or call buttons',
    (tester) async {
      await open(tester, [
        _msg('1', 'Bro you saw the group?', mine: false, at: yesterday),
        _msg('2', 'Yes!', mine: true, at: now),
      ]);
      expect(find.text('Rohit Singh'), findsOneWidget);
      expect(find.text('online'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(
        find.textContaining('Bro you saw the group?', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.byIcon(Icons.done_rounded),
        findsOneWidget,
      ); // my message is sent
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byIcon(Icons.videocam_outlined), findsNothing);
      expect(find.byIcon(Icons.call_outlined), findsNothing);
      expect(find.byTooltip('Send a photo'), findsOneWidget);
      expect(find.byTooltip('Take a photo'), findsOneWidget);
    },
  );

  testWidgets(
    'emoji button opens the emoji panel; tapping an emoji types it; keyboard button closes it',
    (tester) async {
      SharedPreferences.setMockInitialValues(
        {},
      ); // the panel remembers recent emojis
      await open(tester, []);
      await tester.enterText(find.byType(TextField).first, 'Hi ');
      await tester.tap(find.byTooltip('Emoji'));
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPicker), findsOneWidget);

      // Recent is empty at first; go to the smileys tab and pick the first one.
      await tester.tap(find.byIcon(Icons.tag_faces));
      await tester.pumpAndSettle();
      final first = find
          .descendant(
            of: find.byType(EmojiPicker),
            matching: find.byType(EmojiCell),
          )
          .first;
      final emoji = tester.widget<EmojiCell>(first).emoji.emoji;
      await tester.tap(first);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Hi $emoji',
      );

      await tester.tap(find.byTooltip('Keyboard'));
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPicker), findsNothing);
    },
  );

  testWidgets('send is off until something is typed, then sends and clears', (
    tester,
  ) async {
    final repo = await open(tester, []);
    final send = find.byTooltip('Send');
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.send_rounded),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), 'Hello Rohit');
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(repo.sent, ['Hello Rohit']);
    expect(
      find.textContaining('Hello Rohit', findRichText: true),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });
}
