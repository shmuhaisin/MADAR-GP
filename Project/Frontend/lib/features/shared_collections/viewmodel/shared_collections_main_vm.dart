import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/api/shared_collection_api.dart';
import '../model/collections_models.dart';

class SharedCollectionsViewModel extends ChangeNotifier {
  final ApiClient _client;
  late final SharedCollectionApi _api;
  final TokenStorage _tokenStorage = TokenStorage();

  SharedCollectionsViewModel({ApiClient? api}) : _client = api ?? ApiClient() {
    _api = SharedCollectionApi(_client);
  }

  bool loading = false;
  String? error;
  String? apiError;

  final List<SharedCollectionUiModel> _owned = [];
  final List<SharedCollectionUiModel> _joined = [];

  List<SharedCollectionUiModel> get ownedCollections =>
      List.unmodifiable(_owned);
  List<SharedCollectionUiModel> get joinedCollections =>
      List.unmodifiable(_joined);

  // ─── Cache helpers ───────────────────────────────────────────────────────────

  Future<void> _saveToCache(String key, dynamic data) async {
    if (!Hive.isBoxOpen('collections_cache')) return;
    final box = Hive.box('collections_cache');
    await box.put(key, data);
    await box.put('${key}_cached_at', DateTime.now().toIso8601String());
  }

  dynamic _loadFromCache(String key) {
    if (!Hive.isBoxOpen('collections_cache')) return null;
    return Hive.box('collections_cache').get(key);
  }

  String _idFromMap(Map<String, dynamic> raw) {
    return (raw['id'] ?? raw['_id'] ?? raw['collectionId'] ?? '').toString();
  }

  int _parseDateMs(dynamic value) {
    if (value == null) return 0;

    if (value is int) {
      if (value > 1000000000000) return value; // milliseconds
      if (value > 1000000000) return value * 1000; // seconds
      return 0;
    }

    final text = value.toString().trim();
    if (text.isEmpty) return 0;

    final asInt = int.tryParse(text);
    if (asInt != null) {
      if (asInt > 1000000000000) return asInt;
      if (asInt > 1000000000) return asInt * 1000;
    }

    final parsed = DateTime.tryParse(text);
    return parsed?.millisecondsSinceEpoch ?? 0;
  }

  int _firstDateMs(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final ms = _parseDateMs(raw[key]);
      if (ms > 0) return ms;
    }

