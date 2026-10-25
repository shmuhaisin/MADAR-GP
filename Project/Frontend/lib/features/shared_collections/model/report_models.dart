class ReportModel {
  final String id;
  final String? addedNewsId;

  final String reporterUsername;
  final String newsTitle;
  final String reason;
  final DateTime reportedAt;
  final String? addedByUsername;

  const ReportModel({
    required this.id,
    required this.reporterUsername,
    required this.newsTitle,
    required this.reason,
    required this.reportedAt,
    this.addedByUsername,
    this.addedNewsId,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    final reportedBy = (json['reportedBy'] as Map?) ?? {};
    final news = (json['news'] as Map?) ?? {};
    final addedBy = (news['addedBy'] as Map?) ?? {};

    return ReportModel(
      id: (json['id'] ?? '').toString(),
      reason: (json['reportReason'] ?? '').toString(),
      reportedAt: DateTime.tryParse((json['reportedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reporterUsername: (reportedBy['username'] ?? '').toString(),
      newsTitle: (news['title'] ?? '').toString(),
      addedByUsername: (addedBy['username'] ?? '').toString(),
      addedNewsId: (news['addedNewsId'] ?? '').toString().trim().isEmpty
          ? null
          : (news['addedNewsId'] ?? '').toString(),
    );
  }
}