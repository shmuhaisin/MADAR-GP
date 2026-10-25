//member model
enum MemberRole { owner, member }

extension MemberRoleX on MemberRole {
  String get key => name; // "owner" | "member"

  static MemberRole fromKey(String? v) {
    final x = (v ?? '').trim().toLowerCase();
    for (final e in MemberRole.values) {
      if (e.name.toLowerCase() == x) return e;
    }
    return MemberRole.member; 
  }
}

class MemberModel {

  final String id;
   final String userId;
  final String username;
  final MemberRole role;

  const MemberModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.role,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
  
  final membershipId = (json['id'] ?? json['_id'] ?? '').toString();
  
  
  String extractedUserId = '';
  if (json['userId'] is Map) {
    extractedUserId = (json['userId']['_id'] ?? json['userId']['id'] ?? '').toString();
  } else {
    extractedUserId = (json['userId'] ?? '').toString();
  }
  
  
  String extractedUsername = '';
  if (json['userId'] is Map) {
    extractedUsername = (json['userId']['username'] ?? '').toString();
  } else {
    extractedUsername = (json['username'] ?? '').toString();
  }
  
  return MemberModel(
    id: membershipId,  
    userId: extractedUserId,  
    username: extractedUsername,
    role: MemberRoleX.fromKey(json['role']?.toString()),
  );
}

  Map<String, dynamic> toJson() {
    return {
      'userId': id,
      'username': username,
      'role': role.key,
    };
  }

  MemberModel copyWith({
    String? id,
    String? username,
    MemberRole? role,
  }) {
    return MemberModel(
      id: id ?? this.id,
      userId: userId,
      username: username ?? this.username,
      role: role ?? this.role,
    );
  }
}
