class ApiEndpoints {
  const ApiEndpoints._();

  // Existing
  static const schools = '/schools';
  static const users = '/users';
  static const usersUsernameAvailable = '/users/username-available';
  static const usersPhoneAvailable = '/users/phone-available';

  // Auth
  static const authRequestOtp = '/auth/request-otp';
  static const authVerifyOtp = '/auth/verify-otp';
  static const authRefresh = '/auth/refresh';
  static const authLogout = '/auth/logout';

  // Account (DPDP) + media
  static const usersMeAvatar = '/users/me/avatar';
  static const usersMeExport = '/users/me/export';
  static const usersMe = '/users/me';

  // Server-driven client config (force-update / maintenance)
  static const appConfig = '/app/config';

  // Feed
  static const feedActivity = '/feed/activity';
  static const feedRecentJoins = '/feed/recent-joins';
  static const feedBanner = '/feed/banner';

  // Connections
  static const connections = '/connections';
  static const connectionsPending = '/connections/pending';
  static String connectionStatus(String userId) =>
      '/connections/$userId/status';
  static String connectionRequest(String userId) => '/connections/$userId';
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

  // Profiles
  static String profile(String username) => '/profiles/$username';
  static String userSocialLinks(String userId) => '/users/$userId/social-links';
  static String userSocialLink(String userId, String platform) =>
      '/users/$userId/social-links/$platform';
}
