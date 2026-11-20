import 'dart:async';

import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/features/community/data/community_models.dart';
import 'package:apsbrat_frontend/features/community/data/community_repository.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/community/presentation/communities_tab.dart';
import 'package:apsbrat_frontend/features/community/presentation/community_chat_screen.dart';
import 'package:apsbrat_frontend/features/community/presentation/event_screen.dart';
import 'package:apsbrat_frontend/features/community/presentation/community_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

import 'hugeicon_finder.dart';

const _me = Person(
  id: 'me',
  username: 'arjun',
  initials: 'AS',
  name: 'Arjun Singh',
  school: 'APS Pune',
  detail: '',
  city: null,
  job: null,
  currentStatus: 'ALUMNI',
  profilePicUrl: null,
  online: false,
  tags: [],
);

Community _community({
  String id = 'c1',
  String type = 'INTEREST',
  String name = 'Software Developers',
  String visibility = 'OPEN',
  int members = 3,
  String? myRole,
  bool requested = false,
}) => Community(
  id: id,
  type: type,
  name: name,
  visibility: visibility,
  memberCount: members,
  myRole: myRole,
  requested: requested,
);

Post _post(String id, String body, {int likes = 0, bool liked = false}) => Post(
  id: id,
  communityId: 'c1',
  communityName: 'Software Developers',
  author: _me,
  body: body,
  likeCount: likes,
  commentCount: 0,
  likedByMe: liked,
  canDelete: true,
  createdAt: DateTime.now(),
);

/// Stands in for the backend.
class FakeRepo extends CommunityRepository {
  FakeRepo() : super(Dio());

  MyCommunities mineResult = const MyCommunities(joined: [], suggested: []);
  List<Community> discoverResult = const [];
  Community community = _community(myRole: 'MEMBER');
  List<Post> feedPosts = [];
  final joined = <String>[];
  Completer<Post>? likeReply;

  @override
  Future<MyCommunities> mine() async => mineResult;

  @override
  Future<List<Community>> discover(String query) async => discoverResult;

  @override
  Future<Community> get(String id) async => community;

  @override
  Future<Community> join(String id) async {
    joined.add(id);
    return _community(id: id, myRole: 'MEMBER');
  }

  final sorts = <String>[];

  @override
  Future<PageOf<Post>> posts({
    String? communityId,
    String? cursor,
    String sort = 'latest',
  }) async {
    sorts.add(sort);
    return PageOf(items: feedPosts, hasMore: false);
  }

  @override
  Future<Post> createPost(
    String communityId,
    String body, {
    List<String> imageUrls = const [],
    String? eventId,
    int? memoryYear,
    String? memoryCategory,
  }) async => _post('new', body.trim());

  List<Post> memoryPosts = [];
  final memoryQueries = <MemoriesQuery>[];

  @override
  Future<PageOf<Post>> memories(MemoriesQuery query, {String? cursor}) async {
    memoryQueries.add(query);
    return PageOf(items: memoryPosts, hasMore: false);
  }

  @override
  Future<List<int>> memoryYears(String communityId) async => [2012, 2008];

  List<Person> memberList = const [];

  @override
  Future<List<Person>> members(CommunityMembersQuery query) async => memberList;

  EventList eventList = const EventList(events: [], canCreate: false);
  CommunityEvent? theEvent;
  final rsvps = <String?>[];

  @override
  Future<EventList> events(String communityId, {bool past = false}) async =>
      past ? const EventList(events: [], canCreate: false) : eventList;

  @override
  Future<CommunityEvent> event(String id) async => theEvent!;

  @override
  Future<CommunityEvent> setRsvp(String id, String? status) async {
    rsvps.add(status);
    return theEvent!;
  }

  @override
  Future<PageOf<Post>> eventPosts(String eventId, {String? cursor}) async =>
      const PageOf(items: [], hasMore: false);

  @override
  Future<Post> setLiked(String postId, {required bool liked}) =>
      likeReply!.future;

  List<CommunityMessage> chat = [];
  CommunityChatSummary summary = const CommunityChatSummary(
    unreadCount: 0,
    canModerate: false,
  );

  @override
  Future<CommunityChatSummary> chatSummary(String communityId) async => summary;

  @override
  Future<PageOf<CommunityMessage>> chatMessages(
    String communityId, {
    String? cursor,
  }) async => PageOf(items: chat, hasMore: false);

