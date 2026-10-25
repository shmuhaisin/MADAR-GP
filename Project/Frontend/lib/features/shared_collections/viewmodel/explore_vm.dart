import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/shared_collection_api.dart';
import '../../../core/storage/token_storage.dart';
import '../model/collections_models.dart';
import '../model/added_news_model.dart';

class ExploreViewModel extends ChangeNotifier {
  final ApiClient _client;
  late final SharedCollectionApi _api;
  final TokenStorage _tokenStorage = TokenStorage();

  ExploreViewModel({ApiClient? api}) : _client = api ?? ApiClient() {
    _api = SharedCollectionApi(_client);
  }

  bool loading = false;
  bool hasLoadedOnce = false;

  String? error;
  String? apiError;

  final List<ExploreCollectionUiModel> _collections = [];
  List<ExploreCollectionUiModel> get collections =>
      List.unmodifiable(_collections);

  final Set<String> _incrementInFlight = {};
  final Set<String> _detailsPrefetchInFlight = {};

  // ─── Cache helpers ───────────────────────────────────────────────────────────

  Future<void> _saveToCache(dynamic data) async {
    if (!Hive.isBoxOpen('collections_cache')) return;

    final box = Hive.box('collections_cache');
    await box.put('explore_collections', data);
    await box.put(
      'explore_collections_cached_at',
      DateTime.now().toIso8601String(),
    );
  }

  dynamic _loadFromCache() {
    if (!Hive.isBoxOpen('collections_cache')) return null;
    return Hive.box('collections_cache').get('explore_collections');
  }

  Future<void> _saveDetailsToCache(
    String collectionId,
    Map<String, dynamic> data,
  ) async {
    if (!Hive.isBoxOpen('collections_cache')) return;

    final box = Hive.box('collections_cache');
    await box.put('explore_details_$collectionId', data);
    await box.put(
      'explore_details_${collectionId}_cached_at',
      DateTime.now().toIso8601String(),
    );
  }

  String _idFromRawCollection(dynamic item) {
    if (item is! Map) return '';

    final map = Map<String, dynamic>.from(item);
    return (map['id'] ?? map['_id'] ?? '').toString().trim();
  }


  Future<void> _prefetchDetailsForRawCollections(dynamic rawCollections) async {
    if (rawCollections is! List) return;

    for (final item in rawCollections) {
      final id = _idFromRawCollection(item);
      if (id.isEmpty) continue;
      if (_detailsPrefetchInFlight.contains(id)) continue;

      _detailsPrefetchInFlight.add(id);

      try {
        final res = await _api.getCollectionDetails(id);

        if (res is Map) {
          await _saveDetailsToCache(id, Map<String, dynamic>.from(res));
        }
      } catch (e) {
        debugPrint(
          '[Explore] prefetch details failed for $id: '
          '${ApiClient.formatDioError(e)}',
        );
      } finally {
        _detailsPrefetchInFlight.remove(id);
      }
    }
  }

  // ─── Error helpers ───────────────────────────────────────────────────────────

  bool _isNoInternetError(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return true;
      }

      if (e.error is SocketException) return true;

      final raw = '${e.error ?? ''} ${e.message ?? ''}'.toLowerCase();

