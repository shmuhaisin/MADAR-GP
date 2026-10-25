import 'package:flutter/foundation.dart';

@immutable
class AddedNewsModel {
  final String id;
  final String sharedCollectionId;
  final String originalNewsId;
  final String addedByUserId;

  final String newsContent;
  final String newsTitle;
  final String newsSource;
  final String sourceLink;
  final String category;

  final DateTime publishDate;

  final String ttsAudioURLforContent;
  final String ttsAudioURLforSummary;
  final String summaryText;

  final DateTime? createdAt;
  final bool isArchived;
  final bool sharedByCreator;
  final bool isAddedByMe;

  const AddedNewsModel({
    required this.id,
    required this.sharedCollectionId,
    required this.originalNewsId,
    required this.addedByUserId,
    required this.newsContent,
    required this.newsTitle,
    required this.newsSource,
    required this.sourceLink,
    required this.category,
    required this.publishDate,
    required this.ttsAudioURLforContent,
    required this.ttsAudioURLforSummary,
    required this.summaryText,
    this.createdAt,
    this.isArchived = false,
    this.sharedByCreator = false,
    this.isAddedByMe = false,
  });

  factory AddedNewsModel.fromJson(
    Map<String, dynamic> json, {
    bool sharedByCreator = false,
    bool isAddedByMe = false,
  }) {
    final publish =
        _asDate(json['publishDate'] ?? json['publishedAt'] ?? json['date']) ??
            DateTime.fromMillisecondsSinceEpoch(0);

    return AddedNewsModel(
      id: _asObjectId(json['_id'] ?? json['id']),
      sharedCollectionId: _asObjectId(
        json['sharedCollectionId'] ?? json['sharedCollectionID'],
      ),
      originalNewsId: _asObjectId(
        json['originalNewsId'] ?? json['originalNewsID'],
      ),
      addedByUserId: _asObjectId(
        json['addedByUserId'] ?? json['addedByUserID'],
      ),
      newsContent: _asString(json['newsContent'] ?? json['content']),
      newsTitle: _asString(json['newsTitle'] ?? json['title']),
      newsSource: _asString(json['newsSource'] ?? json['source']),
      sourceLink: _asString(json['sourceLink'] ?? json['url'] ?? json['link']),
      category: _asString(json['category']),
      publishDate: publish,
      ttsAudioURLforContent: _asString(
        json['ttsAudioURLforContent'] ?? json['ttsAudioUrlForContent'],
      ),
      ttsAudioURLforSummary: _asString(
        json['ttsAudioURLforSummary'] ?? json['ttsAudioUrlForSummary'],
      ),
      summaryText: _asString(json['summaryText']),
      createdAt: _asDate(json['createdAt']),
      isArchived: json['isArchived'] == true,
      sharedByCreator: sharedByCreator,
      isAddedByMe: isAddedByMe,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'id': id,
      'sharedCollectionId': sharedCollectionId,
      'originalNewsId': originalNewsId,
      'addedByUserId': addedByUserId,
      'newsContent': newsContent,
      'newsTitle': newsTitle,
      'newsSource': newsSource,
      'sourceLink': sourceLink,
      'category': category,
      'publishDate': publishDate.toIso8601String(),
      'ttsAudioURLforContent': ttsAudioURLforContent,
      'ttsAudioURLforSummary': ttsAudioURLforSummary,
      'summaryText': summaryText,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      'isArchived': isArchived,
      'sharedByCreator': sharedByCreator,
      'isAddedByMe': isAddedByMe,
    };
  }

  AddedNewsModel copyWith({
    String? id,
    String? sharedCollectionId,
    String? originalNewsId,
    String? addedByUserId,
    String? newsContent,
    String? newsTitle,
    String? newsSource,
    String? sourceLink,
    String? category,
    DateTime? publishDate,
    String? ttsAudioURLforContent,
    String? ttsAudioURLforSummary,
    String? summaryText,
    DateTime? createdAt,
    bool? isArchived,
    bool? sharedByCreator,
    bool? isAddedByMe,
  }) {
    return AddedNewsModel(
      id: id ?? this.id,
      sharedCollectionId: sharedCollectionId ?? this.sharedCollectionId,
      originalNewsId: originalNewsId ?? this.originalNewsId,
      addedByUserId: addedByUserId ?? this.addedByUserId,
      newsContent: newsContent ?? this.newsContent,
      newsTitle: newsTitle ?? this.newsTitle,
      newsSource: newsSource ?? this.newsSource,
      sourceLink: sourceLink ?? this.sourceLink,
      category: category ?? this.category,
      publishDate: publishDate ?? this.publishDate,
      ttsAudioURLforContent: ttsAudioURLforContent ?? this.ttsAudioURLforContent,
      ttsAudioURLforSummary: ttsAudioURLforSummary ?? this.ttsAudioURLforSummary,
      summaryText: summaryText ?? this.summaryText,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
      sharedByCreator: sharedByCreator ?? this.sharedByCreator,
      isAddedByMe: isAddedByMe ?? this.isAddedByMe,
    );
  }

  static String _asObjectId(dynamic v) {
    if (v == null) return '';

    if (v is Map) {
      final raw = v[r'$oid'] ?? v['\$oid'] ?? v[r'$id'] ?? v['\$id'];
      if (raw is String) return raw.trim();
    }

    final s = v.toString().trim();
    final m = RegExp(r'([a-fA-F0-9]{24})').firstMatch(s);
    return m?.group(1) ?? s;
  }

  static String _asString(dynamic v) => (v == null) ? '' : v.toString();

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);

    if (v is Map) {
      final d = v[r'$date'] ?? v['\$date'];
      if (d is String) return DateTime.tryParse(d);
      if (d is int) return DateTime.fromMillisecondsSinceEpoch(d);
    }

    return null;
  }
}