  @override
  Future<CommunityMessage> sendChatMessage(
    String communityId,
    String body, {
    String? imageUrl,
  }) async => _message('m-new', _me, body);

  @override
  Future<void> markChatRead(String communityId) async {}
}

const _rahul = Person(
  id: 'rahul',
  username: 'rahul',
  initials: 'RS',
  name: 'Rahul Sharma',
  school: 'APS Pune',
  detail: '',
  city: null,
  job: null,
  currentStatus: 'ALUMNI',
  profilePicUrl: null,
  online: false,
  tags: [],
);

CommunityMessage _message(String id, Person sender, String body) =>
    CommunityMessage(
      id: id,
      communityId: 'c1',
      sender: sender,
      body: body,
      createdAt: DateTime.now(),
    );

void main() {
  late FakeRepo repo;

  setUp(() => repo = FakeRepo());

  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityRepositoryProvider.overrideWithValue(repo),
          myUserIdProvider.overrideWith((ref) async => 'me'),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the tab shows my schools to join, what I joined, and Discover', (
    tester,
  ) async {
    repo.mineResult = MyCommunities(
      joined: [
        _community(
          id: 'c2',
          name: 'NDA Aspirants',
          visibility: 'PRIVATE',
          myRole: 'OWNER',
        ),
      ],
      suggested: [
        _community(id: 's1', type: 'SCHOOL', name: 'APS Pune', members: 0),
      ],
    );
    repo.discoverResult = [
      _community(id: 'c3', name: 'Lawyers', visibility: 'PRIVATE'),
    ];
    await show(tester, const CommunitiesTab());

    expect(find.text('Your Schools'), findsOneWidget);
    expect(find.text('APS Pune'), findsOneWidget);
    expect(find.text('School · 0 members'), findsOneWidget);
    // What I'm in: the swipeable row (name and member count on the card).
    expect(find.text('NDA Aspirants'), findsOneWidget);
    expect(find.text('3 members'), findsWidgets);
    // Discover: a private group says Request, not Join.
    expect(find.text('Private · 3 members'), findsOneWidget);
    expect(find.text('Request'), findsOneWidget);

    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    expect(repo.joined, ['s1']);
  });

  testWidgets('nothing joined or found: a note and the add button to create', (
    tester,
  ) async {
    await show(tester, const CommunitiesTab());
    expect(find.text("You're in every group so far."), findsOneWidget);
    expect(hugeIcon(HugeIcons.strokeRoundedAdd01), findsOneWidget);
  });

  testWidgets('a member posts and the new post appears on top', (tester) async {
    repo.feedPosts = [_post('p1', 'Older post')];
    await show(tester, const CommunityScreen(communityId: 'c1'));
    expect(find.text('Older post'), findsOneWidget);

    // The one-line prompt opens the New post sheet.
    await tester.tap(find.text('Share a memory or update'));
    await tester.pumpAndSettle();
    expect(find.text('New post'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '  Hello brats  ');
    await tester.pump();
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    expect(find.text('New post'), findsNothing);

    final bodies = tester
        .widgetList<Text>(find.textContaining(RegExp('Hello brats|Older post')))
        .map((t) => t.data)
        .toList();
    expect(bodies, ['Hello brats', 'Older post']);
  });

  testWidgets('the heart fills at once, then shows the server count', (
    tester,
  ) async {
    repo.feedPosts = [_post('p1', 'Like me', likes: 4)];
    await show(tester, const CommunityScreen(communityId: 'c1'));

    repo.likeReply = Completer();
    await tester.tap(hugeIcon(HugeIcons.strokeRoundedHeart));
    await tester.pump();
    expect(hugeIcon(HugeIcons.strokeRoundedHeart), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    repo.likeReply!.complete(_post('p1', 'Like me', likes: 7, liked: true));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('if liking fails, the heart goes back', (tester) async {
    repo.feedPosts = [_post('p1', 'Like me', likes: 4)];
    await show(tester, const CommunityScreen(communityId: 'c1'));

    repo.likeReply = Completer();
    await tester.tap(hugeIcon(HugeIcons.strokeRoundedHeart));
    await tester.pump();
    repo.likeReply!.completeError(
      DioException(requestOptions: RequestOptions()),
    );
    await tester.pumpAndSettle();
    expect(hugeIcon(HugeIcons.strokeRoundedHeart), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets("a private community's posts stay hidden until you're a member", (
    tester,
  ) async {
    repo.community = _community(visibility: 'PRIVATE', requested: true);
    repo.feedPosts = [_post('p1', 'Secret plans')];
    await show(tester, const CommunityScreen(communityId: 'c1'));

    expect(find.text('Members only'), findsOneWidget);
    expect(find.text('Secret plans'), findsNothing);
    expect(find.text('Requested · waiting for the owner'), findsOneWidget);
  });

  testWidgets('a post with photos shows the slider under its text', (
    tester,
  ) async {
    repo.feedPosts = [
      Post(
        id: 'p9',
        communityId: 'c1',
        communityName: 'Software Developers',
        author: _me,
        body: 'Hackathon day!',
        imageUrls: const ['/media/a.jpg', '/media/b.jpg'],
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        canDelete: false,
        createdAt: DateTime.now(),
      ),
    ];
    await show(tester, const CommunityScreen(communityId: 'c1'));
    expect(find.text('Hackathon day!'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets(
    'Popular reloads the feed sorted by the server; pinned posts are labelled',
    (tester) async {
      repo.feedPosts = [
        Post(
          id: 'p1',
          communityId: 'c1',
          communityName: 'Software Developers',
          author: _me,
          body: 'Reunion on 20 Dec',
          likeCount: 0,
          commentCount: 0,
          likedByMe: false,
          canDelete: false,
          pinned: true,
          createdAt: DateTime.now(),
        ),
      ];
      await show(tester, const CommunityScreen(communityId: 'c1'));
      expect(find.text('Pinned'), findsOneWidget);
      expect(repo.sorts, ['latest']);

      await tester.tap(find.text('Popular'));
      await tester.pumpAndSettle();
      expect(repo.sorts, ['latest', 'popular']);
      expect(find.text('Reunion on 20 Dec'), findsOneWidget);
    },
  );

  testWidgets('members see Chat with the unread count in the header', (
    tester,
  ) async {
    repo.summary = CommunityChatSummary(
      lastMessage: _message(
        'm1',
        _rahul,
        'Anyone planning a reunion this year?',
      ),
      unreadCount: 12,
      canModerate: false,
    );
    await show(tester, const CommunityScreen(communityId: 'c1'));
    expect(find.text('Chat · 12'), findsOneWidget);
    expect(find.text('Joined'), findsOneWidget);
    // A manually created community: Feed, Chat, Events, Members. No Memories.
    for (final tab in ['Feed', 'Chat', 'Events', 'Members']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(find.text('Memories'), findsNothing);
  });

  testWidgets('a school community keeps Feed, Events, Memories and Members', (
    tester,
  ) async {
    repo.community = _community(
      type: 'SCHOOL',
      name: 'APS Pune',
      myRole: 'MEMBER',
    );
    await show(tester, const CommunityScreen(communityId: 'c1'));
    for (final tab in ['Feed', 'Events', 'Memories', 'Members']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(find.text('Chat'), findsOneWidget); // the header button, not a tab
  });

  testWidgets('group chat names other senders, not me, and sends', (
    tester,
  ) async {
    repo.chat = [
      _message('m1', _rahul, 'Hi all'),
      _message('m2', _me, 'Hello Rahul'),
    ];
    await show(tester, const CommunityChatScreen(communityId: 'c1'));
    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('Arjun Singh'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Reunion in Pune?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Reunion in Pune?'), findsOneWidget);
  });

  testWidgets('the next event is highlighted at the top of the feed', (
    tester,
  ) async {
    repo.eventList = EventList(
      events: [
        CommunityEvent(
          id: 'e1',
          communityId: 'c1',
          communityName: 'Software Developers',
          title: 'Class of 2015 reunion',
          venue: 'APS Pune',
          startsAt: DateTime(2026, 12, 20, 18),
          goingCount: 12,
          myRsvp: 'GOING',
        ),
      ],
      canCreate: false,
    );
    await show(tester, const CommunityScreen(communityId: 'c1'));
    expect(find.text('Class of 2015 reunion'), findsOneWidget);
    expect(find.textContaining('12 going'), findsOneWidget);
    expect(find.text('Going'), findsOneWidget);

    // The Events tab: the soonest event big, and no Create button for a member.
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    expect(find.text('12 going · 0 interested'), findsOneWidget);
    expect(find.text('Create an event'), findsNothing);
  });

  testWidgets('an event: details, and tapping my RSVP again clears it', (
    tester,
  ) async {
    repo.theEvent = CommunityEvent(
      id: 'e1',
      communityId: 'c1',
      communityName: 'Software Developers',
      title: 'Class of 2015 reunion',
      venue: 'APS Pune',
      startsAt: DateTime(2026, 12, 20, 18),
      endsAt: DateTime(2026, 12, 20, 21),
      goingCount: 12,
      interestedCount: 3,
      myRsvp: 'GOING',
    );
    await show(tester, const EventScreen(eventId: 'e1'));
    expect(find.text('SUN, 20 DEC · 6:00 PM – 9:00 PM'), findsOneWidget);
    expect(find.text('12 going · 3 interested'), findsOneWidget);

    await tester.tap(find.text('Going'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interested'));
    await tester.pumpAndSettle();
    expect(repo.rsvps, [null, 'INTERESTED']);
  });

  testWidgets('memory posts carry a Throwback label', (tester) async {
    repo.feedPosts = [
      Post(
        id: 'p1',
        communityId: 'c1',
        communityName: 'APS Pune',
        author: _me,
        body: 'Our 2008 march past',
        imageUrls: const ['/media/a.jpg'],
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        canDelete: false,
        memoryYear: 2008,
        memoryCategory: 'SPORTS_DAY',
        createdAt: DateTime.now(),
      ),
    ];
    await show(tester, const CommunityScreen(communityId: 'c1'));
    expect(find.text('Throwback · Sports Day 2008'), findsOneWidget);
  });

  testWidgets('the Memories gallery filters by year and category', (
    tester,
  ) async {
    repo.community = _community(
      type: 'SCHOOL',
      name: 'APS Pune',
      myRole: 'MEMBER',
    );
    await show(tester, const CommunityScreen(communityId: 'c1', initialTab: 2));
    expect(find.text('No memories yet'), findsOneWidget);
    expect(find.text('2012'), findsOneWidget);

    await tester.tap(find.text('2008'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annual Day'));
    await tester.pumpAndSettle();
    expect(repo.memoryQueries.last, (
      communityId: 'c1',
      year: 2008,
      category: 'ANNUAL_DAY',
    ));
    expect(find.text('Nothing for this filter'), findsOneWidget);
  });

  testWidgets('Members tab: connect, message or requested on each row', (
    tester,
  ) async {
    Person member(String id, String name, String relation) => Person(
      id: id,
      username: id,
      initials: name.substring(0, 2).toUpperCase(),
      name: name,
      school: 'APS Pune',
      detail: '12A · Class 2015',
      city: null,
      job: null,
      currentStatus: 'ALUMNI',
      profilePicUrl: null,
      online: false,
      tags: const [],
      relation: relation,
    );
    repo.memberList = [
      member('a', 'Meera Iyer', 'NONE'),
      member('b', 'Divya Nair', 'CONNECTED'),
      member('c', 'Karan Rao', 'PENDING_OUT'),
    ];
    await show(tester, const CommunityScreen(communityId: 'c1', initialTab: 3));
    expect(find.text('Meera Iyer'), findsWidgets);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.byTooltip('Message Divya Nair'), findsOneWidget);
    expect(find.text('Requested'), findsOneWidget);
  });

  test('active labels', () {
    final now = DateTime(2026, 11, 9, 12);
    expect(activeLabel(null, now: now), isNull);
    expect(
      activeLabel(now.subtract(const Duration(minutes: 3)), now: now),
      'Active now',
    );
    expect(
      activeLabel(now.subtract(const Duration(minutes: 40)), now: now),
      'Active 40m ago',
    );
    expect(
      activeLabel(now.subtract(const Duration(hours: 5)), now: now),
      'Active 5h ago',
    );
    expect(
      activeLabel(now.subtract(const Duration(days: 3)), now: now),
      'Active 3d ago',
    );
    expect(
      activeLabel(now.subtract(const Duration(days: 9)), now: now),
      isNull,
    );
  });

  test('time labels', () {
    final now = DateTime(2026, 10, 4, 12);
    expect(
      shortTimeAgo(now.subtract(const Duration(seconds: 20)), now: now),
      'now',
    );
    expect(
      shortTimeAgo(now.subtract(const Duration(minutes: 5)), now: now),
      '5m',
    );
    expect(
      shortTimeAgo(now.subtract(const Duration(hours: 3)), now: now),
      '3h',
    );
    expect(shortTimeAgo(now.subtract(const Duration(days: 2)), now: now), '2d');
    expect(shortTimeAgo(DateTime(2026, 3, 12), now: now), '12 Mar');
  });
}
