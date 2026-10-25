import 'package:flutter/foundation.dart';

@immutable
class ArticleModel {
  final String id;

  final String newsTitle;
  final String newsContent;
  final String newsSource;
  final String sourceLink;
  final String category;

  final DateTime publishDate;

  final String ttsAudioURLforContent;
  final String ttsAudioURLforSummary;
  final String summaryText;

  final int reportsCount;

  const ArticleModel({
    required this.id,
    required this.newsTitle,
    required this.newsContent,
    required this.newsSource,
    required this.sourceLink,
    required this.category,
    required this.publishDate,
    required this.ttsAudioURLforContent,
    required this.ttsAudioURLforSummary,
    required this.summaryText,
    required this.reportsCount,
  });
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
factory ArticleModel.fromJson(Map<String, dynamic> json) {
  return ArticleModel(
id: _asObjectId(json['_id'] ?? json['id']),
    newsTitle: _asString(json['newsTitle'] ?? json['title']),
    newsContent: _asString(json['newsContent'] ?? json['content']),
    newsSource: _asString(json['newsSource'] ?? json['source']),
    sourceLink: _asString(json['sourceLink'] ?? json['url'] ?? json['link']),
    category: _asString(json['category']),
    publishDate: _asDate(json['publishDate']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    ttsAudioURLforContent: _asString(json['ttsAudioURLforContent']),
    ttsAudioURLforSummary: _asString(json['ttsAudioURLforSummary']),
    summaryText: _asString(json['summaryText']),
    reportsCount: json['reportsCount'] ?? 0,
  );
}


  ArticleModel copyWith({
    String? id,
    String? newsTitle,
    String? newsContent,
    String? newsSource,
    String? sourceLink,
    String? category,
    DateTime? publishDate,
    String? ttsAudioURLforContent,
    String? ttsAudioURLforSummary,
    String? summaryText,
    int? reportsCount,
  }) {
    return ArticleModel(
      id: id ?? this.id,
      newsTitle: newsTitle ?? this.newsTitle,
      newsContent: newsContent ?? this.newsContent,
      newsSource: newsSource ?? this.newsSource,
      sourceLink: sourceLink ?? this.sourceLink,
      category: category ?? this.category,
      publishDate: publishDate ?? this.publishDate,
      ttsAudioURLforContent:
          ttsAudioURLforContent ?? this.ttsAudioURLforContent,
      ttsAudioURLforSummary:
          ttsAudioURLforSummary ?? this.ttsAudioURLforSummary,
      summaryText: summaryText ?? this.summaryText,
      reportsCount: reportsCount ?? this.reportsCount,
    );
  }

  static String _asString(dynamic v) =>
      (v == null) ? '' : v.toString();

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);

    if (v is Map) {
      final d = v[r'$date'];
      if (d is String) return DateTime.tryParse(d);
      if (d is int) return DateTime.fromMillisecondsSinceEpoch(d);
    }

    return null;
  }
  Map<String, dynamic> toJson() => {
  '_id': id,
  'newsTitle': newsTitle,
  'newsContent': newsContent,
  'newsSource': newsSource,
  'sourceLink': sourceLink,
  'category': category,
  'publishDate': publishDate.toIso8601String(),
  'ttsAudioURLforContent': ttsAudioURLforContent,
  'ttsAudioURLforSummary': ttsAudioURLforSummary,
  'summaryText': summaryText,
  'reportsCount': reportsCount,
};
}