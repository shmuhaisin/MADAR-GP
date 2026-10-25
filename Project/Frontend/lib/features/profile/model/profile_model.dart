// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart';

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

@immutable
class ProfileModel {
  final String username;
  final String email;
  final String phoneNumber;
  final String birthdate; // "YYYY-MM-DD"
  final List<Interest> interests;

  const ProfileModel({
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.birthdate,
    required this.interests,
  });

  ProfileModel copyWith({
    String? username,
    String? email,
    String? phoneNumber,
    String? birthdate,
    List<Interest>? interests,
  }) {
    return ProfileModel(
      username: username ?? this.username,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      birthdate: birthdate ?? this.birthdate,
      interests: interests ?? this.interests,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'birthdate': birthdate,
      'phoneNumber': phoneNumber,
      'interests': interests.map((e) => e.key).toList(),
    };
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['interests'] as List?) ?? const [];
    final parsed = raw
        .map((e) => InterestX.fromKey(e.toString()))
        .whereType<Interest>()
        .toList();

    return ProfileModel(
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      birthdate: (json['birthdate'] ?? '').toString(),
      phoneNumber: (json['phoneNumber'] ?? '').toString(),
      interests: parsed,
    );
  }
}
