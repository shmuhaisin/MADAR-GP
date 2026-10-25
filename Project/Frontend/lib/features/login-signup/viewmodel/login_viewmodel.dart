import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../model/auth_model.dart';
import '../../../core/api/auth_api.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/api/api_client.dart';

class LoginViewModel extends ChangeNotifier {
  final ApiClient _client = ApiClient();
  late final AuthApi _authApi = AuthApi(_client);
  final TokenStorage _tokenStorage = TokenStorage();

  String usernameOrEmail = '';
  String password = '';

  bool obscure = true;
  bool loading = false;

  String? userError;
  String? passError;
  String? apiError;

  void setUser(String value) {
    usernameOrEmail = value;
    apiError = null;

    userError = _validateIdentifier(value, showRequired: false);
    notifyListeners();
  }

  void setPassword(String value) {
    password = value;
    apiError = null;

    passError = _validatePassword(value, showRequired: false);
    notifyListeners();
  }

  void toggleObscure() {
    obscure = !obscure;
    notifyListeners();
  }

  bool _looksLikeEmail(String value) {
    return value.contains('@');
  }

  bool _isEmailValid(String value) {
    final trimmed = value.trim();

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed)) {
      return false;
    }

    if (trimmed.contains('..')) return false;
    if (trimmed.startsWith('.') || trimmed.endsWith('.')) return false;
    if (trimmed.contains('@.') || trimmed.contains('.@')) return false;

    return true;
  }

  String? _validateIdentifier(String value, {required bool showRequired}) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return showRequired ? 'هذا الحقل مطلوب' : null;
    }

    if (_looksLikeEmail(trimmed) && !_isEmailValid(trimmed)) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }

    return null;
  }

  String? _validatePassword(String value, {required bool showRequired}) {
    if (value.isEmpty) {
      return showRequired ? 'كلمة المرور مطلوبة' : null;
    }

    return null;
  }

  bool validateAll() {
    userError = _validateIdentifier(usernameOrEmail, showRequired: true);
    passError = _validatePassword(password, showRequired: true);

    notifyListeners();

    return userError == null && passError == null;
  }

  bool get canSubmit {
    if (loading) return false;
    if (usernameOrEmail.trim().isEmpty) return false;
    if (password.isEmpty) return false;

    final trimmed = usernameOrEmail.trim();

    if (_looksLikeEmail(trimmed) && !_isEmailValid(trimmed)) {
      return false;
    }

    return true;
  }

  LoginModel buildRequest() {
    return LoginModel(
      identifier: usernameOrEmail.trim(),
      password: password,
    );
  }

  bool _isInvalidCredentialsError(String message) {
    return message.contains('invalid credentials') ||
        message.contains('unauthorized') ||
        message.contains('401');
  }

  bool _isNoInternetError(Object error) {
    if (error is DioException) {
      if (error.error is SocketException) {
        return true;
      }

      final raw = '${error.error ?? ''} ${error.message ?? ''}'.toLowerCase();

      if (raw.contains('failed host lookup') ||
          raw.contains('network is unreachable') ||
          raw.contains('no address associated with hostname') ||
          raw.contains('temporary failure in name resolution')) {
        return true;
      }
    }

    final raw = error.toString().toLowerCase();

    return raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('no address associated with hostname') ||
        raw.contains('temporary failure in name resolution');
  }

  bool _isServerOrAppError(String message) {
    return message.contains('500') ||
        message.contains('502') ||
        message.contains('503') ||
        message.contains('504') ||
        message.contains('internal server error') ||
        message.contains('server error') ||
        message.contains('bad response');
  }

  String _mapLoginErrorMessage(Object error) {
    final message = ApiClient.formatDioError(error).toLowerCase();

    if (_isInvalidCredentialsError(message)) {
      return 'اسم المستخدم أو كلمة المرور غير صحيحة';
    }

    if (_isNoInternetError(error)) {
      return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';
    }

    if (_isServerOrAppError(message)) {
      return 'حدث خطأ في الخادم أو في التطبيق. يرجى المحاولة مرة أخرى لاحقًا';
    }

    return 'حدث خطأ أثناء تسجيل الدخول. يرجى المحاولة مرة أخرى';
  }

  Future<void> _clearLocalSessionBeforeNewLogin() async {
    await _tokenStorage.clearToken();

    if (Hive.isBoxOpen('news_cache')) {
      await Hive.box('news_cache').clear();
    }

    if (Hive.isBoxOpen('collections_cache')) {
      await Hive.box('collections_cache').clear();
    }
  }

  Future<bool> submit() async {
    apiError = null;

    if (!validateAll()) return false;

    loading = true;
    notifyListeners();

    try {
      final request = buildRequest();

      debugPrint('LOGIN REQUEST => ${request.toJson()}');

      // Clear old account data before logging into a new account.
      await _clearLocalSessionBeforeNewLogin();

      final result = await _authApi.signin(request);

      if (result.token.isEmpty) {
        throw Exception('Missing token from backend');
      }

      await _tokenStorage.saveToken(result.token);

      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();

        if (fcmToken != null && fcmToken.isNotEmpty) {
          await _authApi.saveFcmToken(fcmToken);
        }
      } catch (_) {
        // Do not block login if FCM token update fails.
      }

      loading = false;
      notifyListeners();

      return true;
    } catch (error) {
      loading = false;
      apiError = _mapLoginErrorMessage(error);

      notifyListeners();

      return false;
    }
  }

  void clear() {
    usernameOrEmail = '';
    password = '';
    obscure = true;
    loading = false;

    userError = null;
    passError = null;
    apiError = null;

    notifyListeners();
  }
}