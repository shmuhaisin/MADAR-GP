import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/shared_collection_api.dart';
import '../../../core/storage/token_storage.dart';
import '../../news/viewModels/article_detail_view_model.dart' show AudioUiState;
import '../model/added_news_model.dart';
import '../model/collections_models.dart';
import '../model/join_request_model.dart';
import '../model/member_model.dart';
import '../model/report_models.dart';


mixin _CollectionErrorHelper {
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



  bool isServerError(String msg) {
    return msg.contains('500') ||
        msg.contains('502') ||
        msg.contains('503') ||
        msg.contains('504') ||
        msg.contains('internal server error') ||
        msg.contains('server error');
  }

  String mapErrorMessage(Object e, {String fallback = 'تعذّر تحميل البيانات. يرجى المحاولة مرة أخرى'}) {
    if (_isNoInternetError(e)) {
      return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';
    }
    final msg = ApiClient.formatDioError(e).toLowerCase();
    if (isServerError(msg)) {
      return 'حدث خطأ في الخادم. يرجى المحاولة مرة أخرى لاحقًا';
    }
    return fallback;
  }

  String mapActionErrorMessage(Object e, {required String action}) {
    if (_isNoInternetError(e)) {
      return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';
    }
    final msg = ApiClient.formatDioError(e).toLowerCase();
    if (isServerError(msg)) {
      return 'حدث خطأ في الخادم. يرجى المحاولة مرة أخرى لاحقًا';
    }
    return 'تعذّر $action. يرجى المحاولة مرة أخرى';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OwnedCollectionDetailsViewModel
// ─────────────────────────────────────────────────────────────────────────────

class OwnedCollectionDetailsViewModel extends ChangeNotifier
    with _CollectionErrorHelper {
  final ApiClient _client;
  late final SharedCollectionApi _api;
  final TokenStorage _tokenStorage = TokenStorage();

  final String collectionId;

  OwnedCollectionDetailsViewModel({
    required this.collectionId,
    ApiClient? api,
  }) : _client = api ?? ApiClient() {
    _api = SharedCollectionApi(_client);
    loadDetails();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;


  String? error;


  String? apiError;

  int notificationsCount = 2;
  int selectedTabIndex = 2;

  void setTab(int index) {
    selectedTabIndex = index;
    notifyListeners();
  }

  CollectionsDetailsUiModel ownedCollection = const CollectionsDetailsUiModel(
    id: '',
    collectionName: '',
    collectionDescription: '',
    ownerUsername: '',
    numOfViewers: 0,
    isOwned: true,
    members: [],
  );

  final List<AddedNewsModel> _news = [];
  List<AddedNewsModel> get news => List.unmodifiable(_news);

  bool archivedLoading = false;
  String? archivedError;

  final List<AddedNewsModel> _archivedNews = [];
  List<AddedNewsModel> get archivedNews => List.unmodifiable(_archivedNews);

  final List<ReportModel> _reports = [];
  List<ReportModel> get reports => List.unmodifiable(_reports);

  bool reportsLoading = false;
  String? reportsError;

  final List<JoinRequestModel> _joinRequests = [];
  List<JoinRequestModel> get joinRequests => List.unmodifiable(_joinRequests);

  bool joinRequestsLoading = false;
  String? joinRequestsError;

  // ─── Cache helpers ───────────────────────────────────────────────────────────

  Future<void> _saveToCache(Map<String, dynamic> data) async {
    if (!Hive.isBoxOpen('collections_cache')) return;
    final box = Hive.box('collections_cache');
    await box.put('owned_details_$collectionId', data);
    await box.put('owned_details_${collectionId}_cached_at',
        DateTime.now().toIso8601String());
  }

  Map<String, dynamic>? _loadFromCache() {
    if (!Hive.isBoxOpen('collections_cache')) return null;
    final raw =
        Hive.box('collections_cache').get('owned_details_$collectionId');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      return null;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String usernameForUserId(String userId) {
    final u = userId.trim();
    if (u.isEmpty) return '';
    final match =
        ownedCollection.members.where((m) => m.userId == u).toList();
    if (match.isNotEmpty) return match.first.username;
    return '';
  }

  // ─── Load ────────────────────────────────────────────────────────────────────

  Future<void> loadDetails() async {
    final cached = _loadFromCache();
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

      final collectionJson = (res['collection'] is Map)
          ? Map<String, dynamic>.from(res['collection'])
          : <String, dynamic>{};

      final membersRaw = (collectionJson['members'] as List?) ?? const [];
      final newsRaw = (res['addedNews'] as List?) ?? const [];

      final members = membersRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(MemberModel.fromJson)
          .toList();

      ownedCollection = CollectionsDetailsUiModel(
        id: (collectionJson['id'] ?? collectionJson['_id'] ?? '').toString(),
        collectionName: (collectionJson['collectionName'] ?? '').toString(),
        collectionDescription:
            (collectionJson['collectionDescription'] ?? '').toString(),
        ownerUsername: (collectionJson['ownerUsername'] ?? '').toString(),
        numOfViewers: _asInt(collectionJson['numOfViewers']),
        isOwned: true,
        members: members,
      );

      _news
        ..clear()
        ..addAll(_parseNews(newsRaw));
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        error = 'غير مصرح. سجّل دخول من جديد.';
      } else if (ownedCollection.id.isEmpty) {
        error = mapErrorMessage(e,
            fallback: 'تعذّر تحميل تفاصيل المجموعة. يرجى المحاولة مرة أخرى');
      } else if (_isNoInternetError(e)) {
        apiError = 'أنت غير متصل بالإنترنت، يتم عرض آخر بيانات محفوظة';
      } else {
        apiError = mapErrorMessage(e,
            fallback: 'تعذّر تحميل تفاصيل المجموعة. يرجى المحاولة مرة أخرى');
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

    final membersRaw = (collectionJson['members'] as List?) ?? const [];
    final newsRaw = (res['addedNews'] as List?) ?? const [];

    final members = membersRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map(MemberModel.fromJson)
        .toList();

    ownedCollection = CollectionsDetailsUiModel(
      id: (collectionJson['id'] ?? collectionJson['_id'] ?? '').toString(),
      collectionName: (collectionJson['collectionName'] ?? '').toString(),
      collectionDescription:
          (collectionJson['collectionDescription'] ?? '').toString(),
      ownerUsername: (collectionJson['ownerUsername'] ?? '').toString(),
      numOfViewers: _asInt(collectionJson['numOfViewers']),
      isOwned: true,
      members: members,
    );

    _news
      ..clear()
      ..addAll(_parseNews(newsRaw));
  }

  List<AddedNewsModel> _parseNews(List newsRaw) {
    return newsRaw.whereType<Map>().map((e) {
      final map = Map<String, dynamic>.from(e);
      return AddedNewsModel.fromJson(
        map,
        sharedByCreator: map['sharedByCreator'] == true,
        isAddedByMe: map['isAddedByMe'] == true,
      );
    }).toList();
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  // ─── Sub-loads ───────────────────────────────────────────────────────────────

  String get _archivedCacheKey => 'archived_news_$collectionId';

  List<dynamic>? _loadArchivedRawFromCache() {
    if (!Hive.isBoxOpen('collections_cache')) return null;

    final raw = Hive.box('collections_cache').get(_archivedCacheKey);
    if (raw is! List) return null;

    return raw;
  }

  Future<void> _saveArchivedRawToCache(List<dynamic> raw) async {
    if (!Hive.isBoxOpen('collections_cache')) return;

    final box = Hive.box('collections_cache');
    await box.put(_archivedCacheKey, raw);
    await box.put(
      '${_archivedCacheKey}_cached_at',
      DateTime.now().toIso8601String(),
    );
  }

  String _safeString(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.toLowerCase() == 'null') return '';
    return text;
  }

  dynamic _readAddedNewsField(AddedNewsModel item, String name) {
    final dynamic n = item;

    try {
      switch (name) {
        case 'id':
          return n.id;
        case '_id':
          return n.id;
        case 'sharedCollectionId':
          return n.sharedCollectionId;
        case 'originalNewsId':
          return n.originalNewsId;
        case 'addedByUserId':
          return n.addedByUserId;
        case 'newsTitle':
          return n.newsTitle;
        case 'newsContent':
          return n.newsContent;
        case 'newsSource':
          return n.newsSource;
        case 'sourceLink':
          return n.sourceLink;
        case 'category':
          return n.category;
        case 'publishDate':
          return n.publishDate;
        case 'ttsAudioURLforContent':
          return n.ttsAudioURLforContent;
        case 'ttsAudioURLforSummary':
          return n.ttsAudioURLforSummary;
        case 'summaryText':
          return n.summaryText;
        case 'createdAt':
          return n.createdAt;
        case 'sharedByCreator':
          return n.sharedByCreator;
        case 'isAddedByMe':
          return n.isAddedByMe;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Map<String, dynamic> _addedNewsToCacheMap(AddedNewsModel item) {
    dynamic dateToCache(dynamic value) {
      if (value is DateTime) return value.toIso8601String();
      return value;
    }

    return <String, dynamic>{
      'id': _safeString(_readAddedNewsField(item, 'id')),
      '_id': _safeString(_readAddedNewsField(item, 'id')),
      'sharedCollectionId': _safeString(
        _readAddedNewsField(item, 'sharedCollectionId'),
      ),
      'originalNewsId': _safeString(
        _readAddedNewsField(item, 'originalNewsId'),
      ),
      'addedByUserId': _safeString(
        _readAddedNewsField(item, 'addedByUserId'),
      ),
      'newsTitle': _safeString(_readAddedNewsField(item, 'newsTitle')),
      'newsContent': _safeString(_readAddedNewsField(item, 'newsContent')),
      'newsSource': _safeString(_readAddedNewsField(item, 'newsSource')),
      'sourceLink': _safeString(_readAddedNewsField(item, 'sourceLink')),
      'category': _safeString(_readAddedNewsField(item, 'category')),
      'publishDate': dateToCache(_readAddedNewsField(item, 'publishDate')),
      'ttsAudioURLforContent': _safeString(
        _readAddedNewsField(item, 'ttsAudioURLforContent'),
      ),
      'ttsAudioURLforSummary': _safeString(
        _readAddedNewsField(item, 'ttsAudioURLforSummary'),
      ),
      'summaryText': _safeString(_readAddedNewsField(item, 'summaryText')),
      'createdAt': dateToCache(_readAddedNewsField(item, 'createdAt')),
      'sharedByCreator': _readAddedNewsField(item, 'sharedByCreator') == true,
      'isAddedByMe': _readAddedNewsField(item, 'isAddedByMe') == true,
    };
  }

  Future<void> _syncArchivedCacheFromCurrentList() async {
    await _saveArchivedRawToCache(
      _archivedNews.map(_addedNewsToCacheMap).toList(),
    );
  }

  Future<void> _syncOwnedDetailsCacheFromCurrentState() async {
    if (!Hive.isBoxOpen('collections_cache')) return;

    final cached = _loadFromCache() ?? <String, dynamic>{};
    final next = Map<String, dynamic>.from(cached);

    final collectionJson = (next['collection'] is Map)
        ? Map<String, dynamic>.from(next['collection'] as Map)
        : <String, dynamic>{};

    collectionJson['id'] = ownedCollection.id;
    collectionJson['_id'] = ownedCollection.id;
    collectionJson['collectionName'] = ownedCollection.collectionName;
    collectionJson['collectionDescription'] =
        ownedCollection.collectionDescription;
    collectionJson['ownerUsername'] = ownedCollection.ownerUsername;
    collectionJson['numOfViewers'] = ownedCollection.numOfViewers;

    next['collection'] = collectionJson;
    next['addedNews'] = _news.map(_addedNewsToCacheMap).toList();

    await _saveToCache(next);
  }

  Future<void> loadArchivedNews() async {
    final cachedRaw = _loadArchivedRawFromCache();

    if (cachedRaw != null) {
      try {
        _archivedNews
          ..clear()
          ..addAll(_parseNews(cachedRaw));
        archivedError = null;
        notifyListeners();
      } catch (_) {
        // Ignore corrupted cache and try the API.
      }
    } else {
      archivedLoading = true;
      archivedError = null;
      notifyListeners();
    }

    if (cachedRaw != null) {
      archivedLoading = false;
      archivedError = null;
      notifyListeners();
    } else {
      archivedLoading = true;
      archivedError = null;
      notifyListeners();
    }

    try {
      final res = await _api.getArchivedNews(collectionId, auth: true);
      final raw = (res['archivedNews'] as List?) ?? const [];

      await _saveArchivedRawToCache(raw);

      _archivedNews
        ..clear()
        ..addAll(_parseNews(raw));

      archivedError = null;
    } catch (e) {
      if (_archivedNews.isEmpty) {
        archivedError =
            mapActionErrorMessage(e, action: 'تحميل الأخبار المؤرشفة');
      } else if (_isNoInternetError(e)) {
        archivedError = null;
      }
    } finally {
      archivedLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadReports() async {
    if (Hive.isBoxOpen('collections_cache')) {
      final cachedRaw =
          Hive.box('collections_cache').get('reports_$collectionId');
      if (cachedRaw != null) {
        try {
          _reports
            ..clear()
            ..addAll(
              (cachedRaw as List)
                  .whereType<Map>()
                  .map((e) =>
                      ReportModel.fromJson(Map<String, dynamic>.from(e))),
            );
          notifyListeners();
        } catch (_) {}
      }
    }

    reportsLoading = true;
    reportsError = null;
    notifyListeners();

    try {
      final res = await _api.getReports(collectionId, auth: true);
      final raw = (res['reports'] as List?) ?? const [];

      if (Hive.isBoxOpen('collections_cache')) {
        await Hive.box('collections_cache').put('reports_$collectionId', raw);
      }

      _reports
        ..clear()
        ..addAll(
          raw
              .whereType<Map>()
              .map((e) =>
                  ReportModel.fromJson(Map<String, dynamic>.from(e))),
        );
    } catch (e) {
      if (_reports.isEmpty) {
        reportsError = mapActionErrorMessage(e, action: 'تحميل البلاغات');
      }
    } finally {
      reportsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadJoinRequests() async {
    joinRequestsLoading = true;
    joinRequestsError = null;
    notifyListeners();

    try {
      final res = await _api.getJoinRequests(collectionId, auth: true);
      final raw = (res['requests'] as List?) ?? const [];

      _joinRequests
        ..clear()
        ..addAll(
          raw.map(
            (e) => JoinRequestModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          ),
        );
    } catch (e) {
      joinRequestsError =
          mapActionErrorMessage(e, action: 'تحميل طلبات الانضمام');
    } finally {
      joinRequestsLoading = false;
      notifyListeners();
    }
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

  Future<bool> archiveNews(String addedNewsId) async {
    try {
      await _api.archiveAddedNews(collectionId, addedNewsId, auth: true);

      AddedNewsModel? archivedItem;
      for (final item in _news) {
        if (item.id == addedNewsId) {
          archivedItem = item;
          break;
        }
      }

      _news.removeWhere((n) => n.id == addedNewsId);

      if (archivedItem != null &&
          !_archivedNews.any((item) => item.id == addedNewsId)) {
        _archivedNews.insert(0, archivedItem);
        await _syncArchivedCacheFromCurrentList();
      }

      await _syncOwnedDetailsCacheFromCurrentState();

      notifyListeners();
      return true;
    } catch (e) {
      error = mapActionErrorMessage(e, action: 'أرشفة الخبر');
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreNews(String addedNewsId) async {
    try {
      await _api.restoreAddedNews(collectionId, addedNewsId, auth: true);
      _archivedNews.removeWhere((n) => n.id == addedNewsId);
      await _syncArchivedCacheFromCurrentList();
      notifyListeners();
      await loadDetails();
      await _syncOwnedDetailsCacheFromCurrentState();
      return true;
    } catch (e) {
      archivedError = mapActionErrorMessage(e, action: 'استعادة الخبر');
      notifyListeners();
      return false;
    }
  }

  Future<void> acceptRequest(String requestId) async {
    try {
      await _api.decideJoinRequest(
        collectionId,
        requestId,
        decision: 'accept',
        auth: true,
      );
      _joinRequests.removeWhere((r) => r.id == requestId);
      await loadDetails();
      notifyListeners();
    } catch (e) {
      joinRequestsError = mapActionErrorMessage(e, action: 'قبول الطلب');
      notifyListeners();
    }
  }

  Future<void> rejectRequest(String requestId) async {
    try {
      await _api.decideJoinRequest(
        collectionId,
        requestId,
        decision: 'reject',
        auth: true,
      );
      _joinRequests.removeWhere((r) => r.id == requestId);
      notifyListeners();
    } catch (e) {
      joinRequestsError = mapActionErrorMessage(e, action: 'رفض الطلب');
      notifyListeners();
    }
  }

  Future<String?> updateGroup(
      String newTitle, String newDescription) async {
    try {
      await _api.updateCollection(
        collectionId,
        collectionName: newTitle,
        collectionDescription: newDescription,
      );
      ownedCollection = CollectionsDetailsUiModel(
        id: ownedCollection.id,
        collectionName: newTitle,
        collectionDescription: newDescription,
        ownerUsername: ownedCollection.ownerUsername,
        numOfViewers: ownedCollection.numOfViewers,
        isOwned: ownedCollection.isOwned,
        members: ownedCollection.members,
      );
      notifyListeners();
      return null;
    } catch (e) {
      final msg = ApiClient.formatDioError(e);
      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        return 'غير مصرح. سجّل دخول من جديد.';
      }
      return mapActionErrorMessage(e, action: 'تعديل المجموعة');
    }
  }

  Future<String?> deleteMember(String memberId) async {
    try {
      await _api.deleteMember(collectionId, memberId);
      final nextMembers =
          ownedCollection.members.where((m) => m.id != memberId).toList();
      ownedCollection = CollectionsDetailsUiModel(
        id: ownedCollection.id,
        collectionName: ownedCollection.collectionName,
        collectionDescription: ownedCollection.collectionDescription,
        ownerUsername: ownedCollection.ownerUsername,
        numOfViewers: ownedCollection.numOfViewers,
        isOwned: ownedCollection.isOwned,
        members: nextMembers,
      );
      notifyListeners();
      return null;
    } catch (e) {
      final msg = ApiClient.formatDioError(e);
      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        return 'غير مصرح. سجّل دخول من جديد.';
      }
      return mapActionErrorMessage(e, action: 'إزالة العضو');
    }
  }

  Future<String?> deleteNews(String addedNewsId) async {
    try {
      await _api.deleteAddedNews(collectionId, addedNewsId, auth: true);
      _news.removeWhere((n) => n.id == addedNewsId);
      _archivedNews.removeWhere((n) => n.id == addedNewsId);
      _reports.removeWhere((r) => r.addedNewsId == addedNewsId);
      await _syncArchivedCacheFromCurrentList();
      await _syncOwnedDetailsCacheFromCurrentState();
      notifyListeners();
      return null;
    } catch (e) {
      final msg = ApiClient.formatDioError(e);
      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        return 'غير مصرح. سجّل دخول من جديد.';
      }
      return mapActionErrorMessage(e, action: 'حذف الخبر');
    }
  }

  Future<String?> deleteGroup() async {
    try {
      await _api.deleteCollection(collectionId);
      return null;
    } catch (e) {
      final msg = ApiClient.formatDioError(e);
      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        return 'غير مصرح. سجّل دخول من جديد.';
      }
      return mapActionErrorMessage(e, action: 'حذف المجموعة');
    }
  }

  Future<String?> shareCollection() async {
    try {
      final response = await _api.getShareLink(collectionId);
      return response['link'] as String;
    } catch (e) {
      final msg = ApiClient.formatDioError(e);
      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
      }
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JoinedCollectionDetailsViewModel
// ─────────────────────────────────────────────────────────────────────────────

class JoinedCollectionDetailsViewModel extends ChangeNotifier
    with _CollectionErrorHelper {
  final ApiClient _client;
  late final SharedCollectionApi _api;
  final TokenStorage _tokenStorage = TokenStorage();

  final String collectionId;

  JoinedCollectionDetailsViewModel({
    required this.collectionId,
    ApiClient? api,
  }) : _client = api ?? ApiClient() {
    _api = SharedCollectionApi(_client);
    loadDetails();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// خطأ كامل — لما ما في داتا خالص (لا كاش ولا نت)
  String? error;

  /// تحذير خفيف — لما في كاش لكن المستخدم offline
  String? apiError;

  CollectionsDetailsUiModel joinedCollection = const CollectionsDetailsUiModel(
    id: '',
    collectionName: '',
    collectionDescription: '',
    ownerUsername: '',
    numOfViewers: 0,
    isOwned: false,
    members: [],
  );

  final List<AddedNewsModel> _news = [];
  List<AddedNewsModel> get news => List.unmodifiable(_news);

  final Set<String> _reportedByMe = {};
  bool isReportedByMe(String newsId) => _reportedByMe.contains(newsId);

  final Map<String, Timer> _reportHideTimers = {};

  // ─── Cache helpers ───────────────────────────────────────────────────────────

  Future<void> _saveToCache(Map<String, dynamic> data) async {
    if (!Hive.isBoxOpen('collections_cache')) return;
    final box = Hive.box('collections_cache');
    await box.put('joined_details_$collectionId', data);
    await box.put('joined_details_${collectionId}_cached_at',
        DateTime.now().toIso8601String());
  }

  Map<String, dynamic>? _loadFromCache() {
    if (!Hive.isBoxOpen('collections_cache')) return null;
    final raw =
        Hive.box('collections_cache').get('joined_details_$collectionId');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      return null;
    }
  }

  // ─── Load ────────────────────────────────────────────────────────────────────

  Future<void> loadDetails() async {
    final cached = _loadFromCache();
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

      final collectionJson = (res['collection'] is Map)
          ? Map<String, dynamic>.from(res['collection'])
          : <String, dynamic>{};

      final newsRaw = (res['addedNews'] as List?) ?? const [];

      joinedCollection = CollectionsDetailsUiModel(
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
        ..addAll(_parseNews(newsRaw));
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        error = 'غير مصرح. سجّل دخول من جديد.';
      } else if (joinedCollection.id.isEmpty) {
        // ما في كاش + ما في نت → خطأ كامل
        error = mapErrorMessage(e,
            fallback: 'تعذّر تحميل تفاصيل المجموعة. يرجى المحاولة مرة أخرى');
      } else if (_isNoInternetError(e)) {
        // في كاش + أوفلاين → banner خفيف
        apiError = 'أنت غير متصل بالإنترنت، يتم عرض آخر بيانات محفوظة';
      } else {
        // في كاش + خطأ API عادي
        apiError = mapErrorMessage(e,
            fallback: 'تعذّر تحميل تفاصيل المجموعة. يرجى المحاولة مرة أخرى');
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

    joinedCollection = CollectionsDetailsUiModel(
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
      ..addAll(_parseNews(newsRaw));
  }

  List<AddedNewsModel> _parseNews(List newsRaw) {
    return newsRaw.whereType<Map>().map((e) {
      final map = Map<String, dynamic>.from(e);
      return AddedNewsModel.fromJson(
        map,
        sharedByCreator: map['sharedByCreator'] == true,
        isAddedByMe: map['isAddedByMe'] == true,
      );
    }).toList();
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

  Future<String?> leaveGroup() async {
    try {
      await _api.leaveCollection(collectionId);
      return null;
    } catch (e) {
      final msg = ApiClient.formatDioError(e);
      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        return 'غير مصرح. سجّل دخول من جديد.';
      }
      return mapActionErrorMessage(e, action: 'مغادرة المجموعة');
    }
  }

  Future<String?> deleteNews(String addedNewsId) async {
    try {
      await _api.deleteAddedNews(collectionId, addedNewsId, auth: true);
      _news.removeWhere((n) => n.id == addedNewsId);
      notifyListeners();
      return null;
    } catch (e) {
      final msg = ApiClient.formatDioError(e);
      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        return 'غير مصرح. سجّل دخول من جديد.';
      }
      return mapActionErrorMessage(e, action: 'حذف الخبر');
    }
  }

  void hideReportedNews(String newsId) {
    _news.removeWhere((n) => n.id == newsId);
    _reportedByMe.remove(newsId);
    _reportHideTimers.remove(newsId)?.cancel();
    notifyListeners();
  }

  void _scheduleHideReportedNews(
    String newsId, {
    Duration delay = const Duration(seconds: 30),
  }) {
    _reportHideTimers[newsId]?.cancel();
    _reportHideTimers[newsId] = Timer(delay, () {
      _news.removeWhere((n) => n.id == newsId);
      _reportedByMe.remove(newsId);
      _reportHideTimers.remove(newsId);
      notifyListeners();
    });
  }

  Future<void> reportNews(String newsId, String reason) async {
    try {
      await _api.reportAddedNews(
        collectionId,
        newsId,
        reportReason: reason,
        auth: true,
      );
      _reportedByMe.add(newsId);
      notifyListeners();
      _scheduleHideReportedNews(newsId);
    } catch (e) {
      final msg = ApiClient.formatDioError(e);
      if (msg.contains('409') ||
          msg.toLowerCase().contains('conflict') ||
          msg.contains('لقد قمت بالإبلاغ مسبقا')) {
        _reportedByMe.add(newsId);
        notifyListeners();
        _scheduleHideReportedNews(newsId);
        return;
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    for (final t in _reportHideTimers.values) {
      t.cancel();
    }
    _reportHideTimers.clear();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AddArticleToCollectionViewModel — بدون تغيير في المنطق
// ─────────────────────────────────────────────────────────────────────────────

class AddArticleToCollectionViewModel extends ChangeNotifier {
  final ApiClient _client;
  late final SharedCollectionApi _api;

  AddArticleToCollectionViewModel({ApiClient? api})
      : _client = api ?? ApiClient() {
    _api = SharedCollectionApi(_client);
  }

  bool _loading = false;
  bool get loading => _loading;

  String? error;
  AddedNewsModel? addedNews;

  Future<bool> addCurrentArticleToCollection({
    required String collectionId,
    required String originalNewsId,
  }) async {
    _loading = true;
    error = null;
    addedNews = null;
    notifyListeners();

    try {
      final res = await _api.addArticleToCollection(
        collectionId,
        originalNewsId: originalNewsId,
        auth: true,
      );

      final addedNewsJson = res['addedNews'] is Map
          ? Map<String, dynamic>.from(res['addedNews'])
          : <String, dynamic>{};

      if (addedNewsJson.isNotEmpty) {
        addedNews = AddedNewsModel.fromJson(
          addedNewsJson,
          sharedByCreator: false,
          isAddedByMe: true,
        );
      }

      return true;
    } catch (e) {
      error = _formatAddArticleError(e);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String _formatAddArticleError(dynamic e) {
    final raw = ApiClient.formatDioError(e).trim();
    if (raw.isEmpty) return 'حدث خطأ أثناء إضافة الخبر';

    final lower = raw.toLowerCase();

    if (lower.contains('409') ||
        lower.contains('conflict') ||
        raw.contains('موجود بالفعل') ||
        raw.contains('الخبر موجود بالفعل')) {
      return 'هذا الخبر موجود بالفعل في المجموعة';
    }
    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        raw.contains('غير مصرح')) {
      return 'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى';
    }
    if (lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout')) {
      return 'تعذّر الاتصال بالخادم، تحقق من الإنترنت';
    }
    if (lower.contains('500') || lower.contains('internal server')) {
      return 'حدث خطأ في الخادم، حاول مرة أخرى لاحقًا';
    }

    return 'حدث خطأ أثناء إضافة الخبر';
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  void clearAddedNews() {
    addedNews = null;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AddedNewsDetailViewModel — fixed offline/cache behavior only
// ─────────────────────────────────────────────────────────────────────────────

class AddedNewsDetailViewModel extends ChangeNotifier {
  final ApiClient _client;
  late final SharedCollectionApi _api;
  final TokenStorage _tokenStorage = TokenStorage();

  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  final String collectionId;
  AddedNewsModel news;

  bool summaryLoading = false;
  bool summaryEnabled = false;
  bool ttsEnabled = false;
  bool audioLoading = false;
  bool isPlayingAudio = false;

  Duration audioPosition = Duration.zero;
  Duration audioDuration = Duration.zero;

  String currentAudioMode = 'full';
  AudioUiState audioUiState = AudioUiState.idle;

  String? error;

  AddedNewsDetailViewModel({
    required this.collectionId,
    required this.news,
    ApiClient? api,
  }) : _client = api ?? ApiClient() {
    _api = SharedCollectionApi(_client);
    _restoreCachedEnhancements();
    _bindAudioPlayer();
    unawaited(_saveEnhancementsToCache());
  }

  String get _detailCacheKey => 'added_news_detail_${collectionId}_${news.id}';

  void _restoreCachedEnhancements() {
    if (!Hive.isBoxOpen('collections_cache')) return;

    final raw = Hive.box('collections_cache').get(_detailCacheKey);
    if (raw == null || raw is! Map) return;

    try {
      final data = Map<String, dynamic>.from(raw);

      final cachedSummary = (data['summaryText'] ?? '').toString().trim();
      final cachedFullAudio =
          (data['ttsAudioURLforContent'] ?? '').toString().trim();
      final cachedSummaryAudio =
          (data['ttsAudioURLforSummary'] ?? '').toString().trim();

      if (cachedSummary.isNotEmpty && news.summaryText.trim().isEmpty) {
        news = news.copyWith(summaryText: cachedSummary);
      }

      if (cachedFullAudio.isNotEmpty &&
          news.ttsAudioURLforContent.trim().isEmpty) {
        news = news.copyWith(ttsAudioURLforContent: cachedFullAudio);
      }

      if (cachedSummaryAudio.isNotEmpty &&
          news.ttsAudioURLforSummary.trim().isEmpty) {
        news = news.copyWith(ttsAudioURLforSummary: cachedSummaryAudio);
      }
    } catch (_) {
      // Ignore corrupted cache. The screen can still display the news received
      // from the collection details page.
    }
  }

  Future<void> _saveEnhancementsToCache() async {
    if (!Hive.isBoxOpen('collections_cache')) return;

    final summaryText = news.summaryText.trim();
    final fullAudioUrl = news.ttsAudioURLforContent.trim();
    final summaryAudioUrl = news.ttsAudioURLforSummary.trim();

    if (summaryText.isEmpty &&
        fullAudioUrl.isEmpty &&
        summaryAudioUrl.isEmpty) {
      return;
    }

    final box = Hive.box('collections_cache');

    await box.put(_detailCacheKey, {
      'summaryText': summaryText,
      'ttsAudioURLforContent': fullAudioUrl,
      'ttsAudioURLforSummary': summaryAudioUrl,
      'cachedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 3),
      );

      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

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

  void _bindAudioPlayer() {
    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      isPlayingAudio = state.playing;

      if (state.processingState == ProcessingState.completed) {
        ttsEnabled = false;
        isPlayingAudio = false;
        audioPosition = Duration.zero;
        audioUiState = AudioUiState.idle;
        notifyListeners();
        return;
      }

      if (state.playing) {
        audioUiState = AudioUiState.playing;
      } else if (audioPosition > Duration.zero) {
        audioUiState = AudioUiState.paused;
      } else if (!audioLoading) {
        audioUiState = AudioUiState.idle;
      }

      notifyListeners();
    });

    _positionSub = _audioPlayer.positionStream.listen((position) {
      audioPosition = position;
      notifyListeners();
    });

    _durationSub = _audioPlayer.durationStream.listen((duration) {
      audioDuration = duration ?? Duration.zero;
      notifyListeners();
    });
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  Future<void> toggleTts(bool v) async {
    if (audioUiState == AudioUiState.loading) return;

    if (audioUiState == AudioUiState.playing) {
      ttsEnabled = false;
      await stopAudio();
      notifyListeners();
      return;
    }

    if (audioUiState == AudioUiState.paused) {
      ttsEnabled = true;
      await resumeAudio();
      notifyListeners();
      return;
    }

    ttsEnabled = v;
    notifyListeners();

    if (!v) {
      await stopAudio();
      return;
    }

    await playCurrentAudio();
  }

  Future<void> toggleSummary(bool v) async {
    summaryEnabled = v;
    notifyListeners();

    if (v && news.summaryText.trim().isEmpty) {
      await loadSummary();
    }

    if (ttsEnabled) {
      await playCurrentAudio();
    }
  }

  Future<void> loadSummary() async {
    if (news.summaryText.trim().isNotEmpty) {
      await _saveEnhancementsToCache();
      return;
    }

    summaryLoading = true;
    error = null;
    notifyListeners();

    try {
      final online = await _hasInternetConnection();

      if (!online) {
        summaryEnabled = false;
        summaryLoading = false;
        error = 'الملخص غير متاح بدون إنترنت';
        notifyListeners();
        return;
      }

      final res = await _api.getAddedNewsSummary(
        collectionId,
        news.id,
        auth: true,
      );

      final summaryText = (res['summaryText'] ?? '').toString().trim();

      if (summaryText.isNotEmpty) {
        news = news.copyWith(summaryText: summaryText);
        await _saveEnhancementsToCache();
      }
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        summaryEnabled = false;
        error = 'غير مصرح. سجّل دخول من جديد.';
      } else if (_isNoInternetError(e)) {
        summaryEnabled = false;
        error = 'الملخص غير متاح بدون إنترنت';
      } else {
        summaryEnabled = false;
        error = 'تعذّر تحميل الملخص. يرجى المحاولة مرة أخرى';
      }
    } finally {
      summaryLoading = false;
      notifyListeners();
    }
  }

  Future<void> playCurrentAudio() async {
    final mode = summaryEnabled ? 'summary' : 'full';

    try {
      audioLoading = true;
      audioUiState = AudioUiState.loading;
      error = null;
      notifyListeners();

      final online = await _hasInternetConnection();

      if (!online) {
        audioLoading = false;
        ttsEnabled = false;
        isPlayingAudio = false;
        audioUiState = AudioUiState.idle;
        error = 'الاستماع غير متاح بدون إنترنت';
        notifyListeners();
        return;
      }

      final data = await _api.getAddedNewsAudio(
        collectionId,
        news.id,
        mode: mode,
        auth: true,
      );

      final url = (data['url'] ?? '').toString().trim();

      if (url.isEmpty) throw Exception('Audio URL is empty');

      final rawAddedNews = data['addedNews'];

      if (rawAddedNews is Map) {
        news = AddedNewsModel.fromJson(
          Map<String, dynamic>.from(rawAddedNews),
          sharedByCreator: news.sharedByCreator,
          isAddedByMe: news.isAddedByMe,
        );
      } else {
        news = mode == 'summary'
            ? news.copyWith(ttsAudioURLforSummary: url)
            : news.copyWith(ttsAudioURLforContent: url);
      }

      currentAudioMode = mode;
      await _saveEnhancementsToCache();

      await _audioPlayer.stop();
      await _audioPlayer.setUrl(url);

      audioLoading = false;
      isPlayingAudio = true;
      audioUiState = AudioUiState.playing;
      notifyListeners();

      unawaited(_audioPlayer.play());
    } catch (e, s) {
      debugPrint('ADDED NEWS PLAY AUDIO ERROR => $e');
      debugPrint('ADDED NEWS PLAY AUDIO STACK => $s');

      audioLoading = false;
      ttsEnabled = false;
      isPlayingAudio = false;
      audioUiState = AudioUiState.idle;

      if (_isNoInternetError(e)) {
        error = 'الاستماع غير متاح بدون إنترنت';
      } else {
        error = 'تعذر تشغيل الصوت';
      }

      notifyListeners();
    }
  }

  Future<void> pauseAudio() async {
    await _audioPlayer.pause();
    isPlayingAudio = false;
    audioUiState = AudioUiState.paused;
    notifyListeners();
  }

  Future<void> resumeAudio() async {
    await _audioPlayer.play();
    isPlayingAudio = true;
    audioUiState = AudioUiState.playing;
    notifyListeners();
  }

  Future<void> stopAudio() async {
    await _audioPlayer.stop();
    isPlayingAudio = false;
    audioPosition = Duration.zero;
    audioDuration = Duration.zero;
    audioUiState = AudioUiState.idle;
    notifyListeners();
  }

  Future<void> replayAudio() async {
    await _audioPlayer.seek(Duration.zero);
    await _audioPlayer.play();
    isPlayingAudio = true;
    audioUiState = AudioUiState.playing;
    notifyListeners();
  }

  String get displayedContent {
    if (summaryEnabled && news.summaryText.trim().isNotEmpty) {
      return news.summaryText;
    }
    return news.newsContent;
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}