//endpint.dart
class Endpoints {
static const String baseUrl = 'http://10.0.2.2:3000';
  // Auth
  static const String authSignin = '/api/auth/signin';
  static const String authSignupRequestOtp = '/api/auth/signup/request-otp';
  static const String authSignupVerifyOtp = '/api/auth/signup/verify-otp';
  static const String authPasswordRequestOtp = '/api/auth/password/request-otp';
  static const String authPasswordConfirm = '/api/auth/password/confirm';
  static const String authPasswordReset = '/api/auth/password/reset';
  static const String authPhoneChangeRequestOtp =
      '/api/auth/phone-change/request-otp';
  static const String authPhoneChangeVerifyOtp =
      '/api/auth/phone-change/verify-otp';

  // Users/Profile (Nest: @Controller('users'))
  static const String usersProfile = '/api/users/profile';
  static const String usersInterest = '/api/users/interest';
  static const String usersInterestRemove = '/api/users/interest';

  // Shared Collections (Nest: @Controller('shared-collections'))
  static const String createCollection =
      '/api/shared-collections/createCollection';
  static const String getOwnedCollections =
      '/api/shared-collections/getOwnedCollections';
  static const String getJoinedCollections =
      '/api/shared-collections/getJoinedCollections';
  static const String getCollectionDetails =
      '/api/shared-collections/getcollectionDetails';
  static const String getOthersCollections =
      '/api/shared-collections/getOthersCollections';
  static String incrementCollectionView(String id) =>
      '/api/shared-collections/$id/incrementView';
  static String updateCollection(String id) =>
      '/api/shared-collections/$id/updateCollection';
  static String deleteCollection(String id) =>
      '/api/shared-collections/$id/deleteCollection';
  static String deleteMember(String collectionId, String memberId) =>
    '/api/shared-collections/$collectionId/members/$memberId';
  static String getShareLink(String id) =>
    '/api/shared-collections/$id/share-link';
  // Shared Collections Added News (Nest: @Controller('shared-collections'))
  static String addArticleToCollection(String collectionId) =>
      '/api/shared-collections/$collectionId/addArticle';
  static String archiveAddedNews(String collectionId, String addedNewsId) =>
      '/api/shared-collections/$collectionId/addedNews/$addedNewsId/archive';
  static String restoreAddedNews(String collectionId, String addedNewsId) =>
      '/api/shared-collections/$collectionId/addedNews/$addedNewsId/restore';
  static String getArchivedNews(String collectionId) =>
      '/api/shared-collections/$collectionId/archivedNews';
  static String getAddedNewsSummary(String collectionId, String addedNewsId) =>
      '/api/shared-collections/$collectionId/addedNews/$addedNewsId/summary';
  static String getAddedNewsAudio(String collectionId,String addedNewsId,String mode,) =>
   '/api/shared-collections/$collectionId/addedNews/$addedNewsId/audio?mode=$mode';
  static String deleteAddedNews(String collectionId, String addedNewsId) =>
    '/api/shared-collections/$collectionId/addedNews/$addedNewsId';
   // Shared Collections Members (Nest: @Controller('shared-collections'))
static String leaveCollection(String collectionId) =>
    '/api/shared-collections/$collectionId/members/leave';
  //Shared Collections Join Request  (Nest: @Controller('shared-collections'))
  static String createJoinRequest(String collectionId) =>
      '/api/shared-collections/$collectionId/joinRequests/create';
  static String getJoinRequests(String collectionId) =>
      '/api/shared-collections/$collectionId/joinRequests';
  static String decideJoinRequest(String collectionId, String requestId) =>
      '/api/shared-collections/$collectionId/joinRequests/$requestId/decide';
  //Shared Collections Report AddedNews (Nest: @Controller('shared-collections'))
  static String createReport(String collectionId, String addedNewsId) =>
      '/api/shared-collections/$collectionId/addedNews/$addedNewsId/report';
  static String getReports(String collectionId) =>
      '/api/shared-collections/$collectionId/reports';

  // News (Nest: @Controller('news'))
  static const String getNewsFeed = '/api/news'; // GET news feed
  static String getNewsById(String id) => '/api/news/$id'; // GET news details
  static String reportNews(String id) => '/api/news/$id/report'; // PATCH
  static const String newsIngest = '/api/news/ingest';
  static String getNewsSummary(String id) => '/api/news/$id/summary';
static String getNewsAudio(String id, String mode) => '/api/news/$id/audio?mode=$mode';
  // Notifications
  static const String getNotifications = '/api/notifications/getAll';
  static const String getUnreadCount = '/api/notifications/unreadCount';
  static const String markAllRead = '/api/notifications/markAllRead';
  static String getNotificationDetails(String id) =>
      '/api/notifications/$id/getDetails';
  // Semantic Notifications
  static const String getSemanticNotifications =
      '/api/semantic-notifications/getAll';
  static const String createSemanticNotification =
      '/api/semantic-notifications/create';
  static const String deleteSemanticNotification =
      '/api/semantic-notifications/delete';

  static const String authSaveFcmToken = '/api/users/fcm-token';
}
