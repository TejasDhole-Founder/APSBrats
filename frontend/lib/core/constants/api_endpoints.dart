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

  // Account (DPDP) + media
  static const usersMeAvatar = '/users/me/avatar';
  static const usersMeExport = '/users/me/export';
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

  // Communities
  static const communities = '/communities';
  static const communitiesDiscover = '/communities/discover';
  static String community(String id) => '/communities/$id';
  static String communityMessages(String id) => '/communities/$id/messages';
  static String communityJoin(String id) => '/communities/$id/join';
  static String communityRead(String id) => '/communities/$id/read';

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
