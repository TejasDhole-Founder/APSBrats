import 'package:apsbrat_frontend/core/models/person.dart';

/// Mirrors the backend CommunityDto.
class Community {
  const Community({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    required this.visibility,
    required this.memberCount,
    this.myRole,
    this.requested = false,
  });

  final String id;

  /// 'SCHOOL' or 'INTEREST'.
  final String type;
  final String name;
  final String? description;

  /// 'OPEN' or 'PRIVATE'. Always shown as "Public" / "Private" (decision D12).
  final String visibility;
  final int memberCount;

  /// null (not a member), 'MEMBER' or 'OWNER'.
  final String? myRole;

  /// Asked to join a private community; waiting for the owner.
  final bool requested;

  bool get isSchool => type == 'SCHOOL';
  bool get isPrivate => visibility == 'PRIVATE';
  bool get isMember => myRole != null;
  bool get isOwner => myRole == 'OWNER';

  /// "School", "Public" or "Private".
  String get kindLabel =>
      isSchool ? 'School' : (isPrivate ? 'Private' : 'Public');

  String get membersLabel =>
      memberCount == 1 ? '1 member' : '$memberCount members';

  factory Community.fromJson(Map<String, dynamic> json) => Community(
    id: json['id'] as String,
    type: json['type'] as String? ?? 'INTEREST',
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    visibility: json['visibility'] as String? ?? 'OPEN',
    memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
    myRole: json['myRole'] as String?,
    requested: json['requested'] as bool? ?? false,
  );
}

class MyCommunities {
  const MyCommunities({required this.joined, required this.suggested});

  final List<Community> joined;

  /// My schools' communities I haven't joined yet.
  final List<Community> suggested;

  factory MyCommunities.fromJson(Map<String, dynamic> json) => MyCommunities(
    joined: _list(json['joined'], Community.fromJson),
    suggested: _list(json['suggested'], Community.fromJson),
  );
}

/// Mirrors the backend PostDto.
class Post {
  const Post({
    required this.id,
    required this.communityId,
    required this.communityName,
    required this.author,
    required this.body,
    this.imageUrls = const [],
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.canDelete,
    this.pinned = false,
    this.canPin = false,
    this.eventId,
    this.eventTitle,
    this.memoryYear,
    this.memoryCategory,
    required this.createdAt,
  });

  final String id;
  final String communityId;
  final String communityName;
  final Person author;

  /// Can be empty when the post is just a photo.
  final String body;

  /// 0 to 10 photos, in slider order ("/media/…").
  final List<String> imageUrls;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final bool canDelete;

  /// Shown at the top of its community's feed.
  final bool pinned;

  /// I own the community, or I'm staff.
  final bool canPin;

  /// Shared from this event (its photos), or null.
  final String? eventId;
  final String? eventTitle;

  /// A school memory: the year it's from and a kMemoryCategories code.
  final int? memoryYear;
  final String? memoryCategory;
  final DateTime createdAt;

  /// The heart, flipped locally before the server answers.
  Post toggledLike() => copyWith(
    likedByMe: !likedByMe,
    likeCount: likeCount + (likedByMe ? -1 : 1),
  );

  Post copyWith({bool? likedByMe, int? likeCount, int? commentCount}) => Post(
    id: id,
    communityId: communityId,
    communityName: communityName,
    author: author,
    body: body,
    imageUrls: imageUrls,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    likedByMe: likedByMe ?? this.likedByMe,
    canDelete: canDelete,
    pinned: pinned,
    canPin: canPin,
    eventId: eventId,
    eventTitle: eventTitle,
    memoryYear: memoryYear,
    memoryCategory: memoryCategory,
    createdAt: createdAt,
  );

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    communityId: json['communityId'] as String? ?? '',
    communityName: json['communityName'] as String? ?? '',
    author: Person.fromJson(json['author'] as Map<String, dynamic>),
    body: json['body'] as String? ?? '',
    imageUrls: [
      for (final u in (json['imageUrls'] as List?) ?? const []) u.toString(),
    ],
    likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
    likedByMe: json['likedByMe'] as bool? ?? false,
    canDelete: json['canDelete'] as bool? ?? false,
    pinned: json['pinned'] as bool? ?? false,
    canPin: json['canPin'] as bool? ?? false,
    eventId: json['eventId'] as String?,
    eventTitle: json['eventTitle'] as String?,
    memoryYear: (json['memoryYear'] as num?)?.toInt(),
    memoryCategory: json['memoryCategory'] as String?,
    createdAt: _date(json['createdAt']),
  );
}

