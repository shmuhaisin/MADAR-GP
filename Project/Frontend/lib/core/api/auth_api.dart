import 'package:flutter/foundation.dart';

import 'api_client.dart';
import '../../features/login-signup/model/auth_model.dart';
import 'endpoints.dart';

class AuthApi {
  final ApiClient _api;

  AuthApi(this._api);

  // ---------------- SIGNIN ----------------
  Future<AuthResultModel> signin(LoginModel req) async {
    debugPrint('SIGNIN body => ${req.toJson()}');

    final res = await _api.postMap(
      Endpoints.authSignin,
      data: req.toJson(),
      auth: false,
    );

    return AuthResultModel.fromJson(res);
  }

  // ---------------- SIGNUP OTP FLOW ----------------
  Future<void> signupRequestOtp(SignUpRequestModel req) async {
    debugPrint('SIGNUP REQUEST-OTP body => ${req.toJson()}');

    await _api.postMap(
      Endpoints.authSignupRequestOtp,
      data: req.toJson(),
      auth: false,
    );
  }

  Future<AuthResultModel> signupVerifyOtp({
    required String phone,
    required String code,
  }) async {
    final res = await _api.postMap(
      Endpoints.authSignupVerifyOtp,
      data: {
        'phone': phone,
        'code': code,
      },
      auth: false,
    );

    return AuthResultModel.fromJson(res);
  }

  // ---------------- RESET PASSWORD FLOW ----------------
  Future<void> requestResetOtp({required String phoneNumber}) async {
    await _api.postMap(
      Endpoints.authPasswordRequestOtp,
      data: {'phoneNumber': phoneNumber},
      auth: false,
    );
  }

  Future<String> confirmResetOtp({
    required String phone,
    required String code,
  }) async {
    final res = await _api.postMap(
      Endpoints.authPasswordConfirm,
      data: {
        'phone': phone,
        'code': code,
      },
      auth: false,
    );

    final resetToken = res['resetToken']?.toString();

    if (resetToken == null || resetToken.isEmpty) {
      throw Exception('Missing resetToken from backend');
    }

    return resetToken;
  }

  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await _api.postMap(
      Endpoints.authPasswordReset,
      data: {
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
      auth: false,
    );
  }

  // ---------------- FCM TOKEN ----------------
  Future<void> saveFcmToken(String token) async {
    await _api.postMap(
      Endpoints.authSaveFcmToken,
      data: {'fcmToken': token},
      auth: true,
    );
  }

  // ---------------- CHANGE PHONE OTP FLOW (AUTH) ----------------
  Future<void> requestPhoneChangeOtp({
    required String phoneNumber,
  }) async {
    await _api.postMap(
      Endpoints.authPhoneChangeRequestOtp,
      data: {'phoneNumber': phoneNumber},
      auth: true,
    );
  }

  Future<String> verifyPhoneChangeOtp({
    required String phone,
    required String code,
  }) async {
    final res = await _api.postMap(
      Endpoints.authPhoneChangeVerifyOtp,
      data: {
        'phone': phone,
        'code': code,
      },
      auth: true,
    );

    final token = res['phoneChangeVerificationToken']?.toString();

    if (token == null || token.isEmpty) {
      throw Exception('Missing phoneChangeVerificationToken from backend');
    }

    return token;
  }
}