import '../../profile/model/profile_model.dart';

enum NotifType { joinReq, reqReply, semantic }

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotifType type;
  final DateTime date;
  bool isRead;

  final String? status;
  final String? newsID;
  final String? collectionId;
  final Interest? interest;
  final String? keyword;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.date,
    this.isRead = false,
    this.status,
    this.newsID,
    this.collectionId,
    this.interest,
    this.keyword,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {

    NotifType parseType(String? t) {
      switch (t) {
        case 'joinReq':
          return NotifType.joinReq;
        case 'reqReply':
          return NotifType.reqReply;
        case 'semantic':
          return NotifType.semantic;
        default:
          return NotifType.joinReq;
      }
    }

    Interest? parseInterest(String? i) {
      if (i == null || i.isEmpty) return null;
      try {
        return InterestX.fromKey(i);
      } catch (_) {
        return null;
      }
    }

    return NotificationModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      type: parseType(json['type']?.toString()),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      isRead: json['isRead'] == true,
      status: json['status']?.toString(),
      newsID: json['relatedNewsId']?.toString(),
      collectionId: json['collectionId']?.toString(),
      keyword: json['keyword']?.toString(),
      interest: parseInterest(json['interest']?.toString()), 
    );
  }
}
