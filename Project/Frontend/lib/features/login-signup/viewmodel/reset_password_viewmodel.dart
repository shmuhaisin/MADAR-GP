import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/auth_api.dart';

/// ViewModel responsible for:
/// 1) managing reset-password form state,
/// 2) validating the new password and confirmation fields,
/// 3) submitting the password reset request,
/// 4) mapping technical failures into user-friendly messages.
class ResetPasswordViewModel extends ChangeNotifier {
  /// Reset token received after successful OTP verification.
  final String resetToken;

  /// Shared API client used for backend communication.
  final ApiClient _client;

  /// Authentication API wrapper built on top of the shared API client.
  late final AuthApi _authApi;

  ResetPasswordViewModel({
    required this.resetToken,
    ApiClient? client,
  }) : _client = client ?? ApiClient() {
    _authApi = AuthApi(_client);
  }

  /// New password entered by the user.
  String newPassword = '';

  /// Password confirmation entered by the user.
  String confirmPassword = '';

  /// Controls password visibility for the new-password field.
  bool obscure1 = true;

  /// Controls password visibility for the confirm-password field.
  bool obscure2 = true;

  /// True while the reset-password request is in progress.
  bool loading = false;

  /// Field-level validation error for the new password.
  String? newPassError;

  /// Field-level validation error for confirm password.
  String? confirmError;

  /// Request-level error shown after submission failure.
  String? apiError;

  /// Updates the new password field.
  ///
  /// While typing:
  /// - clears previous request error,
  /// - validates password rules,
  /// - does not show "required" until submit,
  /// - revalidates confirm password if it already has a value.
  void setNewPassword(String value) {
    newPassword = value;
    apiError = null;

    newPassError = _validateNewPassword(value, showRequired: false);

    if (confirmPassword.isNotEmpty) {
      confirmError = _validateConfirmPassword(
        confirmPassword,
        showRequired: false,
      );
    }

    notifyListeners();
  }

  /// Updates the confirm-password field.
  ///
  /// While typing:
  /// - clears previous request error,
  /// - checks whether the confirmation matches the new password,
  /// - does not show "required" until submit.
  void setConfirmPassword(String value) {
    confirmPassword = value;
    apiError = null;

    confirmError = _validateConfirmPassword(value, showRequired: false);
    notifyListeners();
  }

  /// Toggles visibility for the new-password field.
  void toggleObscure1() {
    obscure1 = !obscure1;
    notifyListeners();
  }

  /// Toggles visibility for the confirm-password field.
  void toggleObscure2() {
    obscure2 = !obscure2;
    notifyListeners();
  }

  /// Validates whether the password satisfies the required rules:
  /// - at least 6 characters,
  /// - at least one uppercase letter,
  /// - at least one digit,
  /// - at least one special character.
  bool _isPasswordValid(String value) {
    if (value.length < 6) return false;
    if (!RegExp(r'[A-Z]').hasMatch(value)) return false;
    if (!RegExp(r'[0-9]').hasMatch(value)) return false;
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]').hasMatch(value)) {
      return false;
    }

    return true;
  }

  /// Returns the exact validation message for the new password field.
  ///
  /// This centralizes password rule messages so the same logic is not duplicated
  /// in multiple methods.
  String? _validateNewPassword(String value, {required bool showRequired}) {
    if (value.isEmpty) {
      return showRequired ? 'كلمة المرور الجديدة مطلوبة' : null;
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

  /// Validates the confirm-password field.
  ///
  /// Rules:
  /// - required only when [showRequired] is true,
  /// - must exactly match the new password.
  String? _validateConfirmPassword(String value, {required bool showRequired}) {
    if (value.isEmpty) {
      return showRequired ? 'تأكيد كلمة المرور مطلوب' : null;
    }

    if (value != newPassword) {
      return 'كلمتا المرور غير متطابقتين';
    }

    return null;
  }

  /// Runs full form validation before submission.
  ///
  /// This is the stage where "required" errors should appear.
  bool validateAll() {
    newPassError = _validateNewPassword(newPassword, showRequired: true);
    confirmError = _validateConfirmPassword(
      confirmPassword,
      showRequired: true,
    );

    notifyListeners();
    return newPassError == null && confirmError == null;
  }

  /// Controls whether the submit button should be enabled.
  ///
  /// The button is disabled when:
  /// - request is already running,
  /// - either field is empty,
  /// - password rules are not satisfied,
  /// - confirmation does not match.
  bool get canSubmit {
    if (loading) return false;
    if (newPassword.isEmpty) return false;
    if (confirmPassword.isEmpty) return false;
    if (!_isPasswordValid(newPassword)) return false;
    if (confirmPassword != newPassword) return false;

    return true;
  }

  /// Detects whether the reset token is invalid or expired.
  bool _isInvalidOrExpiredTokenError(String message) {
    return (message.contains('invalid') && message.contains('token')) ||
        (message.contains('expired') && message.contains('token')) ||
        message.contains('reset token is invalid') ||
        message.contains('reset token is expired') ||
        message.contains('invalid reset token') ||
        message.contains('expired reset token') ||
        message.contains('unauthorized') ||
        message.contains('401');
  }

  /// Detects whether the device most likely has no internet access.
  ///
  /// This method is intentionally strict.
  /// It only returns true for strong indicators that the user's device
  /// is offline or cannot access the network.
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
  /// 1) invalid/expired reset token,
  /// 2) confirmed no-internet case on the user's device,
  /// 3) server/app failure,
  /// 4) generic unexpected failure.
  String _mapResetPasswordErrorMessage(Object error) {
    final message = ApiClient.formatDioError(error).toLowerCase();

    if (_isInvalidOrExpiredTokenError(message)) {
      return 'انتهت صلاحية رمز أو رابط إعادة التعيين. يرجى طلب رمز جديد';
    }

    if (_isNoInternetError(error)) {
      return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';
    }

    if (_isServerOrAppError(message)) {
      return 'حدث خطأ في الخادم أو في التطبيق. يرجى المحاولة مرة أخرى لاحقًا';
    }

    return 'حدث خطأ أثناء إعادة تعيين كلمة المرور. يرجى المحاولة مرة أخرى';
  }

  /// Sends the reset-password request to the backend.
  ///
  /// Important:
  /// The new password is sent exactly as typed by the user.
  /// It should not be trimmed automatically because trimming changes
  /// the actual password value.
  Future<bool> submit() async {
    if (!validateAll()) return false;

    loading = true;
    apiError = null;
    notifyListeners();

    try {
      await _authApi.resetPassword(
        resetToken: resetToken,
        newPassword: newPassword,
      );

      loading = false;
      notifyListeners();
      return true;
    } catch (error) {
      loading = false;
      apiError = _mapResetPasswordErrorMessage(error);

      notifyListeners();
      return false;
    }
  }

  /// Resets the whole form to its initial state.
  void clear() {
    newPassword = '';
    confirmPassword = '';
    obscure1 = true;
    obscure2 = true;
    loading = false;

    newPassError = null;
    confirmError = null;
    apiError = null;

    notifyListeners();
  }
}