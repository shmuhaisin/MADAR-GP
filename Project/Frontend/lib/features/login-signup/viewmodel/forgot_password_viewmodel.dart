import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/auth_api.dart';

/// ViewModel responsible for:
/// 1) managing forgot-password phone form state,
/// 2) validating country code and phone input,
/// 3) building the final phone number sent to the backend,
/// 4) sending the reset OTP request,
/// 5) mapping technical failures into user-friendly messages.
class ForgotPasswordPhoneViewModel extends ChangeNotifier {
  /// Shared API client used for backend communication.
  final ApiClient _client;

  /// Authentication API wrapper built on top of the shared API client.
  late final AuthApi _authApi;

  ForgotPasswordPhoneViewModel({ApiClient? client})
      : _client = client ?? ApiClient() {
    _authApi = AuthApi(_client);
  }

  /// Selected country dial code.
  ///
  /// Default is Saudi Arabia.
  /// Examples:
  /// +966, +971, +20
  String countryDialCode = '+966';

  /// Local phone digits entered by the user.
  ///
  /// Saudi examples:
  /// 5XXXXXXXX
  /// 05XXXXXXXX
  String phoneDigits = '';

  /// True while the OTP request is being sent.
  bool loading = false;

  /// Field-level validation error for phone number.
  String? phoneError;

  /// Field-level validation error for country code.
  String? countryCodeError;

  /// Request-level error shown after submission failure.
  String? apiError;

  /// Builds the final phone number sent to the backend.
  ///
  /// Example:
  /// countryDialCode = +966
  /// phoneDigits = 0501234567
  /// result = +966501234567
  String get phoneFull {
    final local = _stripLeadingZeros(_normalizeDigits(phoneDigits));
    final dial = _normalizeCountryCode(countryDialCode);
    return '$dial$local';
  }

  /// Controls whether the submit button should be enabled.
  ///
  /// The button is disabled when:
  /// - request is already in progress,
  /// - phone input is empty,
  /// - country code is invalid,
  /// - phone number is invalid.
  bool get canSubmit {
    if (loading) return false;
    if (phoneDigits.isEmpty) return false;
    if (!_isCountryCodeValid()) return false;
    if (!_isPhoneValid()) return false;

    return true;
  }

  /// Updates the country dial code.
  ///
  /// While typing/changing:
  /// - normalize the dial code,
  /// - clear previous API error,
  /// - revalidate current input,
  /// - do not delay format checking because country code is structural input.
  void setCountryDialCode(String value) {
    countryDialCode = _normalizeCountryCode(value);
    apiError = null;

    _validateFields(showRequired: false);
    notifyListeners();
  }

  /// Updates the local phone digits.
  ///
  /// While typing:
  /// - normalize Arabic/Persian numerals into English digits,
  /// - remove non-digit characters,
  /// - clear previous API error,
  /// - validate format,
  /// - do not show "required" until submission.
  void setPhoneDigits(String value) {
    phoneDigits = _digitsOnly(_normalizeDigits(value));
    apiError = null;

    _validateFields(showRequired: false);
    notifyListeners();
  }

  /// Validates both country code and phone fields.
  ///
  /// When [showRequired] is true, empty-field messages are shown.
  /// Otherwise, only structural/format validation is applied.
  void _validateFields({required bool showRequired}) {
    phoneError = null;
    countryCodeError = null;

    if (!_isCountryCodeValid()) {
      countryCodeError = 'رمز الدولة غير صحيح';
    }

    if (phoneDigits.isEmpty) {
      if (showRequired) {
        phoneError = 'رقم الجوال مطلوب';
      }
    } else if (!_isPhoneValid()) {
      phoneError = _phoneValidationMessage();
    }
  }

  /// Runs full validation before submit.
  ///
  /// This is the stage where required-field errors should appear.
  bool validateAll() {
    apiError = null;

    _validateFields(showRequired: true);
    notifyListeners();

    return countryCodeError == null && phoneError == null;
  }

  /// Checks whether the country code has a valid format.
  ///
  /// Accepted format:
  /// + followed by 1 to 4 digits
  /// Examples:
  /// +966
  /// +20
  bool _isCountryCodeValid() {
    final normalized = _normalizeCountryCode(countryDialCode);
    return RegExp(r'^\+\d{1,4}$').hasMatch(normalized);
  }

