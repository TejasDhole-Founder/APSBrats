class ApiEndpoints {
  const ApiEndpoints._();

  // Existing
  static const schools = '/schools';
  static const users = '/users';
  static const usersUsernameAvailable = '/users/username-available';

  // Auth
  static const authRequestOtp = '/auth/request-otp';
  static const authVerifyOtp = '/auth/verify-otp';
  static const authGoogle = '/auth/google';
  static const authRefresh = '/auth/refresh';
  static const authLogout = '/auth/logout';
  static const authLogoutAll = '/auth/logout-all';

  // Account (DPDP) + media
  static const usersMeAvatar = '/users/me/avatar';
  static const usersMeExport = '/users/me/export';
  static const usersMeBlocks = '/users/me/blocks';
  static String userBlock(String userId) => '/users/$userId/block';
  static const usersMe = '/users/me';
  static const usersMeSettings = '/users/me/settings';

  // Server-driven client config (force-update / maintenance)
  static const appConfig = '/app/config';

  // Feed
  static const feedActivity = '/feed/activity';
  static const feedRecentJoins = '/feed/recent-joins';
  static const feedBanner = '/feed/banner';

  // Connections
  static const connections = '/connections';
  static const connectionsPending = '/connections/pending';
  static const connectionsSent = '/connections/sent';

  // Circle (my people)
  static const circleSummary = '/users/me/circle/summary';
  static const circleClassmates = '/users/me/circle/classmates';
  static const circleSchoolmates = '/users/me/circle/schoolmates';
  static String connectionStatus(String userId) =>
      '/connections/$userId/status';
  static String connectionRequest(String userId) => '/connections/$userId';
  static String connectionMutual(String userId) =>
      '/connections/$userId/mutual';
  static String connectionAccept(String userId) =>
      '/connections/$userId/accept';

  // Career (jobs + college) — one timeline per person
  static const organizationsSearch = '/organizations/search';
  static const career = '/career';
  static String careerEntry(String id) => '/career/$id';
  static String userCareer(String userId) => '/users/$userId/career';

  // Communities (school + interest), posts, likes, comments
  static const communitiesMine = '/communities/mine';
  static const communitiesDiscover = '/communities/discover';
  static const communities = '/communities';
  static String community(String id) => '/communities/$id';
  static String communityJoin(String id) => '/communities/$id/join';
  static String communityLeave(String id) => '/communities/$id/members/me';
  static String communityMember(String id, String userId) =>
      '/communities/$id/members/$userId';
  static String communityRequests(String id) => '/communities/$id/requests';
  static String communityRequestDecision(
    String id,
    String userId,
    String decision,
  ) => '/communities/$id/requests/$userId/$decision';
  static String communityPosts(String id) => '/communities/$id/posts';
  static String communityMembers(String id) => '/communities/$id/members';
  static String communityChat(String id) => '/communities/$id/chat';
  static String communityChatMessages(String id) =>
      '/communities/$id/chat/messages';
  static String communityChatRead(String id) => '/communities/$id/chat/read';
  static String communityMessage(String id) => '/community-messages/$id';
  static String communityEvents(String id) => '/communities/$id/events';
  static String event(String id) => '/events/$id';
  static String eventCancel(String id) => '/events/$id/cancel';
  static String eventRsvp(String id) => '/events/$id/rsvp';
  static String eventAttendees(String id) => '/events/$id/attendees';
  static String eventPosts(String id) => '/events/$id/posts';
  static String communityMemories(String id) => '/communities/$id/memories';
  static String communityMemoryYears(String id) =>
      '/communities/$id/memories/years';
  static const feedHome = '/feed/home';
  static String post(String id) => '/posts/$id';
  static String postLike(String id) => '/posts/$id/like';
  static String postPin(String id) => '/posts/$id/pin';
  static String postComments(String id) => '/posts/$id/comments';
  static String comment(String id) => '/comments/$id';
  static const reports = '/reports';

  // Photos for posts and chat: upload first, then attach the returned address.
  static const mediaImages = '/media/images';

  // Conversations (DMs)
  static const conversations = '/conversations';
  static String conversationWith(String userId) =>
      '/conversations/with/$userId';
  static String conversationMessages(String id) =>
      '/conversations/$id/messages';
  static String conversationRead(String id) => '/conversations/$id/read';

  // Notifications
  static const notifications = '/notifications';
  static const notificationsUnreadCount = '/notifications/unread-count';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const notificationsReadAll = '/notifications/read-all';

  // Search
  static const search = '/search';
  static const peopleSearch = '/people/search';

  // Profiles
  static String profile(String userId) => '/profiles/$userId';
  static String userSchoolHistory(String userId) =>
      '/users/$userId/school-history';
  static String userSchoolHistoryBulk(String userId) =>
      '/users/$userId/school-history/bulk';
  static String userSocialLinks(String userId) => '/users/$userId/social-links';
  static String userSocialLink(String userId, String platform) =>
      '/users/$userId/social-links/$platform';
}