/// School memory categories (backend MemoryCategory), with labels.
const kMemoryCategories = [
  ('ANNUAL_DAY', 'Annual Day'),
  ('SPORTS_DAY', 'Sports Day'),
  ('CLASSROOM', 'Classroom'),
  ('TRIPS', 'Trips & Excursions'),
  ('FAREWELL', 'Farewell'),
  ('CAMPUS', 'Campus'),
  ('OTHER', 'Other'),
];

/// Earliest year a memory can be from (matches the backend).
const kFirstMemoryYear = 1950;

String memoryCategoryLabel(String? code) =>
    kMemoryCategories.where((c) => c.$1 == code).firstOrNull?.$2 ?? '';

/// Mirrors the backend EventDto: a reunion or meetup in a community.
class CommunityEvent {
  const CommunityEvent({
    required this.id,
    required this.communityId,
    required this.communityName,
    required this.title,
    this.description,
    required this.venue,
    required this.startsAt,
    this.endsAt,
    this.coverUrl,
    this.cancelled = false,
    this.organizer,
    this.goingCount = 0,
    this.interestedCount = 0,
    this.photoCount = 0,
    this.myRsvp,
    this.canManage = false,
  });

  final String id;
  final String communityId;
  final String communityName;
  final String title;
  final String? description;

  /// An address, or "Online".
  final String venue;

  /// Local wall-clock time.
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? coverUrl;
  final bool cancelled;
  final Person? organizer;
  final int goingCount;
  final int interestedCount;

  /// Posts (photos) shared from it.
  final int photoCount;

  /// 'GOING', 'INTERESTED' or null.
  final String? myRsvp;

  /// Community owner or staff: may edit or cancel.
  final bool canManage;

  /// Photos can be shared once it has started.
  bool get started => !startsAt.isAfter(DateTime.now());

  factory CommunityEvent.fromJson(Map<String, dynamic> json) => CommunityEvent(
    id: json['id'] as String,
    communityId: json['communityId'] as String? ?? '',
    communityName: json['communityName'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    venue: json['venue'] as String? ?? '',
    startsAt: _date(json['startsAt']),
    endsAt: json['endsAt'] == null ? null : _date(json['endsAt']),
    coverUrl: json['coverUrl'] as String?,
    cancelled: json['cancelled'] as bool? ?? false,
    organizer: json['organizer'] == null
        ? null
        : Person.fromJson(json['organizer'] as Map<String, dynamic>),
    goingCount: (json['goingCount'] as num?)?.toInt() ?? 0,
    interestedCount: (json['interestedCount'] as num?)?.toInt() ?? 0,
    photoCount: (json['photoCount'] as num?)?.toInt() ?? 0,
    myRsvp: json['myRsvp'] as String?,
    canManage: json['canManage'] as bool? ?? false,
  );
}

class EventList {
  const EventList({required this.events, required this.canCreate});

  final List<CommunityEvent> events;

  /// I own the community or I'm staff.
  final bool canCreate;

  factory EventList.fromJson(Map<String, dynamic> json) => EventList(
    events: _list(json['events'], CommunityEvent.fromJson),
    canCreate: json['canCreate'] as bool? ?? false,
  );
}

/// Mirrors the backend CommentDto.
class PostComment {
  const PostComment({
    required this.id,
    required this.author,
    required this.body,
    required this.canDelete,
    required this.createdAt,
  });

