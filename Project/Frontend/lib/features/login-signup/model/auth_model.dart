// auth_model.dart

// ignore_for_file: constant_identifier_names

// ===== Interests (match backend enum values) =====
// Backend enum in TS often is: HEALTH, ENTERTAINMENT, ...
// If your TS enum is lowercase, change keys below to match exactly.
enum Interest {
  Health,
  Entertainment,
  Politics,
  Technology,
  Sports,
}

extension InterestX on Interest {
  String get labelAr {
    switch (this) {
      case Interest.Health:
        return 'الصحة';
      case Interest.Entertainment:
        return 'الترفيه';
      case Interest.Politics:
        return 'السياسة';
      case Interest.Technology:
        return 'التقنية';

      case Interest.Sports:
        return 'الرياضة';
    }
  }

  //  what we send to backend

  String get key {
  switch (this) {
    case Interest.Health:
      return 'Health';
    case Interest.Entertainment:
      return 'Entertainment';
    case Interest.Politics:
      return 'Politics';
    case Interest.Technology:
      return 'Technology';

    case Interest.Sports:
      return 'Sports';
  }
}

  static Interest? fromKey(String v) {
  final x = v.trim().toLowerCase();
  for (final i in Interest.values) {
    if (i.key.toLowerCase() == x) return i;
  }
  return null;
}
}

// ===== Login =====
class LoginModel {
  final String identifier; // username OR email
  final String password;

  const LoginModel({
    required this.identifier,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'password': password,
      };
}

// ===== SignUp request (what VM builds & sends) =====
class SignUpRequestModel {
  final String username;
  final String email;
  final String password;
  final String phoneNumber;
  final String birthdate; // "YYYY-MM-DD"
  final List<Interest> interests;

  const SignUpRequestModel({
    required this.username,
    required this.email,
    required this.password,
    required this.phoneNumber,
    required this.birthdate,
    required this.interests,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'password': password,
        'phoneNumber': phoneNumber,
        'birthdate': birthdate,
        'interests': interests.map((e) => e.key).toList(),
      };
}

// ===== User =====
class UserModel {
  final String id;
  final String username;
  final String email;
  final String phoneNumber;
  final String birthdate;
  final List<Interest> interests;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.birthdate,
    required this.interests,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // accept both "interests" and old keys if backend differs
    final raw = (json['interests'] ?? json['Interest'] ?? json['Interests']);
    final rawList = raw is List ? raw : const [];

    final parsed = rawList
        .map((e) => InterestX.fromKey(e.toString()))
        .whereType<Interest>()
        .toList();

    return UserModel(
      id: (json['id'] ?? json['_id'] ?? json['userID'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phoneNumber: (json['phoneNumber'] ?? '').toString(),
      birthdate: (json['birthdate'] ?? '').toString(),
      interests: parsed,
    );
  }
}

// ===== Auth result =====
class AuthResultModel {
  final String token;
  final UserModel user;

  const AuthResultModel({
    required this.token,
    required this.user,
  });

  factory AuthResultModel.fromJson(Map<String, dynamic> json) {
    return AuthResultModel(
      token: (json['token'] ?? json['accessToken'] ?? '').toString(),
      user: UserModel.fromJson(
        (json['user'] ?? json['data'] ?? {}) as Map<String, dynamic>,
      ),
    );
  }
}

// ===== Forgot Password request =====
class ForgotPasswordRequestModel {
  final String phoneNumber;

  const ForgotPasswordRequestModel({required this.phoneNumber});

  Map<String, dynamic> toJson() => {
        'phoneNumber': phoneNumber,
      };
}

// ===== OTP Verify request =====
class OtpVerifyRequestModel {
  final String phoneNumber;
  final String otp;

  const OtpVerifyRequestModel({
    required this.phoneNumber,
    required this.otp,
  });

  Map<String, dynamic> toJson() => {
        'phoneNumber': phoneNumber,
        'otp': otp,
      };
}

// ===== Reset Password request =====
class ResetPasswordRequestModel {
  final String resetToken;
  final String newPassword;

  const ResetPasswordRequestModel({
    required this.resetToken,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
        'resetToken': resetToken,
        'newPassword': newPassword,
      };
}
