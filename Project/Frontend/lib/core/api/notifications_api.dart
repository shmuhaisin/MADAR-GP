import 'api_client.dart';
import 'endpoints.dart';

class NotificationsApi {
  final ApiClient _api;
  NotificationsApi(this._api);

  // =========================================================
  // GET ALL NOTIFICATIONS
  // GET /api/notifications/getAll?type=&interest=&keyword=
  // =========================================================
  Future<Map<String, dynamic>> getNotifications({
    String? type,
    String? interest,
    String? keyword,
    bool auth = true,
  }) async {
    final params = <String, String>{};
    if (type != null && type != 'all') params['type'] = type;
    if (interest != null) params['interest'] = interest;
    if (keyword != null) params['keyword'] = keyword;

    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final url = query.isEmpty
        ? Endpoints.getNotifications
        : '${Endpoints.getNotifications}?$query';

    return _api.getMap(url, auth: auth);
  }

  // =========================================================
  // GET UNREAD COUNT
  // GET /api/notifications/unreadCount
  // =========================================================
  Future<Map<String, dynamic>> getUnreadCount({bool auth = true}) async {
    return _api.getMap(Endpoints.getUnreadCount, auth: auth);
  }

  // =========================================================
  // GET NOTIFICATION DETAILS
  // GET /api/notifications/:id/getDetails
  // =========================================================
  Future<Map<String, dynamic>> getNotificationDetails(
    String id, {
    bool auth = true,
  }) async {
    return _api.getMap(Endpoints.getNotificationDetails(id), auth: auth);
  }

  // =========================================================
  // MARK ALL AS READ
  // PATCH /api/notifications/markAllRead
  // =========================================================
  Future<Map<String, dynamic>> markAllAsRead({bool auth = true}) async {
    return _api.patch(Endpoints.markAllRead, auth: auth);
  }

  // =========================================================
  // GET SEMANTIC NOTIFICATIONS
  // GET /api/semantic-notifications/getAll
  // =========================================================
  Future<Map<String, dynamic>> getSemanticNotifications({bool auth = true}) async {
    return _api.getMap(Endpoints.getSemanticNotifications, auth: auth);
  }

  // =========================================================
  // CREATE SEMANTIC NOTIFICATION
  // POST /api/semantic-notifications/create
  // =========================================================
  Future<Map<String, dynamic>> createSemanticNotification({
    required String interest,
    required String keyword,
    bool auth = true,
  }) async {
    return _api.post(
      Endpoints.createSemanticNotification,
      auth: auth,
      data: {'interest': interest, 'keyword': keyword},
    );
  }

  // =========================================================
  // DELETE SEMANTIC NOTIFICATION
  // DELETE /api/semantic-notifications/delete
  // =========================================================
Future<Map<String, dynamic>> deleteSemanticNotification({
  required String interest,
  required String keyword,
  bool auth = true,
}) async {
  return _api.delete(
    '${Endpoints.deleteSemanticNotification}?interest=$interest&keyword=${Uri.encodeComponent(keyword)}',
    auth: auth,
  );
}
}