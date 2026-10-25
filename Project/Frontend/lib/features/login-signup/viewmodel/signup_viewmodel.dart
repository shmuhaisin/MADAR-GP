import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/auth_api.dart';
import '../model/auth_model.dart';

/// ViewModel responsible for:
/// 1) managing signup form state,
/// 2) validating all signup fields,
/// 3) building the signup request model,
/// 4) sending the signup OTP request,
/// 5) mapping backend and connectivity failures into user-friendly messages.
class SignUpViewModel extends ChangeNotifier {
  /// Shared API client used for backend communication.
  final ApiClient _client;

  /// Authentication API wrapper built on top of the shared API client.
  late final AuthApi _authApi;

  SignUpViewModel({ApiClient? client}) : _client = client ?? ApiClient() {
    _authApi = AuthApi(_client);
  }

  // ========================= Form values =========================

  String username = '';
  String email = '';

  String countryDialCode = '+966';

  String phoneDigits = '';
  String password = '';

  DateTime? birthdate;

  final Set<Interest> interests = {};

  // ========================= UI state =========================

  bool loading = false;
  bool obscure = true;

  // ========================= Field / request errors =========================

  String? nameError;
  String? emailError;
  String? countryCodeError;
  String? phoneError;
  String? passError;
  String? dobError;
  String? interestsError;
  String? apiError;

  // ========================= Setters =========================

  void setName(String value) {
    username = value;
    apiError = null;

    nameError = _validateUsername(value, showRequired: false);
    notifyListeners();
  }

  void setEmail(String value) {
    email = value;
    apiError = null;

    emailError = _validateEmail(value, showRequired: false);
    notifyListeners();
  }

  void setCountryDialCode(String code) {
    countryDialCode = _normalizeCountryCode(code);
    apiError = null;

    countryCodeError = _validateCountryCode();
    phoneError = _validatePhone(phoneDigits, showRequired: false);

    notifyListeners();
  }

  void setPhoneDigits(String value) {
    phoneDigits = _digitsOnly(_normalizeDigits(value));
    apiError = null;

    countryCodeError = _validateCountryCode();
    phoneError = _validatePhone(phoneDigits, showRequired: false);

    notifyListeners();
  }

  void setPassword(String value) {
    password = value;
    apiError = null;

    passError = _validatePassword(value, showRequired: false);
    notifyListeners();
  }

  /// Updates date of birth.
  /// User must be older than 16 years old.
  void setDob(DateTime date) {
    birthdate = date;
    dobError = _validateDob(showRequired: true);
    apiError = null;
    notifyListeners();
  }

  void toggleObscure() {
    obscure = !obscure;
    notifyListeners();
  }

  void toggleInterest(Interest tag) {
    apiError = null;

    if (interests.contains(tag)) {
      interests.remove(tag);
    } else {
      interests.add(tag);
    }

    interestsError = _validateInterests(showRequired: false);
    notifyListeners();
  }

  // ========================= Derived values =========================

  String get phoneNumberFull {
    var local = _digitsOnly(_normalizeDigits(phoneDigits));
    local = local.replaceFirst(RegExp(r'^0+'), '');
    return '${_normalizeCountryCode(countryDialCode)}$local';
  }

  bool get canSubmit {
    if (loading) return false;
    if (username.trim().isEmpty) return false;
    if (email.trim().isEmpty) return false;
    if (phoneDigits.isEmpty) return false;
    if (password.isEmpty) return false;
    if (birthdate == null) return false;
    if (interests.isEmpty) return false;

    if (_validateUsername(username, showRequired: true) != null) return false;
    if (_validateEmail(email, showRequired: true) != null) return false;
    if (_validateCountryCode() != null) return false;
    if (_validatePhone(phoneDigits, showRequired: true) != null) return false;
    if (_validatePassword(password, showRequired: true) != null) return false;
    if (_validateDob(showRequired: true) != null) return false;

    return true;
  }

  // ========================= Validation helpers =========================

