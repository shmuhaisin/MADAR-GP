import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/profile_api.dart';
import '../../../core/storage/token_storage.dart';
import '../model/profile_model.dart';

class ProfileViewModel extends ChangeNotifier {
  final ApiClient _client;
  late final ProfileApi _profileApi;
  final TokenStorage _tokenStorage = TokenStorage();

  ProfileViewModel({ApiClient? api}) : _client = api ?? ApiClient() {
    _profileApi = ProfileApi(_client);
  }

  ProfileModel? _profile;
  ProfileModel? get profile => _profile;

  bool loading = false;
  bool isEditing = false;

  String? error;
  String? apiError;

  String? usernameError;
  String? emailError;
  String? birthdateError;
  String? phoneError;
  String? interestsError;

  ProfileModel? _cachedBeforeEdit;

  List<Interest> get allInterests => Interest.values;

  Set<Interest> get selectedInterests =>
      (_profile?.interests ?? const <Interest>[]).toSet();

  int get interestsCount => selectedInterests.length;

  void _resetState() {
    _profile = null;
    _cachedBeforeEdit = null;

    loading = false;
    isEditing = false;

    error = null;
    apiError = null;

    usernameError = null;
    emailError = null;
    birthdateError = null;
    phoneError = null;
    interestsError = null;

    notifyListeners();
  }

  Future<void> _clearLocalSession() async {
    await _tokenStorage.clearToken();

    if (Hive.isBoxOpen('news_cache')) {
      await Hive.box('news_cache').clear();
    }

    if (Hive.isBoxOpen('collections_cache')) {
      await Hive.box('collections_cache').clear();
    }

    if (Hive.isBoxOpen('profile_cache')) {
      await Hive.box('profile_cache').clear();
    }

    _resetState();
  }

  Future<void> _saveProfileToCache(Map<String, dynamic> json) async {
    if (!Hive.isBoxOpen('profile_cache')) return;

    final box = Hive.box('profile_cache');

    await box.put('profile', json);
    await box.put('profile_cached_at', DateTime.now().toIso8601String());
  }