  final String id;
  final Person author;
  final String body;
  final bool canDelete;
  final DateTime createdAt;

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
    id: json['id'] as String,
    author: Person.fromJson(json['author'] as Map<String, dynamic>),
    body: json['body'] as String? ?? '',
    canDelete: json['canDelete'] as bool? ?? false,
    createdAt: _date(json['createdAt']),
  );
}

/// Mirrors the backend CommunityMessageDto (one group-chat message).
class CommunityMessage {
  const CommunityMessage({
    required this.id,
    required this.communityId,
    required this.sender,
    required this.body,
    this.imageUrl,
    this.removed = false,
    required this.createdAt,
  });

  final String id;
  final String communityId;
  final Person sender;
  final String body;
  final String? imageUrl;

  /// A live notice that this message was deleted or hidden.
  final bool removed;
  final DateTime createdAt;

  /// "Rahul: Anyone planning a reunion?" for the chat card.
  String get preview =>
      '${sender.name.split(' ').first}: ${body.isNotEmpty ? body : 'Photo'}';

  factory CommunityMessage.fromJson(Map<String, dynamic> json) =>
      CommunityMessage(
        id: json['id'] as String,
        communityId: json['communityId'] as String? ?? '',
        sender: Person.fromJson(json['sender'] as Map<String, dynamic>),
        body: json['body'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        removed: json['removed'] as bool? ?? false,
        createdAt: _date(json['createdAt']),
      );
}

/// The chat card on a community page.
class CommunityChatSummary {
  const CommunityChatSummary({
    this.lastMessage,
    required this.unreadCount,
    required this.canModerate,
    this.onlineCount,
  });

  final CommunityMessage? lastMessage;
  final int unreadCount;

  /// I own the community or I'm staff: I may delete anyone's message.
  final bool canModerate;

  /// Members active in the last few minutes; null when I hide my activity.
  final int? onlineCount;

  factory CommunityChatSummary.fromJson(Map<String, dynamic> json) =>
      CommunityChatSummary(
        lastMessage: json['lastMessage'] == null
            ? null
            : CommunityMessage.fromJson(
                json['lastMessage'] as Map<String, dynamic>,
              ),
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
        canModerate: json['canModerate'] as bool? ?? false,
        onlineCount: (json['onlineCount'] as num?)?.toInt(),
      );
}

/// Someone waiting to join a private community I own.
class JoinRequestItem {
  const JoinRequestItem({required this.person, required this.requestedAt});

  final Person person;
  final DateTime requestedAt;

  factory JoinRequestItem.fromJson(Map<String, dynamic> json) =>
      JoinRequestItem(
        person: Person.fromJson(json['person'] as Map<String, dynamic>),
        requestedAt: _date(json['requestedAt']),
      );
}

/// One page of a cursor-paged list (the backend's CursorPage).
class PageOf<T> {
  const PageOf({required this.items, this.nextCursor, required this.hasMore});

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  factory PageOf.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) => PageOf(
    items: _list(json['items'], fromJson),
    nextCursor: json['nextCursor'] as String?,
    hasMore: json['hasMore'] as bool? ?? false,
  );
}

/// Report reasons (backend decision D9), with friendly labels.
const kReportReasons = [
  ('SPAM', 'Spam'),
  ('INAPPROPRIATE', 'Inappropriate'),
  ('NOT_RELEVANT', 'Not relevant to this community'),
  ('HARASSMENT', 'Harassment or bullying'),
  ('PRIVACY', 'Shares private information'),
  ('OTHER', 'Something else'),
];

/// "now", "5m", "3h", "2d", then "12 Mar".
String shortTimeAgo(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${time.day} ${months[time.month - 1]}';
}

List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) => [
  for (final e in (raw as List?) ?? const [])
    fromJson(e as Map<String, dynamic>),
];

/// The backend sends local date-times without a zone ("2026-10-04T15:30:43").
DateTime _date(dynamic raw) =>
    raw is String ? (DateTime.tryParse(raw) ?? DateTime.now()) : DateTime.now();
