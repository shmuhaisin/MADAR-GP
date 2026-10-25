//news_api
import 'api_client.dart';
import 'endpoints.dart';
import '../storage/token_storage.dart';
import 'package:dio/dio.dart';

class NewsApi {
  final ApiClient _api;
  NewsApi(this._api);

  // =========================================================
  // GET NEWS FEED
  // GET /api/news?page=&limit=&category=
  // =========================================================
  Future<Map<String, dynamic>> getFeed({
    int page = 1,
    int limit = 10,
    String? category,
    bool auth = true,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (category != null && category.isNotEmpty) 'category': category,
    };

    return _api.getMap(
      '${Endpoints.getNewsFeed}?${_toQueryString(query)}',
      auth: auth,
    );
  }



  // =========================================================
  // GET NEWS BY ID
  // GET /api/news/:id
  // =========================================================
  Future<Map<String, dynamic>> getById(String id, {bool auth = true}) async {
    return _api.getMap(Endpoints.getNewsById(id), auth: auth);
  }


  // =========================================================
  // GET AI SUMMARY
  // GET /api/news/:id/summary
  // =========================================================
  Future<Map<String, dynamic>> getSummary(String id, {bool auth = true}) async {
    return _api.getMap(Endpoints.getNewsSummary(id), auth: auth);
  }

  // =========================================================
  // REPORT NEWS
  // PATCH /api/news/:id/report
  // =========================================================
  Future<Map<String, dynamic>> report(String id, {bool auth = true}) async {
    return _api.patch(
      Endpoints.reportNews(id),
      auth: auth,
      data: {}, // your backend doesn’t need a body
    );
  }

   Future<Map<String, dynamic>> getAudioRequestData({
  required String id,
  required String mode,
  bool auth = true,
}) async {
  final headers = <String, dynamic>{};

  if (auth) {
    final token = await TokenStorage().readToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
  }

  final res = await _api.dio.get(
    Endpoints.getNewsAudio(id, mode),
    options: Options(
      headers: headers,
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 15),
    ),
  );

  return Map<String, dynamic>.from(res.data as Map);
}


  // helper to build
  String _toQueryString(Map<String, dynamic> map) {
    return map.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent('${e.value}')}')
        .join('&');
  }
}