  ProfileModel? _loadProfileFromCache() {
    if (!Hive.isBoxOpen('profile_cache')) return null;

    final box = Hive.box('profile_cache');
    final raw = box.get('profile');

    if (raw == null) return null;

    try {
      final json = Map<String, dynamic>.from(raw as Map);
      return ProfileModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadProfile() async {
    loading = true;
    error = null;
    apiError = null;
    notifyListeners();

    try {
      final res = await _profileApi.getMyProfile();

      final json = (res['user'] is Map)
          ? Map<String, dynamic>.from(res['user'])
          : Map<String, dynamic>.from(res);

      _profile = ProfileModel.fromJson(json);

      await _saveProfileToCache(json);

      error = null;
      apiError = null;
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('HTTP 401') || msg.toLowerCase().contains('http 401')) {
        await _clearLocalSession();
        error = 'غير مصرح. سجّل دخول من جديد.';
      } else {
        final cachedProfile = _loadProfileFromCache();

        if (cachedProfile != null) {
          _profile = cachedProfile;
          error = null;
          apiError = 'أنت غير متصل بالإنترنت، يتم عرض آخر بيانات محفوظة';
        } else {
          error =
              'تعذر تحميل الملف الشخصي. لا يوجد اتصال بالإنترنت ولا توجد بيانات محفوظة';
        }
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void startEdit() {
    if (_profile == null) return;

    _cachedBeforeEdit = _profile?.copyWith(
      username: _profile!.username,
      email: _profile!.email,
      birthdate: _profile!.birthdate,
      phoneNumber: _profile!.phoneNumber,
      interests: List<Interest>.from(_profile!.interests),
    );

    _clearValidationErrors();
    apiError = null;
    isEditing = true;
    notifyListeners();
  }

  void cancelEdit() {
    if (_cachedBeforeEdit != null) {
      _profile = _cachedBeforeEdit;
    }

    _cachedBeforeEdit = null;
    isEditing = false;

    _clearValidationErrors();
    apiError = null;

    notifyListeners();
  }

  void onUsernameChanged(String value) {
    apiError = null;
    usernameError = _validateUsername(value, showRequired: false);
    notifyListeners();
  }

  void onEmailChanged(String value) {
    apiError = null;
    emailError = _validateEmail(value, showRequired: false);
    notifyListeners();
  }

  void onBirthdateChanged(String value) {
    apiError = null;
    birthdateError = _validateBirthdate(value, showRequired: false);
    notifyListeners();
  }

  void onPhoneChanged({
    required String dialCode,
    required String localDigits,
  }) {
    apiError = null;

    final digits = _digitsOnly(_normalizeDigits(localDigits));
    final normalizedDial = _normalizeCountryCode(dialCode);

    phoneError = _validatePhone(
      digits,
      countryDialCode: normalizedDial,
      showRequired: false,
    );

    notifyListeners();
  }

  void clearErrors() {
    error = null;
    apiError = null;
    _clearValidationErrors();
    notifyListeners();
  }

  void applyExternalPhoneError(String message) {
    phoneError = message;
    apiError = null;
    notifyListeners();
  }

  void applyApiError(String message) {
    apiError = message;
    notifyListeners();
  }

  void applyInterestsError(String message) {
    interestsError = message;
    apiError = null;
    notifyListeners();
  }

  void _clearValidationErrors() {
    usernameError = null;
    emailError = null;
    birthdateError = null;
    phoneError = null;
    interestsError = null;
  }

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

  String? _validateBirthdate(String value, {required bool showRequired}) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return showRequired ? 'تاريخ الميلاد مطلوب' : null;
    }

    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      return 'صيغة تاريخ الميلاد غير صحيحة';
    }

    final parsed = DateTime.tryParse(trimmed);

    if (parsed == null) {
      return 'تاريخ الميلاد غير صالح';
    }

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final birthdateOnly = DateTime(parsed.year, parsed.month, parsed.day);

    if (birthdateOnly.isAfter(todayOnly)) {
      return 'تاريخ الميلاد غير صالح';
    }

    int age = todayOnly.year - birthdateOnly.year;

    final hasBirthdayPassedThisYear =
        todayOnly.month > birthdateOnly.month ||
        (todayOnly.month == birthdateOnly.month &&
            todayOnly.day >= birthdateOnly.day);

    if (!hasBirthdayPassedThisYear) {
      age--;
    }

    // Older than 16 = 17 years old or more.
    if (age < 17) {
      return 'يجب أن يكون عمرك أكبر من 16 سنة';
    }

    return null;
  }

  String? _validatePhone(
    String value, {
    required String countryDialCode,
    required bool showRequired,
  }) {
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

  String? _validateInterests({required bool showRequired}) {
    if (selectedInterests.isEmpty) {
      return showRequired ? 'اختر اهتمام واحد على الأقل' : null;
    }

    return null;
  }

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

  String _normalizePhone(String input) {
    final trimmed = input.trim();

    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('+')) {
      final digits = trimmed.substring(1).replaceAll(RegExp(r'\D'), '');
      return digits.isEmpty ? '' : '+$digits';
    }

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? '' : '+$digits';
  }

  String _normalizeForCompare(String value) {
    return value.trim().toLowerCase();
  }

  String _normalizePhoneForCompare(String value) {
    return _normalizePhone(value).replaceAll(RegExp(r'\s+'), '');
  }

  bool validateForSave({
    required String username,
    required String email,
    required String birthdate,
    required String phoneNumber,
  }) {
    _clearValidationErrors();
    apiError = null;

    final normalizedPhone = _normalizePhone(phoneNumber);

    final digits = normalizedPhone.startsWith('+')
        ? normalizedPhone.substring(1)
        : normalizedPhone;

    String dialCode = '+966';
    String localDigits = digits;

    if (normalizedPhone.startsWith('+966')) {
      dialCode = '+966';
      localDigits = digits.substring(3);
    } else if (normalizedPhone.startsWith('+971')) {
      dialCode = '+971';
      localDigits = digits.substring(3);
    } else if (normalizedPhone.startsWith('+20')) {
      dialCode = '+20';
      localDigits = digits.substring(2);
    }

    usernameError = _validateUsername(username, showRequired: true);
    emailError = _validateEmail(email, showRequired: true);
    birthdateError = _validateBirthdate(birthdate, showRequired: true);
    phoneError = _validatePhone(
      localDigits,
      countryDialCode: dialCode,
      showRequired: true,
    );
    interestsError = _validateInterests(showRequired: true);

    notifyListeners();

    return usernameError == null &&
        emailError == null &&
        birthdateError == null &&
        phoneError == null &&
        interestsError == null;
  }

  bool _isGenericDuplicateError(String message) {
    final msg = message.toLowerCase();

    return msg.contains('already exists') ||
        msg.contains('already registered') ||
        msg.contains('duplicate') ||
        msg.contains('duplicate key') ||
        msg.contains('e11000') ||
        msg.contains('user already exists') ||
        msg.contains('user already registered') ||
        msg.contains('account already exists') ||
        msg.contains('conflict') ||
        msg.contains('409');
  }

  bool _isDuplicateEmailError(String message) {
    final msg = message.toLowerCase();

    return msg.contains('email already exists') ||
        msg.contains('email already registered') ||
        msg.contains('duplicate email') ||
        msg.contains('email is already used') ||
        (msg.contains('email') && msg.contains('duplicate')) ||
        (msg.contains('email') && msg.contains('already exists')) ||
        (msg.contains('email') && msg.contains('already registered')) ||
        (msg.contains('email') && msg.contains('used')) ||
        msg.contains('البريد الإلكتروني مستخدم');
  }

  bool _isDuplicateUsernameError(String message) {
    final msg = message.toLowerCase();

    return msg.contains('username already exists') ||
        msg.contains('username already registered') ||
        msg.contains('duplicate username') ||
        msg.contains('username is already used') ||
        msg.contains('name already exists') ||
        msg.contains('duplicate name') ||
        (msg.contains('username') && msg.contains('duplicate')) ||
        (msg.contains('username') && msg.contains('already exists')) ||
        (msg.contains('username') && msg.contains('already registered')) ||
        (msg.contains('username') && msg.contains('used')) ||
        msg.contains('اسم المستخدم مستخدم');
  }

  bool _isDuplicatePhoneError(String message) {
    final msg = message.toLowerCase();

    return msg.contains('phone number already exists') ||
        msg.contains('phone already exists') ||
        msg.contains('phone already registered') ||
        msg.contains('duplicate phone') ||
        msg.contains('phone is already used') ||
        (msg.contains('phone') && msg.contains('duplicate')) ||
        (msg.contains('phone') && msg.contains('already exists')) ||
        (msg.contains('phone') && msg.contains('already registered')) ||
        (msg.contains('phone') && msg.contains('used')) ||
        msg.contains('رقم الجوال مستخدم') ||
        msg.contains('رقم الهاتف مستخدم');
  }

  bool _isInvalidPhoneVerificationToken(String message) {
    final msg = message.toLowerCase();

    return (msg.contains('phonechangeverificationtoken') &&
            msg.contains('invalid')) ||
        (msg.contains('phone change verification token') &&
            msg.contains('invalid')) ||
        (msg.contains('phone change verification token') &&
            msg.contains('expired')) ||
        msg.contains('invalid verification token') ||
        msg.contains('expired verification token');
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
    final msg = message.toLowerCase();

    return msg.contains('500') ||
        msg.contains('502') ||
        msg.contains('503') ||
        msg.contains('504') ||
        msg.contains('internal server error') ||
        msg.contains('server error') ||
        msg.contains('bad response');
  }

  String _mapProfileErrorMessage(Object error) {
    final message = ApiClient.formatDioError(error).toLowerCase();

    if (_isNoInternetError(error)) {
      return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';
    }

    if (_isDuplicateUsernameError(message)) {
      return 'اسم المستخدم مستخدم بالفعل';
    }

    if (_isDuplicateEmailError(message)) {
      return 'هذا البريد الإلكتروني مستخدم بالفعل';
    }

    if (_isDuplicatePhoneError(message)) {
      return 'رقم الجوال مستخدم بالفعل';
    }

    if (_isServerOrAppError(message)) {
      return 'حدث خطأ في الخادم أو في التطبيق. يرجى المحاولة مرة أخرى لاحقًا';
    }

    return 'حدث خطأ أثناء تحديث الملف الشخصي. يرجى المحاولة مرة أخرى';
  }

  Future<String?> saveProfile({
    required String username,
    required String email,
    required String birthdate,
    required String phoneNumber,
    String? phoneChangeVerificationToken,
  }) async {
    final u = username.trim();
    final e = email.trim();
    final b = birthdate.trim();
    final p = _normalizePhone(phoneNumber);

    if (!validateForSave(
      username: u,
      email: e,
      birthdate: b,
      phoneNumber: p,
    )) {
      return usernameError ??
          emailError ??
          birthdateError ??
          phoneError ??
          interestsError ??
          'يرجى التحقق من البيانات المدخلة';
    }

    loading = true;
    apiError = null;
    notifyListeners();

    try {
      final body = {
        'username': u,
        'email': e,
        'birthdate': b,
        'phoneNumber': p,
        if (phoneChangeVerificationToken != null &&
            phoneChangeVerificationToken.trim().isNotEmpty)
          'phoneChangeVerificationToken': phoneChangeVerificationToken.trim(),
      };

      final res = await _profileApi.updateMyProfile(body);

      final json = (res['user'] is Map)
          ? Map<String, dynamic>.from(res['user'])
          : Map<String, dynamic>.from(res);

      if (json.containsKey('username') || json.containsKey('email')) {
        _profile = ProfileModel.fromJson(json);
        await _saveProfileToCache(json);
      } else {
        _profile = _profile?.copyWith(
          username: u,
          email: e,
          birthdate: b,
          phoneNumber: p,
          interests: selectedInterests.toList(),
        );

        if (_profile != null) {
          await _saveProfileToCache(_profile!.toJson());
        }
      }

      _cachedBeforeEdit = null;
      isEditing = false;
      _clearValidationErrors();
      apiError = null;
      loading = false;

      notifyListeners();

      return null;
    } catch (err) {
      loading = false;

      final msg = ApiClient.formatDioError(err).toLowerCase();

      if (msg.contains('http 401')) {
        await _clearLocalSession();
        error = 'غير مصرح. سجّل دخول من جديد.';
        notifyListeners();
        return error;
      }

      final currentUsername = _profile?.username.trim() ?? '';
      final currentEmail = _profile?.email.trim() ?? '';
      final currentPhone = _normalizePhone(_profile?.phoneNumber ?? '');

      final usernameChanged =
          _normalizeForCompare(u) != _normalizeForCompare(currentUsername);
      final emailChanged =
          _normalizeForCompare(e) != _normalizeForCompare(currentEmail);
      final phoneChanged =
          _normalizePhoneForCompare(p) != _normalizePhoneForCompare(currentPhone);

      String? fieldOnlyError;

      if (_isDuplicateUsernameError(msg)) {
        usernameError = 'اسم المستخدم مستخدم بالفعل';
        apiError = null;
        fieldOnlyError = usernameError;
      } else if (_isDuplicateEmailError(msg)) {
        emailError = 'هذا البريد الإلكتروني مستخدم بالفعل';
        apiError = null;
        fieldOnlyError = emailError;
      } else if (_isDuplicatePhoneError(msg)) {
        phoneError = 'رقم الجوال مستخدم بالفعل';
        apiError = null;
        fieldOnlyError = phoneError;
      } else if (_isInvalidPhoneVerificationToken(msg)) {
        apiError = 'رمز توثيق تغيير رقم الجوال غير صالح أو منتهي الصلاحية';
      } else if (_isGenericDuplicateError(msg)) {
        if (usernameChanged) {
          usernameError = 'اسم المستخدم مستخدم بالفعل';
          apiError = null;
          fieldOnlyError = usernameError;
        } else if (emailChanged) {
          emailError = 'هذا البريد الإلكتروني مستخدم بالفعل';
          apiError = null;
          fieldOnlyError = emailError;
        } else if (phoneChanged) {
          phoneError = 'رقم الجوال مستخدم بالفعل';
          apiError = null;
          fieldOnlyError = phoneError;
        } else {
          apiError = 'البيانات مستخدمة بالفعل';
        }
      } else {
        apiError = _mapProfileErrorMessage(err);
      }

      notifyListeners();

      return fieldOnlyError ?? apiError;
    }
  }

  Future<String?> toggleInterest(Interest interest) async {
    final hasIt = selectedInterests.contains(interest);

    if (hasIt && selectedInterests.length <= 1) {
      interestsError = 'لا يمكن حذف آخر اهتمام. يجب اختيار اهتمام واحد على الأقل';
      notifyListeners();
      return interestsError;
    }

    apiError = null;
    interestsError = null;
    notifyListeners();

    try {
      if (hasIt) {
        final res = await _profileApi.removeInterest(interest.key);

        if (res['interests'] is List) {
          final raw = res['interests'] as List;

          final parsed = raw
              .map((e) => InterestX.fromKey(e.toString()))
              .whereType<Interest>()
              .toList();

          _profile = _profile?.copyWith(interests: parsed);
        } else {
          final next = <Interest>{...selectedInterests}..remove(interest);
          _profile = _profile?.copyWith(interests: next.toList());
        }
      } else {
        final res = await _profileApi.addInterests([interest.key]);

        if (res['interests'] is List) {
          final raw = res['interests'] as List;

          final parsed = raw
              .map((e) => InterestX.fromKey(e.toString()))
              .whereType<Interest>()
              .toList();

          _profile = _profile?.copyWith(interests: parsed);
        } else {
          final next = <Interest>{...selectedInterests, interest};
          _profile = _profile?.copyWith(interests: next.toList());
        }
      }

      if (_profile != null) {
        await _saveProfileToCache(_profile!.toJson());
      }

      interestsError = null;
      notifyListeners();

      return null;
    } catch (e) {
      final msg = ApiClient.formatDioError(e);

      if (msg.contains('HTTP 401') || msg.toLowerCase().contains('http 401')) {
        await _clearLocalSession();
        error = 'غير مصرح. سجّل دخول من جديد.';
        notifyListeners();
        return error;
      }

      apiError = _mapProfileErrorMessage(e);

      notifyListeners();

      return apiError;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      await _profileApi.deleteMyProfile();
      await _clearLocalSession();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> signOut() async {
    try {
      await _clearLocalSession();
      return true;
    } catch (_) {
      return false;
    }
  }
}