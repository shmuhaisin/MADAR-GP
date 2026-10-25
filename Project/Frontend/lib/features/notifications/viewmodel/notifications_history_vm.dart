import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/notifications_api.dart';
import '../../../core/storage/token_storage.dart';
import '../model/notifications_model.dart';

enum HistoryFilter {
  all,
  joinReq,
  reqReply,
  keyword,
}

class NotificationHistoryVM extends ChangeNotifier {
  final ApiClient _client;
  late final NotificationsApi _api;
  final TokenStorage _tokenStorage = TokenStorage();

  NotificationHistoryVM({ApiClient? api}) : _client = api ?? ApiClient() {
    _api = NotificationsApi(_client);
  }

  HistoryFilter filter = HistoryFilter.all;
  bool isLoading = false;
  bool isOffline = false;
  String? error;

  Set<String> selectedKeywords = {};

  final List<NotificationModel> _all = [];
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  List<NotificationModel> get allNotifications => List.unmodifiable(_all);

  List<NotificationModel> get items {
    return _all.where((n) {
      switch (filter) {
        case HistoryFilter.all:
          return true;

        case HistoryFilter.joinReq:
          return n.type == NotifType.joinReq;

        case HistoryFilter.reqReply:
          return n.type == NotifType.reqReply;

        case HistoryFilter.keyword:
          if (n.type != NotifType.semantic) return false;
          final kw = n.keyword ?? '';
          return selectedKeywords.contains(kw);
      }
    }).toList();
  }

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

    if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504') ||
        lower.contains('server error')) {
      return 'حدث خطأ في الخادم. حاولي مرة أخرى لاحقًا.';
    }

    return 'حدث خطأ أثناء تحميل الإشعارات';
  }

  void clear() {
    filter = HistoryFilter.all;
    isLoading = false;
    isOffline = false;
    error = null;

    selectedKeywords.clear();

    _all.clear();
    _unreadCount = 0;

    notifyListeners();
  }

  Future<void> loadNotifications({bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      error = null;
      notifyListeners();
    }

    final online = await _hasInternet();

    if (!online) {
      isOffline = true;
      error = 'لا يوجد اتصال بالإنترنت';
      if (!silent) {
        isLoading = false;
      }
      notifyListeners();
      return;
    }

    try {
      isOffline = false;
      error = null;

      final res = await _api.getNotifications(auth: true);
      final raw = (res['notifications'] as List?) ?? [];

      _all
        ..clear()
        ..addAll(
          raw.map(
            (e) => NotificationModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          ),
        );

      final countRes = await _api.getUnreadCount(auth: true);
      _unreadCount = (countRes['unreadCount'] as num?)?.toInt() ?? 0;
    } catch (e) {
      final clean = _cleanError(e);

      if (clean.contains('انتهت الجلسة')) {
        await _tokenStorage.clearToken();
        _all.clear();
        _unreadCount = 0;
      }

      error = clean;
    } finally {
      if (!silent) {
        isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<bool> markAllAsRead() async {
    final online = await _hasInternet();

    if (!online) {
      isOffline = true;
      error = 'لا يوجد اتصال بالإنترنت';
      notifyListeners();
      return false;
    }

    try {
      error = null;
      isOffline = false;

      await _api.markAllAsRead(auth: true);

      for (final n in _all) {
        n.isRead = true;
      }

      _unreadCount = 0;
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

  void showAll() {
    filter = HistoryFilter.all;
    selectedKeywords.clear();
    notifyListeners();
  }

  void setJoinReq() {
    filter = HistoryFilter.joinReq;
    selectedKeywords.clear();
    notifyListeners();
  }

  void setReqReply() {
    filter = HistoryFilter.reqReply;
    selectedKeywords.clear();
    notifyListeners();
  }

  void applyKeywords(Set<String> keywords) {
    if (keywords.isEmpty) {
      showAll();
      return;
    }

    selectedKeywords = keywords;
    filter = HistoryFilter.keyword;

    notifyListeners();
  }
}