      return raw.contains('failed host lookup') ||
          raw.contains('network is unreachable') ||
          raw.contains('no address associated with hostname') ||
          raw.contains('temporary failure in name resolution') ||
          raw.contains('connection refused') ||
          raw.contains('connection failed') ||
          raw.contains('connection error') ||
          raw.contains('connection timed out') ||
          raw.contains('receive timeout') ||
          raw.contains('send timeout');
    }

    final raw = e.toString().toLowerCase();

    return raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection refused') ||
        raw.contains('connection failed') ||
        raw.contains('connection error') ||
        raw.contains('connection timed out') ||
        raw.contains('receive timeout') ||
        raw.contains('send timeout');
  }

  bool _isServerError(String msg) {
    return msg.contains('500') ||
        msg.contains('502') ||
        msg.contains('503') ||
        msg.contains('504') ||
        msg.contains('internal server error') ||
        msg.contains('server error');
  }

  String _mapErrorMessage(Object e) {
    if (_isNoInternetError(e)) {
      return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';
    }

    final msg = ApiClient.formatDioError(e).toLowerCase();

    if (_isServerError(msg)) {
      return 'حدث خطأ في الخادم. يرجى المحاولة مرة أخرى لاحقًا';
    }

    return 'تعذّر تحميل المجموعات. يرجى المحاولة مرة أخرى';
  }

  // ─── Public helpers ──────────────────────────────────────────────────────────

  void clearError() {
    if (error == null && apiError == null) return;

    error = null;
    apiError = null;
    notifyListeners();
  }

  void reset() {
    loading = false;
    hasLoadedOnce = false;
    error = null;
    apiError = null;
    _incrementInFlight.clear();
    _detailsPrefetchInFlight.clear();
    _collections.clear();
    notifyListeners();
  }

  // ─── Load ────────────────────────────────────────────────────────────────────

  Future<void> loadAll() async {
    final cached = _loadFromCache();

    if (cached != null) {
      try {
        _collections
          ..clear()
          ..addAll(
            (cached as List).whereType<Map>().map(
                  (e) => ExploreCollectionUiModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                ),
          );

        hasLoadedOnce = true;
        notifyListeners();
      } catch (_) {
        _collections.clear();
      }
    } else {
      loading = true;
      notifyListeners();
    }

    error = null;
    apiError = null;

    try {
      final raw = await _api.getOthersCollections(auth: true);

      await _saveToCache(raw);

      _collections
        ..clear()
        ..addAll(
          raw.whereType<Map>().map(
                (e) => ExploreCollectionUiModel.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              ),
        );

      notifyListeners();


      unawaited(_prefetchDetailsForRawCollections(raw));
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        error = 'غير مصرح. سجّل دخول من جديد.';
      } else if (_collections.isEmpty) {
        error = _mapErrorMessage(e);
      } else if (_isNoInternetError(e)) {
        apiError = 'أنت غير متصل بالإنترنت، يتم عرض آخر بيانات محفوظة';
      } else {
        apiError = _mapErrorMessage(e);
      }
    } finally {
      loading = false;
      hasLoadedOnce = true;
      notifyListeners();
    }
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

  Future<String?> joinAction(String id) async {
    final index = _collections.indexWhere((e) => e.id == id);

    if (index == -1) {
      return 'فشل إرسال طلب الانضمام، يرجى المحاولة مرة أخرى';
    }

    final current = _collections[index];

    if (current.joinStatus.trim().toLowerCase() == 'pending') {
      return null;
    }

    try {
      await _api.createJoinRequest(id, auth: true);

      _collections[index] = current.copyWith(joinStatus: 'pending');
      notifyListeners();

      return null;
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('409') || msg.toLowerCase().contains('conflict')) {
        _collections[index] = current.copyWith(joinStatus: 'pending');
        notifyListeners();

        return null;
      }

      return 'فشل إرسال طلب الانضمام، يرجى المحاولة مرة أخرى';
    }
  }

  Future<void> incrementViewOnce(String collectionId) async {
    if (_incrementInFlight.contains(collectionId)) return;

    _incrementInFlight.add(collectionId);

    try {
      final res = await _api.incrementView(collectionId, auth: true);
      final updatedViews = res['numOfViewers'];

      final i = _collections.indexWhere((c) => c.id == collectionId);

      if (i != -1 && updatedViews != null) {
        final current = _collections[i];

        _collections[i] = current.copyWith(numOfViewers: updatedViews as int);
        notifyListeners();
      }
    } catch (e) {
      debugPrint(
        '[Explore] incrementView failed: ${ApiClient.formatDioError(e)}',
      );
    } finally {
      _incrementInFlight.remove(collectionId);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ExploreCollectionDetailsViewModel
// ─────────────────────────────────────────────────────────────────────────────

class ExploreCollectionDetailsViewModel extends ChangeNotifier {
  final ApiClient _client;
  late final SharedCollectionApi _api;
  final TokenStorage _tokenStorage = TokenStorage();

  final String collectionId;

  ExploreCollectionDetailsViewModel({
    required this.collectionId,
    required ExploreCollectionUiModel initialCollection,
    ApiClient? api,
  })  : _client = api ?? ApiClient(),
        collection = CollectionsDetailsUiModel(
          id: initialCollection.id,
          collectionName: initialCollection.collectionName,
          collectionDescription: initialCollection.collectionDescription,
          ownerUsername: initialCollection.ownerUsername ?? '',
          numOfViewers: initialCollection.numOfViewers ?? 0,
          isOwned: false,
          members: const [],
        ) {
    _api = SharedCollectionApi(_client);
    loadDetails();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? error;
  String? apiError;

  CollectionsDetailsUiModel collection;

  final List<AddedNewsModel> _news = [];
  List<AddedNewsModel> get news => List.unmodifiable(_news);

  // ─── Cache helpers ───────────────────────────────────────────────────────────

  Future<void> _saveToCache(Map<String, dynamic> data) async {
    if (!Hive.isBoxOpen('collections_cache')) return;

    final box = Hive.box('collections_cache');
    await box.put('explore_details_$collectionId', data);
    await box.put(
      'explore_details_${collectionId}_cached_at',
      DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic>? _loadFromCache() {
    if (!Hive.isBoxOpen('collections_cache')) return null;

    final raw = Hive.box('collections_cache').get('explore_details_$collectionId');

    if (raw == null) return null;

    try {
      return Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      return null;
    }
  }

  // ─── Error helpers ───────────────────────────────────────────────────────────

  bool _isNoInternetError(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return true;
      }

      if (e.error is SocketException) return true;

      final raw = '${e.error ?? ''} ${e.message ?? ''}'.toLowerCase();

      return raw.contains('failed host lookup') ||
          raw.contains('network is unreachable') ||
          raw.contains('no address associated with hostname') ||
          raw.contains('temporary failure in name resolution') ||
          raw.contains('connection refused') ||
          raw.contains('connection failed') ||
          raw.contains('connection error') ||
          raw.contains('connection timed out') ||
          raw.contains('receive timeout') ||
          raw.contains('send timeout');
    }

    final raw = e.toString().toLowerCase();

    return raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection refused') ||
        raw.contains('connection failed') ||
        raw.contains('connection error') ||
        raw.contains('connection timed out') ||
        raw.contains('receive timeout') ||
        raw.contains('send timeout');
  }

  bool _isServerError(String msg) {
    return msg.contains('500') ||
        msg.contains('502') ||
        msg.contains('503') ||
        msg.contains('504') ||
        msg.contains('internal server error') ||
        msg.contains('server error');
  }

  String _mapErrorMessage(Object e) {
    if (_isNoInternetError(e)) {
      return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';
    }

    final msg = ApiClient.formatDioError(e).toLowerCase();

    if (_isServerError(msg)) {
      return 'حدث خطأ في الخادم. يرجى المحاولة مرة أخرى لاحقًا';
    }

    return 'تعذّر تحميل تفاصيل المجموعة. يرجى المحاولة مرة أخرى';
  }

  // ─── Load ────────────────────────────────────────────────────────────────────

  Future<void> loadDetails() async {
    final cached = _loadFromCache();
    final hadCachedDetails = cached != null;

    if (cached != null) {
      _applyResponse(cached);
      notifyListeners();
    } else {
      _isLoading = true;
      notifyListeners();
    }

    error = null;
    apiError = null;

    try {
      final res = await _api.getCollectionDetails(collectionId);

      await _saveToCache(res);
      _applyResponse(res);
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        error = 'غير مصرح. سجّل دخول من جديد.';
      } else if (_isNoInternetError(e)) {
        if (hadCachedDetails) {
          apiError = 'أنت غير متصل بالإنترنت، يتم عرض آخر بيانات محفوظة';
        } else {


          error = 'لا يمكن عرض أخبار هذه المجموعة بدون إنترنت لأنها لم تُحفظ بعد';
        }
      } else if (collection.id.isEmpty) {
        error = _mapErrorMessage(e);
      } else {
        apiError = _mapErrorMessage(e);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyResponse(Map<String, dynamic> res) {
    final collectionJson = (res['collection'] is Map)
        ? Map<String, dynamic>.from(res['collection'])
        : <String, dynamic>{};

    final newsRaw = (res['addedNews'] as List?) ?? const [];

    collection = CollectionsDetailsUiModel(
      id: (collectionJson['id'] ?? collectionJson['_id'] ?? '').toString(),
      collectionName: (collectionJson['collectionName'] ?? '').toString(),
      collectionDescription:
          (collectionJson['collectionDescription'] ?? '').toString(),
      ownerUsername: (collectionJson['ownerUsername'] ?? '').toString(),
      numOfViewers: _asInt(collectionJson['numOfViewers']),
      isOwned: false,
      members: const [],
    );

    _news
      ..clear()
      ..addAll(_parseNews(newsRaw, collectionId: collection.id));
  }

  List<AddedNewsModel> _parseNews(List newsRaw, {required String collectionId}) {
    return newsRaw.whereType<Map>().map((e) {
      final map = Map<String, dynamic>.from(e);

      final normalized = <String, dynamic>{
        'id': map['id'] ?? map['_id'],
        'sharedCollectionId': collectionId,
        'originalNewsId': map['originalNewsId'] ?? '',
        'addedByUserId': map['addedByUserId'] ?? '',
        'newsTitle': map['newsTitle'] ?? map['title'] ?? '',
        'newsContent': map['newsContent'] ?? map['content'] ?? '',
        'newsSource': map['newsSource'] ?? map['source'] ?? '',
        'sourceLink': map['sourceLink'] ?? '',
        'category': map['category'] ?? '',
        'publishDate': map['publishDate'] ?? map['date'],
        'ttsAudioURLforContent': map['ttsAudioURLforContent'] ?? '',
        'ttsAudioURLforSummary': map['ttsAudioURLforSummary'] ?? '',
        'summaryText': map['summaryText'] ?? '',
        'createdAt': map['createdAt'],
      };

      return AddedNewsModel.fromJson(
        normalized,
        sharedByCreator: map['sharedByCreator'] == true,
        isAddedByMe: false,
      );
    }).toList();
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }
}
