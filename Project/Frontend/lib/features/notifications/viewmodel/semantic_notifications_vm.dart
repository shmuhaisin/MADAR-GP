import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/notifications_api.dart';
import '../../../core/storage/token_storage.dart';
import '../../profile/model/profile_model.dart';

class SemanticNotificationsVM extends ChangeNotifier {
  final ApiClient _client;
  late final NotificationsApi _api;
  final TokenStorage _tokenStorage = TokenStorage();

  static const String _cacheBoxName = 'semantic_notifications_cache';
  static const String _cacheKey = 'semantic_notifications';

  SemanticNotificationsVM({ApiClient? api}) : _client = api ?? ApiClient() {
    _api = NotificationsApi(_client);
  }

  bool isLoading = false;
  bool isOffline = false;
  String? error;

  List<Interest> interests = [];
  final Map<Interest, List<String>> grouped = {};

  bool get canModify => !isOffline;

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 3),
      );

      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveCache() async {
    final box = Hive.box(_cacheBoxName);

    final data = grouped.map(
      (interest, keywords) => MapEntry(
        interest.key,
        List<String>.from(keywords),
      ),
    );

    await box.put(_cacheKey, data);
  }

  void _loadCache() {
    final box = Hive.box(_cacheBoxName);
    final cached = box.get(_cacheKey);

    if (cached == null) return;

    final map = Map<String, dynamic>.from(cached as Map);

    grouped.clear();
    interests = [];

    for (final entry in map.entries) {
      final interest = InterestX.fromKey(entry.key);
      if (interest == null) continue;

      final keywords = (entry.value as List?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          [];

      if (keywords.isEmpty) continue;

      interests.add(interest);
      grouped[interest] = keywords;
    }
  }

  String _cleanError(Object e) {
    final msg = ApiClient.formatDioError(e);
    final lower = msg.toLowerCase();

    if (lower.contains('http 401') || lower.contains('unauthorized')) {
      return 'انتهت الجلسة. سجّلي الدخول مرة أخرى.';
    }

    if (lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('timeout') ||
        lower.contains('failed host lookup')) {
      return 'لا يوجد اتصال بالإنترنت';
    }

    if (lower.contains('409') ||
        lower.contains('conflict') ||
        lower.contains('already exists') ||
        msg.contains('موجود')) {
      return 'هذه الكلمة الدلالية موجودة مسبقًا';
    }

    if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504') ||
        lower.contains('server error')) {
      return 'حدث خطأ في الخادم. حاولي مرة أخرى لاحقًا.';
    }

    return 'حدث خطأ أثناء تنفيذ العملية';
  }

  void clear() {
    isLoading = false;
    isOffline = false;
    error = null;
    interests = [];
    grouped.clear();
    notifyListeners();
  }

  Future<void> loadSemanticNotifications({bool silent = false}) async {
    if (!silent) {
      _loadCache();
      isLoading = grouped.isEmpty;
      error = null;
      notifyListeners();
    }

    final online = await _hasInternet();

    if (!online) {
      _loadCache();

      isOffline = true;
      error = 'أنت غير متصل بالإنترنت. يتم عرض آخر كلمات دلالية محفوظة.';
      isLoading = false;

      notifyListeners();
      return;
    }

    try {
      isOffline = false;
      error = null;

      if (!silent && grouped.isEmpty) {
        isLoading = true;
        notifyListeners();
      }

      final res = await _api.getSemanticNotifications(auth: true);
      final raw = (res['semanticNotifications'] as Map?) ?? {};

      grouped.clear();
      interests = [];

      for (final entry in raw.entries) {
        final interestKey = entry.key.toString();

        final keywords = (entry.value as List?)
                ?.map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList() ??
            [];

        final interest = InterestX.fromKey(interestKey);
        if (interest == null) continue;
        if (keywords.isEmpty) continue;

        interests.add(interest);
        grouped[interest] = keywords;
      }

      await _saveCache();
    } catch (e) {
      _loadCache();

      final clean = _cleanError(e);

      if (clean.contains('انتهت الجلسة')) {
        await _tokenStorage.clearToken();
        grouped.clear();
        interests = [];
      }

      error = clean;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> add({
    required Interest interest,
    required String keyword,
  }) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return false;

    final online = await _hasInternet();

    if (!online) {
      isOffline = true;
      error = 'لا يمكن إضافة كلمة دلالية بدون اتصال بالإنترنت';
      notifyListeners();
      return false;
    }

    try {
      error = null;
      isOffline = false;
      notifyListeners();

      await _api.createSemanticNotification(
        interest: interest.key,
        keyword: trimmed,
      );

      grouped.putIfAbsent(interest, () => <String>[]);

      if (!grouped[interest]!.contains(trimmed)) {
        grouped[interest]!.add(trimmed);
      }

      if (!interests.contains(interest)) {
        interests.add(interest);
      }

      await _saveCache();

      notifyListeners();
      return true;
    } catch (e) {
      final clean = _cleanError(e);

      if (clean.contains('انتهت الجلسة')) {
        await _tokenStorage.clearToken();
        clear();
      }

      error = clean;
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete({
    required Interest interest,
    required String keyword,
  }) async {
    final online = await _hasInternet();

    if (!online) {
      isOffline = true;
      error = 'لا يمكن حذف كلمة دلالية بدون اتصال بالإنترنت';
      notifyListeners();
      return false;
    }

    try {
      error = null;
      isOffline = false;
      notifyListeners();

      await _api.deleteSemanticNotification(
        interest: interest.key,
        keyword: keyword,
      );

      grouped[interest]?.remove(keyword);

      if ((grouped[interest] ?? []).isEmpty) {
        grouped.remove(interest);
        interests.remove(interest);
      }

      await _saveCache();

      notifyListeners();
      return true;
    } catch (e) {
      final clean = _cleanError(e);

      if (clean.contains('انتهت الجلسة')) {
        await _tokenStorage.clearToken();
        clear();
      }

      error = clean;
      notifyListeners();
      return false;
    }
  }
}