    return 0;
  }

  int _metaMs(String key) {
    if (!Hive.isBoxOpen('collections_cache')) return 0;

    final value = Hive.box('collections_cache').get(key);

    if (value is int) return value;

    if (value is String) {
      final parsedDate = DateTime.tryParse(value);
      if (parsedDate != null) return parsedDate.millisecondsSinceEpoch;

      final parsedInt = int.tryParse(value);
      if (parsedInt != null) return parsedInt;
    }

    return 0;
  }

  Future<void> _putMetaMs(String key, int value) async {
    if (!Hive.isBoxOpen('collections_cache')) return;
    await Hive.box('collections_cache').put(key, value);
  }

  Future<void> _setOwnedCreatedNow(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return;

    await _putMetaMs(
      'owned_created_ms_$cleanId',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _rememberOwnedCreatedDates(List<dynamic> rawList) async {
    if (!Hive.isBoxOpen('collections_cache')) return;

    for (var i = 0; i < rawList.length; i++) {
      final item = rawList[i];
      if (item is! Map) continue;

      final raw = Map<String, dynamic>.from(item);
      final id = _idFromMap(raw).trim();
      if (id.isEmpty) continue;

      final existing = _metaMs('owned_created_ms_$id');
      final fromServer = _firstDateMs(raw, [
        'createdAt',
        'created_at',
        'createdDate',
        'created',
        'updatedAt',
      ]);

      if (fromServer > 0) {
        await _putMetaMs('owned_created_ms_$id', fromServer);
        continue;
      }

      if (existing == 0) {
        // Fallback: preserve current API order if the backend gives no date.
        await _putMetaMs(
          'owned_created_ms_$id',
          DateTime.now().millisecondsSinceEpoch - i,
        );
      }
    }
  }

  Future<void> _rememberJoinedSortDates(List<dynamic> rawList) async {
    if (!Hive.isBoxOpen('collections_cache')) return;

    for (var i = 0; i < rawList.length; i++) {
      final item = rawList[i];
      if (item is! Map) continue;

      final raw = Map<String, dynamic>.from(item);
      final id = _idFromMap(raw).trim();
      if (id.isEmpty) continue;

      final existing = _metaMs('joined_sort_ms_$id');
      final fromServer = _firstDateMs(raw, [
        'joinedAt',
        'joined_at',
        'acceptedAt',
        'accepted_at',
        'createdAt',
        'created_at',
        'updatedAt',
      ]);

      if (fromServer > 0) {
        await _putMetaMs('joined_sort_ms_$id', fromServer);
        continue;
      }

      if (existing == 0) {
        // Fallback: preserve current API order if the backend gives no date.
        await _putMetaMs(
          'joined_sort_ms_$id',
          DateTime.now().millisecondsSinceEpoch - i,
        );
      }
    }
  }

  int _ownedScore(SharedCollectionUiModel c) {
    final id = c.id.trim();
    return _metaMs('owned_created_ms_$id');
  }

  void _sortOwnedCollections() {
    final originalIndex = <String, int>{};
    for (var i = 0; i < _owned.length; i++) {
      originalIndex[_owned[i].id] = i;
    }

    _owned.sort((a, b) {
      final aScore = _ownedScore(a);
      final bScore = _ownedScore(b);

      if (aScore != bScore) {
        return bScore.compareTo(aScore);
      }

      final aIndex = originalIndex[a.id] ?? 0;
      final bIndex = originalIndex[b.id] ?? 0;

      if (aIndex != bIndex) {
        return aIndex.compareTo(bIndex);
      }

      return a.collectionName.compareTo(b.collectionName);
    });
  }

  void _sortJoinedCollections() {
    final originalIndex = <String, int>{};
    for (var i = 0; i < _joined.length; i++) {
      originalIndex[_joined[i].id] = i;
    }

    _joined.sort((a, b) {
      final aScore = _metaMs('joined_sort_ms_${a.id}');
      final bScore = _metaMs('joined_sort_ms_${b.id}');

      if (aScore != bScore) {
        return bScore.compareTo(aScore);
      }

      final aIndex = originalIndex[a.id] ?? 0;
      final bIndex = originalIndex[b.id] ?? 0;

      return aIndex.compareTo(bIndex);
    });
  }

  Map<String, dynamic> _collectionToCacheMap(SharedCollectionUiModel c) {
    return {
      'id': c.id,
      '_id': c.id,
      'collectionName': c.collectionName,
      'collectionDescription': c.collectionDescription,
      'ownerUsername': c.ownerUsername,
      'numOfViewers': c.numOfViewers,
    };
  }

  Future<void> _saveCurrentListsToCache() async {
    if (!Hive.isBoxOpen('collections_cache')) return;

    await _saveToCache(
      'owned_collections',
      _owned.map(_collectionToCacheMap).toList(),
    );
    await _saveToCache(
      'joined_collections',
      _joined.map(_collectionToCacheMap).toList(),
    );
  }

  Future<void> _saveCollectionDetailsToCache({
    required String key,
    required Map<String, dynamic> data,
  }) async {
    if (!Hive.isBoxOpen('collections_cache')) return;

    final box = Hive.box('collections_cache');
    await box.put(key, data);
    await box.put('${key}_cached_at', DateTime.now().toIso8601String());
  }

  Future<void> _prefetchCollectionDetailsCache({
    required List<SharedCollectionUiModel> owned,
    required List<SharedCollectionUiModel> joined,
  }) async {
    if (!Hive.isBoxOpen('collections_cache')) return;

    final seenOwned = <String>{};
    final seenJoined = <String>{};

    Future<void> cacheOne({
      required String id,
      required String keyPrefix,
    }) async {
      final cleanId = id.trim();
      if (cleanId.isEmpty) return;

      try {
        final res = await _api.getCollectionDetails(cleanId);

        await _saveCollectionDetailsToCache(
          key: '${keyPrefix}_details_$cleanId',
          data: Map<String, dynamic>.from(res),
        );
      } catch (_) {
        // Do not break the main page if one collection details request fails.
        // The details page will still try to load its own data when opened.
      }
    }

    for (final collection in owned) {
      final id = collection.id.trim();
      if (id.isEmpty || !seenOwned.add(id)) continue;
      await cacheOne(id: id, keyPrefix: 'owned');
    }

    for (final collection in joined) {
      final id = collection.id.trim();
      if (id.isEmpty || !seenJoined.add(id)) continue;
      await cacheOne(id: id, keyPrefix: 'joined');
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

  // ─── Load ────────────────────────────────────────────────────────────────────

  Future<void> loadAll() async {
    final cachedOwned = _loadFromCache('owned_collections');
    final cachedJoined = _loadFromCache('joined_collections');

    if (cachedOwned != null || cachedJoined != null) {
      try {
        if (cachedOwned != null) {
          _owned
            ..clear()
            ..addAll(
              (cachedOwned as List).whereType<Map>().map(
                    (e) => SharedCollectionUiModel.fromJson(
                      Map<String, dynamic>.from(e),
                      kind: CollectionKind.owned,
                    ),
                  ),
            );
        }

        if (cachedJoined != null) {
          _joined
            ..clear()
            ..addAll(
              (cachedJoined as List).whereType<Map>().map(
                    (e) => SharedCollectionUiModel.fromJson(
                      Map<String, dynamic>.from(e),
                      kind: CollectionKind.joined,
                    ),
                  ),
            );
        }

        _sortOwnedCollections();
        _sortJoinedCollections();

        notifyListeners();
      } catch (_) {
        _owned.clear();
        _joined.clear();
        loading = true;
        notifyListeners();
      }
    } else {
      loading = true;
      notifyListeners();
    }

    error = null;
    apiError = null;

    try {
      final ownedRaw = await _api.getOwnedCollections();
      final joinedRaw = await _api.getJoinedCollections();

      await _rememberOwnedCreatedDates(ownedRaw);
      await _rememberJoinedSortDates(joinedRaw);

      _owned
        ..clear()
        ..addAll(
          ownedRaw.whereType<Map>().map(
                (e) => SharedCollectionUiModel.fromJson(
                  Map<String, dynamic>.from(e),
                  kind: CollectionKind.owned,
                ),
              ),
        );

      _joined
        ..clear()
        ..addAll(
          joinedRaw.whereType<Map>().map(
                (e) => SharedCollectionUiModel.fromJson(
                  Map<String, dynamic>.from(e),
                  kind: CollectionKind.joined,
                ),
              ),
        );

      _sortOwnedCollections();
      _sortJoinedCollections();

      await _saveCurrentListsToCache();

      unawaited(
        _prefetchCollectionDetailsCache(
          owned: List<SharedCollectionUiModel>.from(_owned),
          joined: List<SharedCollectionUiModel>.from(_joined),
        ),
      );
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        error = 'غير مصرح. سجّل دخول من جديد.';
      } else if (_owned.isEmpty && _joined.isEmpty) {
        error = _mapErrorMessage(e);
      } else if (_isNoInternetError(e)) {
        apiError = 'أنت غير متصل بالإنترنت، يتم عرض آخر بيانات محفوظة';
      } else {
        apiError = _mapErrorMessage(e);
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ─── CRUD ────────────────────────────────────────────────────────────────────

  Future<String?> createCollection({
    required String collectionName,
    required String collectionDescription,
  }) async {
    final name = collectionName.trim();
    final desc = collectionDescription.trim();

    final nameErr = _validateTitle(name);
    if (nameErr != null) return nameErr;

    final descErr = _validateDesc(desc);
    if (descErr != null) return descErr;

    try {
      final res = await _api.createCollection(
        collectionName: name,
        collectionDescription: desc,
      );

      final raw = (res['collection'] is Map)
          ? Map<String, dynamic>.from(res['collection'])
          : res;

      final created =
          SharedCollectionUiModel.fromJson(raw, kind: CollectionKind.owned);

      _owned.insert(0, created);

      await _setOwnedCreatedNow(created.id);

      _sortOwnedCollections();

      await _saveCurrentListsToCache();

      notifyListeners();
      return null;
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        return 'غير مصرح. سجّل دخول من جديد.';
      }

      if (_isNoInternetError(e)) return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';

      if (_isServerError(msg.toLowerCase())) {
        return 'حدث خطأ في الخادم. يرجى المحاولة مرة أخرى لاحقًا';
      }

      return 'تعذّر إنشاء المجموعة. يرجى المحاولة مرة أخرى';
    }
  }

  Future<String?> updateCollection(
    String id, {
    String? collectionName,
    String? collectionDescription,
  }) async {
    final name = collectionName?.trim();
    final desc = collectionDescription?.trim();

    if (name != null) {
      final err = _validateTitle(name);
      if (err != null) return err;
    }

    if (desc != null) {
      final err = _validateDesc(desc);
      if (err != null) return err;
    }

    try {
      final res = await _api.updateCollection(
        id,
        collectionName: name,
        collectionDescription: desc,
      );

      final raw = (res['collection'] is Map)
          ? Map<String, dynamic>.from(res['collection'])
          : res;

      final updated = SharedCollectionUiModel.fromJson(raw);

      _replaceInList(_owned, updated);
      _replaceInList(_joined, updated);

      _sortOwnedCollections();
      _sortJoinedCollections();

      await _saveCurrentListsToCache();

      notifyListeners();
      return null;
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        return 'غير مصرح. سجّل دخول من جديد.';
      }

      if (_isNoInternetError(e)) return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';

      return 'تعذّر تعديل المجموعة. يرجى المحاولة مرة أخرى';
    }
  }

  Future<String?> deleteCollection(String id) async {
    try {
      await _api.deleteCollection(id);

      _owned.removeWhere((c) => c.id == id);
      _joined.removeWhere((c) => c.id == id);

      await _saveCurrentListsToCache();

      notifyListeners();
      return null;
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        return 'غير مصرح. سجّل دخول من جديد.';
      }

      if (_isNoInternetError(e)) return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';

      return 'تعذّر حذف المجموعة. يرجى المحاولة مرة أخرى';
    }
  }

  Future<String?> leaveCollection(String id) async {
    try {
      await _api.leaveCollection(id);

      _joined.removeWhere((c) => c.id == id);

      await _saveCurrentListsToCache();

      notifyListeners();
      return null;
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('HTTP 401')) {
        await _tokenStorage.clearToken();
        return 'غير مصرح. سجّل دخول من جديد.';
      }

      if (_isNoInternetError(e)) return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';

      return 'تعذّر مغادرة المجموعة. يرجى المحاولة مرة أخرى';
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  void _replaceInList(
    List<SharedCollectionUiModel> list,
    SharedCollectionUiModel next,
  ) {
    final i = list.indexWhere((x) => x.id == next.id);
    if (i == -1) return;

    final prev = list[i];

    list[i] = prev.copyWith(
      collectionName: next.collectionName.isNotEmpty
          ? next.collectionName
          : prev.collectionName,
      collectionDescription: next.collectionDescription.isNotEmpty
          ? next.collectionDescription
          : prev.collectionDescription,
      numOfViewers: next.numOfViewers ?? prev.numOfViewers,
      ownerUsername: next.ownerUsername ?? prev.ownerUsername,
      kind: prev.kind,
    );
  }

  static const int titleMax = 40;
  static const int descMax = 90;

  String? _validateTitle(String input) {
    final value = input.trim();

    if (value.isEmpty) return 'اسم المجموعة مطلوب';
    if (value.length < 3) {
      return 'اسم المجموعة ينبغي أن يحتوي على 3 أحرف على الأقل';
    }
    if (value.length > titleMax) return 'الحد الأقصى $titleMax حرف';

    final allowed = RegExp(r'^[\u0600-\u06FFa-zA-Z0-9\s\-_()]+$');

    if (!allowed.hasMatch(value)) {
      return 'مسموح فقط: حروف/أرقام/مسافة و - _ ( )';
    }

    if (RegExp(r'\s{2,}').hasMatch(value)) {
      return 'لا تترك مسافات كثيرة بين الكلمات';
    }

    return null;
  }

  String? _validateDesc(String input) {
    final value = input.trim();

    if (value.isEmpty) return 'وصف المجموعة مطلوب';
    if (value.length < 10) return 'الوصف ينبغي أن يحتوي على 10 أحرف على الأقل';
    if (value.length > descMax) return 'الحد الأقصى $descMax حرف';

    return null;
  }
}

class CreateCollectionViewModel extends ChangeNotifier {
  static const int titleMax = 40;
  static const int descMax = 90;

  bool _submitting = false;
  bool get submitting => _submitting;

  String _collectionName = '';
  String _collectionDescription = '';
  bool _titleTouched = false;
  bool _descTouched = false;

  String get collectionName => _collectionName;
  String get collectionDescription => _collectionDescription;
  int get titleLen => _collectionName.trim().length;
  int get descLen => _collectionDescription.trim().length;
  bool get isTitleMaxed => titleLen >= titleMax;
  bool get isDescMaxed => descLen >= descMax;

  String? get titleError =>
      _titleTouched ? _validateTitle(_collectionName) : null;
  String? get descError =>
      _descTouched ? _validateDesc(_collectionDescription) : null;

  String? get titleHelper {
    if (!_titleTouched) return null;
    if (titleError != null) return titleError;
    if (isTitleMaxed) return 'وصلت الحد الأقصى لاسم المجموعة';
    return null;
  }

  String? get descHelper {
    if (!_descTouched) return null;
    if (descError != null) return descError;
    if (isDescMaxed) return 'وصلت الحد الأقصى للوصف';
    return null;
  }

  bool get canSubmit =>
      _validateTitle(_collectionName) == null &&
      _validateDesc(_collectionDescription) == null;

  void onTitleChanged(String value) {
    _titleTouched = true;

    if (_collectionName == value) return;

    _collectionName = value;
    notifyListeners();
  }

  void onDescChanged(String value) {
    _descTouched = true;

    if (_collectionDescription == value) return;

    _collectionDescription = value;
    notifyListeners();
  }

  void markAllTouched() {
    final changed = !_titleTouched || !_descTouched;

    _titleTouched = true;
    _descTouched = true;

    if (changed) notifyListeners();
  }

  Future<void> submit({
    required SharedCollectionsViewModel mainVm,
    required VoidCallback onSuccess,
    required void Function(String message) onError,
  }) async {
    if (_submitting) return;

    _submitting = true;
    notifyListeners();

    try {
      markAllTouched();

      if (!canSubmit) {
        onError('تأكد من تعبئة الحقول بشكل صحيح');
        return;
      }

      final err = await mainVm.createCollection(
        collectionName: _collectionName,
        collectionDescription: _collectionDescription,
      );

      if (err != null) {
        onError(err);
        return;
      }

      onSuccess();
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  String? _validateTitle(String input) {
    final value = input.trim();

    if (value.isEmpty) return 'اسم المجموعة مطلوب';
    if (value.length < 3) {
      return 'اسم المجموعة ينبغي أن يحتوي على 3 أحرف على الأقل';
    }
    if (value.length > titleMax) return 'الحد الأقصى $titleMax حرف';

    final allowed = RegExp(r'^[\u0600-\u06FFa-zA-Z0-9\s\-_()]+$');

    if (!allowed.hasMatch(value)) {
      return 'مسموح فقط: حروف/أرقام/مسافة و - _ ( )';
    }

    if (RegExp(r'\s{2,}').hasMatch(value)) {
      return 'لا تترك مسافات كثيرة بين الكلمات';
    }

    return null;
  }

  String? _validateDesc(String input) {
    final value = input.trim();

    if (value.isEmpty) return 'وصف المجموعة مطلوب';
    if (value.length < 10) return 'الوصف ينبغي أن يحتوي على 10 أحرف على الأقل';
    if (value.length > descMax) return 'الحد الأقصى $descMax حرف';

    return null;
  }
}
