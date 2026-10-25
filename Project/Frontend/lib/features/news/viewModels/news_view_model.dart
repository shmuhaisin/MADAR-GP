import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/news_api.dart';
import '../../../core/storage/token_storage.dart';
import '../../profile/model/profile_model.dart';
import '../models/article_model.dart';

class NewsViewModel extends ChangeNotifier {
  final ApiClient _client;
  late final NewsApi _api;
  final TokenStorage _tokenStorage = TokenStorage();

  NewsViewModel({ApiClient? api}) : _client = api ?? ApiClient() {
    _api = NewsApi(_client);
  }

  bool loading = false;
  bool loadingMore = false;
  bool isOffline = false;
  String? error;

  int selectedCategoryIndex = 0;

  int page = 1;
  final int limit = 10;
  bool hasMore = true;

  int total = 0;

  int get totalPages => total == 0 ? 0 : (total / limit).ceil();

  int get currentPage => page;

  final List<ArticleModel> _articles = [];

  List<ArticleModel> get articles => List.unmodifiable(_articles);

  String _currentUserKey = 'guest';

  void setCurrentUserKey(String value) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      _currentUserKey = 'guest';
    } else {
      _currentUserKey = cleaned;
    }
  }

  final List<Map<String, String?>> _categories = [
    {'label': 'الكل', 'value': null},
  ];

  List<Map<String, String?>> get categories => List.unmodifiable(_categories);

  String? get selectedCategoryValue {
    if (_categories.isEmpty) return null;

    if (selectedCategoryIndex < 0 ||
        selectedCategoryIndex >= _categories.length) {
      return null;
    }

    return _categories[selectedCategoryIndex]['value'];
  }

  bool _interestsInitialized = false;

  bool get interestsInitialized => _interestsInitialized;

  static const Map<String, String> _interestLabelAr = {
    'Health': 'الصحة',
    'Politics': 'السياسة',
    'Entertainment': 'الترفيه',
    'Technology': 'التقنية',
    'Sports': 'الرياضة',
    'Economy': 'الاقتصاد',
  };

  void setUserInterests(List<Interest> interests) {
    _categories.clear();

    final values = interests
        .map((i) => i.key)
        .where((v) => v.trim().isNotEmpty)
        .toSet()
        .toList();

    if (values.length >= 2) {
      _categories.add({'label': 'الكل', 'value': null});
    }

    for (final v in values) {
      _categories.add({
        'label': _interestLabelAr[v] ?? v,
        'value': v,
      });
    }

    if (_categories.isEmpty) {
      _categories.add({'label': 'الكل', 'value': null});
    }

    selectedCategoryIndex = 0;
    _interestsInitialized = true;

    notifyListeners();
  }

  void clearError() {
    if (error == null) return;

    error = null;
    notifyListeners();
  }

  void setCategory(int index) {
    if (index < 0 || index >= categories.length) return;
    if (selectedCategoryIndex == index) return;

    selectedCategoryIndex = index;
    refresh();
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));

      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _cacheKey() {
    final category = selectedCategoryValue ?? 'all';

   
    return 'articles_${_currentUserKey}_$category';
  }

  void _saveToCache(List<ArticleModel> articles) {
    final box = Hive.box('news_cache');
    final key = _cacheKey();

    final encoded = articles.map((a) => a.toJson()).toList();

    box.put(key, encoded);
    box.put('cache_time_$_currentUserKey', DateTime.now().toIso8601String());
  }

  List<ArticleModel> _loadFromCache() {
    final box = Hive.box('news_cache');
    final key = _cacheKey();

    final raw = box.get(key);

    if (raw == null) return [];

    return (raw as List)
        .map((e) => ArticleModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> refresh() async {
    await fetchPage(1);
  }

  Future<void> fetchPage(int pageNumber) async {
    loading = true;
    error = null;
    notifyListeners();

    final online = await _hasInternet();

    if (!online) {
      final cached = _loadFromCache();

      if (cached.isNotEmpty) {
        _articles
          ..clear()
          ..addAll(cached);

        isOffline = true;
      } else {
        _articles.clear();
        error = 'لا يوجد اتصال بالإنترنت ولا توجد أخبار محفوظة';
      }

      loading = false;
      notifyListeners();
      return;
    }

    try {
      final res = await _api.getFeed(
        page: pageNumber,
        limit: limit,
        category: selectedCategoryValue,
      );

      final items = (res['items'] as List?) ?? const [];

      total = (res['total'] as num?)?.toInt() ?? 0;
      page = (res['page'] as num?)?.toInt() ?? pageNumber;

      _articles
        ..clear()
        ..addAll(
          items
              .whereType<Map>()
              .map((e) => ArticleModel.fromJson(Map<String, dynamic>.from(e))),
        );

      hasMore = page < totalPages;
      isOffline = false;

      _saveToCache(_articles);
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        error = 'غير مصرح. سجّل دخولك من جديد.';
      } else {
        error = 'حدث خطأ أثناء تحميل الأخبار. حاول مرة أخرى.';
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;

    loadingMore = true;
    error = null;
    notifyListeners();

    try {
      final nextPage = page + 1;

      final res = await _api.getFeed(
        page: nextPage,
        limit: limit,
        category: selectedCategoryValue,
      );

      final items = (res['items'] as List?) ?? const [];

      total = (res['total'] as num?)?.toInt() ?? total;

      final newOnes = items
          .whereType<Map>()
          .map((e) => ArticleModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      _articles.addAll(newOnes);

      page = (res['page'] as num?)?.toInt() ?? nextPage;
      hasMore = page < totalPages;

      _saveToCache(_articles);
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        error = 'غير مصرح. سجّل دخولك من جديد.';
      } else {
        error = 'تعذر تحميل المزيد من الأخبار. حاول مرة أخرى.';
      }
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }
}