import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/auth_api.dart';

/// ViewModel responsible for:
/// 1) managing OTP input state,
/// 2) handling countdown timer logic,
/// 3) validating the verification code,
/// 4) submitting OTP verification requests for different flows,
/// 5) mapping technical exceptions into user-friendly messages.
class OtpVerifyViewModel extends ChangeNotifier {
  /// Phone number associated with the OTP process.
  final String phone;

  /// Shared API client used for backend communication.
  final ApiClient _client;

  /// Authentication API wrapper built on top of the shared API client.
  late final AuthApi _authApi;

  OtpVerifyViewModel({
    required this.phone,
    ApiClient? client,
  }) : _client = client ?? ApiClient() {
    _authApi = AuthApi(_client);
    _startTimer();
  }

  /// Stores the 6 OTP digits separately to support multi-field input UI.
  final List<String> digits = ['', '', '', '', '', ''];

  /// True while a verification request is being sent.
  bool loading = false;

  /// Field-level validation error for the OTP code itself.
  String? otpError;

  /// Request-level error shown when verification fails after submission.
  String? apiError;

  /// Remaining resend countdown in seconds.
  int seconds = 45;

  /// Internal timer used for the resend countdown.
  Timer? _timer;

  /// Returns the final 6-digit OTP code as one string.
  String get code => digits.join();

  /// Returns true only when all OTP boxes are filled and no request is running.
  bool get canVerify => digits.every((d) => d.isNotEmpty) && !loading;

  /// Returns true only when resend is allowed and no request is running.
  bool get canResend => seconds == 0 && !loading;

  /// Updates one OTP digit.
  ///
  /// Behavior:
  /// - clears old validation/request errors,
  /// - accepts only one normalized digit,
  /// - allows empty string when deleting input.
  void setDigit(int index, String value) {
    otpError = null;
    apiError = null;

    final normalized = _digitsOnly(_normalizeDigits(value));

    if (normalized.isEmpty) {
      digits[index] = '';
    } else {
      digits[index] = normalized[0];
    }

    notifyListeners();
  }

  /// Fills OTP boxes starting from [startIndex] using pasted text.
  ///
  /// Behavior:
  /// - accepts Arabic and English numerals,
  /// - ignores non-digit characters,
  /// - stops when all 6 boxes are filled.
  void setCodeFromPaste(String pasted, {required int startIndex}) {
    otpError = null;
    apiError = null;

    final chars = _digitsOnly(_normalizeDigits(pasted)).split('');

    for (int i = 0; i < chars.length; i++) {
      final idx = startIndex + i;
      if (idx >= digits.length) break;
      digits[idx] = chars[i];
    }

    notifyListeners();
  }

  /// Clears all OTP digits.
  void clearCode() {
    digits.setAll(0, ['', '', '', '', '', '']);
    otpError = null;
    apiError = null;
    notifyListeners();
  }