  String? _validateUsername(String value, {required bool showRequired}) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return showRequired ? 'اسم المستخدم مطلوب' : null;
    }

    if (trimmed.length < 3) {
      return 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل';
    }

    if (trimmed.length > 8) {
      return 'اسم المستخدم يجب ألا يتجاوز 8 أحرف';
    }

    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmed)) {
      return 'اسم المستخدم يجب أن يحتوي على حروف إنجليزية وأرقام فقط';
    }

    return null;
  }

  String? _validateEmail(String value, {required bool showRequired}) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return showRequired ? 'البريد الإلكتروني مطلوب' : null;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed)) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }

    if (trimmed.contains('..')) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }

    if (trimmed.startsWith('.') || trimmed.endsWith('.')) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }

    if (trimmed.contains('@.') || trimmed.contains('.@')) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }

    return null;
  }

  String? _validateCountryCode() {
    final normalized = _normalizeCountryCode(countryDialCode);

    if (!RegExp(r'^\+\d{1,4}$').hasMatch(normalized)) {
      return 'رمز الدولة غير صحيح';
    }

    return null;
  }

  String? _validatePhone(String value, {required bool showRequired}) {
    final digits = _digitsOnly(_normalizeDigits(value));
    final isSaudi = _normalizeCountryCode(countryDialCode) == '+966';

    if (digits.isEmpty) {
      return showRequired ? 'رقم الجوال مطلوب' : null;
    }

    if (isSaudi) {
      final validSaudi =
          (digits.length == 9 && digits.startsWith('5')) ||
          (digits.length == 10 && digits.startsWith('05'));

      if (!validSaudi) {
        return 'رقم الجوال غير صحيح (مثال: 5XXXXXXXX أو 05XXXXXXXX)';
      }

      return null;
    }

    if (digits.length < 6 || digits.length > 14) {
      return 'رقم الهاتف غير صحيح';
    }

    return null;
  }

  String? _validatePassword(String value, {required bool showRequired}) {
    if (value.isEmpty) {
      return showRequired ? 'كلمة المرور مطلوبة' : null;
    }

    if (value.length < 6) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'كلمة المرور يجب أن تحتوي على حرف كبير واحد على الأقل';
    }

    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'كلمة المرور يجب أن تحتوي على رقم واحد على الأقل';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]').hasMatch(value)) {
      return 'كلمة المرور يجب أن تحتوي على رمز خاص واحد على الأقل';
    }

    return null;
  }

  /// Validates date of birth.
  /// User must be older than 16 years old.
  String? _validateDob({required bool showRequired}) {
    if (birthdate == null) {
      return showRequired ? 'تاريخ الميلاد مطلوب' : null;
    }

    final today = DateTime.now();

    int age = today.year - birthdate!.year;

    final hasBirthdayPassedThisYear =
        today.month > birthdate!.month ||
        (today.month == birthdate!.month && today.day >= birthdate!.day);

    if (!hasBirthdayPassedThisYear) {
      age--;
    }

    // Older than 16 = 17 years old or more.
    if (age < 17) {
      return 'يجب أن يكون عمرك أكبر من 16 سنة';
    }

    return null;
  }

  String? _validateInterests({required bool showRequired}) {
    if (interests.isEmpty) {
      return showRequired ? 'يجب اختيار اهتمام واحد على الأقل' : null;
    }

    return null;
  }

  bool validateAll() {
    apiError = null;

    nameError = _validateUsername(username, showRequired: true);
    emailError = _validateEmail(email, showRequired: true);
    countryCodeError = _validateCountryCode();
    phoneError = _validatePhone(phoneDigits, showRequired: true);
    passError = _validatePassword(password, showRequired: true);
    dobError = _validateDob(showRequired: true);
    interestsError = _validateInterests(showRequired: true);

    notifyListeners();

    return nameError == null &&
        emailError == null &&
        countryCodeError == null &&
        phoneError == null &&
        passError == null &&
        dobError == null &&
        interestsError == null;
  }

  // ========================= Formatting helpers =========================

  String _normalizeDigits(String input) {
    const arabicToEnglish = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };

    return input.split('').map((ch) => arabicToEnglish[ch] ?? ch).join();
  }

  String _digitsOnly(String input) {
    return input.replaceAll(RegExp(r'\D'), '');
  }

  String _normalizeCountryCode(String code) {
    final digits = _digitsOnly(_normalizeDigits(code));
    return digits.isEmpty ? '' : '+$digits';
  }

  String _fmtDob(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  // ========================= Request building =========================

  SignUpRequestModel buildRequest() {
    final d = birthdate!;

    return SignUpRequestModel(
      username: username.trim(),
      email: email.trim(),
      password: password,
      phoneNumber: phoneNumberFull,
      birthdate: _fmtDob(d),
      interests: interests.toList(),
    );
  }

  // ========================= Error classification =========================

  bool _isDuplicateEmailError(String message) {
    return message.contains('email already exists') ||
        message.contains('email already registered') ||
        message.contains('duplicate email');
  }

  bool _isDuplicateUsernameError(String message) {
    return message.contains('username already exists') ||
        message.contains('username already registered') ||
        message.contains('duplicate username');
  }

  bool _isDuplicatePhoneError(String message) {
    return (message.contains('phone') &&
            (message.contains('already exists') ||
                message.contains('already registered') ||
                message.contains('duplicate'))) ||
        message.contains('phone already exists') ||
        message.contains('phone already registered') ||
        message.contains('duplicate phone');
  }

  bool _isDuplicateUserError(String message) {
    return message.contains('user already exists') ||
        message.contains('user already registered');
  }

  bool _isBadRequestError(String message) {
    return message.contains('bad request') || message.contains('400');
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

  bool _applyBackendFieldErrors(String message) {
    if (_isDuplicateEmailError(message)) {
      emailError = 'هذا البريد الإلكتروني مستخدم بالفعل';
      apiError = 'هذا البريد الإلكتروني مستخدم بالفعل';
      return true;
    }

    if (_isDuplicateUsernameError(message)) {
      nameError = 'اسم المستخدم مستخدم بالفعل';
      apiError = 'اسم المستخدم مستخدم بالفعل';
      return true;
    }

    if (_isDuplicatePhoneError(message)) {
      phoneError = 'رقم الجوال مستخدم بالفعل';
      apiError = 'رقم الجوال مستخدم بالفعل';
      return true;
    }

    if (_isDuplicateUserError(message)) {
      apiError =
          'المستخدم موجود بالفعل. يرجى استخدام بريد إلكتروني أو رقم جوال آخر';
      return true;
    }

    return false;
  }

  String _mapSignUpErrorMessage(Object error) {
    final message = ApiClient.formatDioError(error).toLowerCase();

    if (_isNoInternetError(error)) {
      return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';
    }

    if (_isBadRequestError(message)) {
      return 'خطأ في البيانات المدخلة. يرجى التحقق من المعلومات';
    }

    if (_isServerOrAppError(message)) {
      return 'حدث خطأ في الخادم أو في التطبيق. يرجى المحاولة مرة أخرى لاحقًا';
    }

    return 'حدث خطأ أثناء إنشاء الحساب. يرجى المحاولة مرة أخرى';
  }

  // ========================= Submission =========================

  Future<bool> submitStart() async {
    if (!validateAll()) return false;

    loading = true;
    apiError = null;
    notifyListeners();

    try {
      final req = buildRequest();
      await _authApi.signupRequestOtp(req);

      loading = false;
      notifyListeners();
      return true;
    } catch (error) {
      loading = false;

      final message = ApiClient.formatDioError(error).toLowerCase();

      if (!_applyBackendFieldErrors(message)) {
        apiError = _mapSignUpErrorMessage(error);
      }

      notifyListeners();
      return false;
    }
  }

  void clear() {
    username = '';
    email = '';
    countryDialCode = '+966';
    phoneDigits = '';
    password = '';
    birthdate = null;
    interests.clear();

    loading = false;
    obscure = true;

    nameError = null;
    emailError = null;
    countryCodeError = null;
    phoneError = null;
    passError = null;
    dobError = null;
    interestsError = null;
    apiError = null;

    notifyListeners();
  }
}