  /// Validates the phone number based on the selected country.
  ///
  /// Saudi Arabia (+966):
  /// - 9 digits starting with 5, or
  /// - 10 digits starting with 05
  ///
  /// Other countries:
  /// - generic validation from 6 to 14 digits
  bool _isPhoneValid() {
    final digits = _digitsOnly(_normalizeDigits(phoneDigits));

    if (countryDialCode == '+966') {
      if (digits.length == 9 && digits.startsWith('5')) return true;
      if (digits.length == 10 && digits.startsWith('05')) return true;
      return false;
    }

    return digits.length >= 6 && digits.length <= 14;
  }

  /// Returns the appropriate phone validation message.
  String _phoneValidationMessage() {
    if (countryDialCode == '+966') {
      return 'رقم الجوال غير صحيح (مثال: 5XXXXXXXX أو 05XXXXXXXX)';
    }
    return 'رقم الهاتف غير صحيح';
  }

  /// Converts Arabic and Persian numerals into English numerals.
  ///
  /// Example:
  /// ٠٥٠١٢٣٤٥٦٧ -> 0501234567
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

  /// Removes any non-digit characters from the input.
  String _digitsOnly(String input) {
    return input.replaceAll(RegExp(r'\D'), '');
  }

  /// Normalizes the dial code into the format:
  /// +digits
  ///
  /// Examples:
  /// 966  -> +966
  /// +966 -> +966
  String _normalizeCountryCode(String code) {
    final digits = _digitsOnly(_normalizeDigits(code));
    return digits.isEmpty ? '' : '+$digits';
  }

  /// Removes leading zeros from the local phone number.
  ///
  /// Example:
  /// 0501234567 -> 501234567
  String _stripLeadingZeros(String input) {
    return input.replaceFirst(RegExp(r'^0+'), '');
  }

  /// Detects whether the device most likely has no internet access.
  ///
  /// Important:
  /// This method is intentionally strict.
  /// It only returns true for strong indicators that the user's device
  /// is offline or cannot reach the network.
  ///
  /// It does NOT classify every timeout or generic connection issue
  /// as "no internet", because those may also be caused by backend issues.
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

  /// Detects whether the backend reported that no user exists
  /// for the submitted phone number.
  bool _isPhoneNotRegisteredError(String message) {
    return message.contains('no user with this phone') ||
        message.contains('user not found') ||
        message.contains('phone not found') ||
        message.contains('404');
  }

  /// Detects whether the failure is most likely from the server or application.
  ///
  /// These errors should not be shown as internet issues.
  bool _isServerOrAppError(String message) {
    return message.contains('500') ||
        message.contains('502') ||
        message.contains('503') ||
        message.contains('504') ||
        message.contains('internal server error') ||
        message.contains('server error') ||
        message.contains('bad response');
  }

  /// Converts technical exceptions into user-facing Arabic messages.
  ///
  /// Classification order:
  /// 1) phone not registered,
  /// 2) confirmed no-internet case on the user's device,
  /// 3) server/app failure,
  /// 4) generic unexpected failure.
  String _mapForgotPasswordErrorMessage(Object error) {
    final message = ApiClient.formatDioError(error).toLowerCase();

    if (_isPhoneNotRegisteredError(message)) {
      return 'رقم الجوال غير مسجل';
    }

    if (_isNoInternetError(error)) {
      return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';
    }

    if (_isServerOrAppError(message)) {
      return 'حدث خطأ في الخادم أو في التطبيق. يرجى المحاولة مرة أخرى لاحقًا';
    }

    return 'حدث خطأ أثناء إرسال رمز التحقق. يرجى المحاولة مرة أخرى';
  }

  /// Sends the reset-password OTP request to the backend.
  ///
  /// Flow:
  /// 1) validate local input,
  /// 2) send the final normalized phone number,
  /// 3) return true on success,
  /// 4) show a proper user-facing error on failure.
  Future<bool> submit() async {
    if (!validateAll()) return false;

    loading = true;
    apiError = null;
    notifyListeners();

    try {
      await _authApi.requestResetOtp(phoneNumber: phoneFull);

      loading = false;
      notifyListeners();
      return true;
    } catch (error) {
      loading = false;
      apiError = _mapForgotPasswordErrorMessage(error);

      notifyListeners();
      return false;
    }
  }

  /// Resets the whole form back to its default state.
  void clear() {
    countryDialCode = '+966';
    phoneDigits = '';
    loading = false;

    phoneError = null;
    countryCodeError = null;
    apiError = null;

    notifyListeners();
  }
}