  /// Starts or restarts the resend countdown timer.
  void _startTimer() {
    _timer?.cancel();
    seconds = 45;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (seconds <= 0) {
        seconds = 0;
        timer.cancel();
      } else {
        seconds--;
      }

      notifyListeners();
    });
  }

  /// Validates OTP code before verification.
  ///
  /// Current rule:
  /// - all 6 digits must be entered.
  bool validateCode() {
    otpError = null;

    if (digits.any((d) => d.isEmpty)) {
      otpError = 'أدخل رمز التحقق كاملًا';
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  /// Converts Arabic and Persian numerals into English numerals.
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

  /// Removes all non-digit characters from the input.
  String _digitsOnly(String input) {
    return input.replaceAll(RegExp(r'\D'), '');
  }

  /// Detects whether the device most likely has no internet access.
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

  /// Detects whether the submitted OTP code is invalid.
  bool _isInvalidOtpError(String message) {
    return message.contains('invalid otp') ||
        message.contains('invalid code') ||
        message.contains('incorrect code') ||
        message.contains('wrong code') ||
        message.contains('invalid verification code') ||
        message.contains('401');
  }

  /// Detects whether the submitted OTP code has expired.
  bool _isExpiredOtpError(String message) {
    return message.contains('expired otp') ||
        message.contains('otp expired') ||
        message.contains('code expired') ||
        message.contains('verification code expired') ||
        message.contains('expired');
  }

  /// Detects whether the user is being rate-limited.
  bool _isTooManyRequestsError(String message) {
    return message.contains('too many requests') ||
        message.contains('rate limit') ||
        message.contains('429');
  }

  /// Detects whether the failure is most likely from the server or application.
  bool _isServerOrAppError(String message) {
    return message.contains('500') ||
        message.contains('502') ||
        message.contains('503') ||
        message.contains('504') ||
        message.contains('internal server error') ||
        message.contains('server error') ||
        message.contains('bad response');
  }

  /// Converts technical verification errors into user-facing Arabic messages.
  String _mapOtpErrorMessage(Object error) {
    final message = ApiClient.formatDioError(error).toLowerCase();

    if (_isInvalidOtpError(message)) {
      return 'رمز التحقق غير صحيح';
    }

    if (_isExpiredOtpError(message)) {
      return 'انتهت صلاحية رمز التحقق. يرجى طلب رمز جديد';
    }

    if (_isTooManyRequestsError(message)) {
      return 'تم تجاوز عدد المحاولات المسموح. يرجى المحاولة لاحقًا';
    }

    if (_isNoInternetError(error)) {
      return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';
    }

    if (_isServerOrAppError(message)) {
      return 'حدث خطأ في الخادم أو في التطبيق. يرجى المحاولة مرة أخرى لاحقًا';
    }

    return 'حدث خطأ أثناء التحقق من الرمز. يرجى المحاولة مرة أخرى';
  }

  /// Shared verification wrapper for API calls that return a value.
  ///
  /// Examples:
  /// - reset token
  /// - phone change verification token
  Future<T?> _runVerification<T>(Future<T> Function() action) async {
    if (!validateCode()) return null;

    loading = true;
    otpError = null;
    apiError = null;
    notifyListeners();

    try {
      final result = await action();

      loading = false;
      notifyListeners();
      return result;
    } catch (error) {
      loading = false;
      apiError = _mapOtpErrorMessage(error);
      notifyListeners();
      return null;
    }
  }

  /// Shared verification wrapper for API calls that return no value.
  ///
  /// This is used for flows where success is enough and no token/data is returned.
  Future<bool> _runVoidVerification(Future<void> Function() action) async {
    if (!validateCode()) return false;

    loading = true;
    otpError = null;
    apiError = null;
    notifyListeners();

    try {
      await action();

      loading = false;
      notifyListeners();
      return true;
    } catch (error) {
      loading = false;
      apiError = _mapOtpErrorMessage(error);
      notifyListeners();
      return false;
    }
  }

  /// Verifies signup OTP.
  ///
  /// Returns:
  /// - true on success
  /// - false on failure
  Future<bool> verifySignupOtp() {
    return _runVoidVerification(() {
      return _authApi.signupVerifyOtp(
        phone: phone.trim(),
        code: code,
      );
    });
  }

  /// Verifies forgot-password OTP and returns the reset token on success.
  ///
  /// Returns:
  /// - reset token on success
  /// - null on failure
  Future<String?> verifyForgotPasswordOtpAndGetResetToken() {
    return _runVerification<String>(() {
      return _authApi.confirmResetOtp(
        phone: phone.trim(),
        code: code,
      );
    });
  }

  /// Verifies phone-change OTP and returns the phone-change token on success.
  ///
  /// Returns:
  /// - verification token on success
  /// - null on failure
  Future<String?> verifyPhoneChangeOtpAndGetToken() {
    return _runVerification<String>(() {
      return _authApi.verifyPhoneChangeOtp(
        phone: phone.trim(),
        code: code,
      );
    });
  }

  /// Resets the local OTP UI state and restarts the resend timer.
  ///
  /// Important:
  /// This method does NOT call the backend to resend a code.
  /// It only clears the local fields and restarts the local countdown.
  void resendLocalOnly() {
    digits.setAll(0, ['', '', '', '', '', '']);
    otpError = null;
    apiError = null;
    _startTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}