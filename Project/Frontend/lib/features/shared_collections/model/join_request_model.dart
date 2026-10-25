
class JoinRequestModel {
  final String id;
  final String username;
  final String requestDate;

  const JoinRequestModel({
    required this.id,
    required this.username,
    required this.requestDate,
  });

  factory JoinRequestModel.fromJson(Map<String, dynamic> json) {
    return JoinRequestModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      requestDate: (json['requestDate'] ?? json['createdAt'] ?? '').toString(),
    );
  }
}