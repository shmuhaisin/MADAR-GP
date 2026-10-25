import "member_model.dart";

// ===== Enums =====
enum CollectionKind { owned, joined }


// ---- Helpers ----
String _readId(Map<String, dynamic> json) =>
    (json["_id"] ?? json["id"] ?? "").toString();

int? _readInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

// ================================
// Shared Collections main screen
// ================================
class SharedCollectionUiModel {
  final String id;
  final String collectionName;
  final String collectionDescription;
  final String? ownerUsername;
  final CollectionKind? kind;
  final int? numOfViewers;

  const SharedCollectionUiModel({
    required this.id,
    required this.collectionName,
    required this.collectionDescription,
    this.kind,
    this.ownerUsername,
    this.numOfViewers,
  });

  SharedCollectionUiModel copyWith({
    String? id,
    String? collectionName,
    String? collectionDescription,
    CollectionKind? kind,
    String? ownerUsername,
    int? numOfViewers,
  }) {
    return SharedCollectionUiModel(
      id: id ?? this.id,
      collectionName: collectionName ?? this.collectionName,
      collectionDescription: collectionDescription ?? this.collectionDescription,
      kind: kind ?? this.kind,
      ownerUsername: ownerUsername ?? this.ownerUsername,
      numOfViewers: numOfViewers ?? this.numOfViewers,
    );
  }


  factory SharedCollectionUiModel.fromJson(Map<String, dynamic> json, {CollectionKind? kind}) {
  String pickString(List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return '';
  }

  return SharedCollectionUiModel(
    id: (json['_id'] ?? json['id'] ?? json['collectionId'] ?? '').toString(),
    collectionName: pickString(['collectionName', 'name', 'title', 'collection_name']),
    collectionDescription: pickString(['collectionDescription', 'description', 'desc', 'collection_description']),
    ownerUsername: (json['ownerUsername'] ?? json['owner'] ?? json['owner_username'])?.toString(),
    numOfViewers: (json['numOfViewers'] ?? json['views']) is int ? json['numOfViewers'] : null,
    kind: kind ?? CollectionKind.owned,
  );
}


  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "collectionName": collectionName,
      "collectionDescription": collectionDescription,
      if (numOfViewers != null) "numOfViewers": numOfViewers,
    
    };
  }
}

// ================================
// Shared Collection Details screen
// ================================
class CollectionsDetailsUiModel {
  final String id;
  final String collectionName;
  final String collectionDescription;

  final String ownerUsername;
  final int numOfViewers;
  final bool isOwned;
  final List<MemberModel> members;

  const CollectionsDetailsUiModel({
    required this.id,
    required this.collectionName,
    required this.collectionDescription,
    required this.ownerUsername,
    required this.numOfViewers,
    required this.isOwned,
    required this.members,
  });

  factory CollectionsDetailsUiModel.fromJson(
    Map<String, dynamic> json, {
    required bool isOwned,
  }) {
    final rawMembers = (json["members"] as List?) ?? const [];

    return CollectionsDetailsUiModel(
      id: _readId(json),
      collectionName: (json["collectionName"] ?? "").toString(),
      collectionDescription: (json["collectionDescription"] ?? "").toString(),
      ownerUsername: (json["ownerUsername"] ?? "").toString(),
      numOfViewers: _readInt(json["numOfViewers"]) ?? 0,
      isOwned: isOwned,
      members: rawMembers
          .whereType<Map>()
          .map((m) => MemberModel.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "collectionName": collectionName,
      "collectionDescription": collectionDescription,
      "ownerUsername": ownerUsername,
      "numOfViewers": numOfViewers,
      "isOwned": isOwned,
      "members": members.map((m) => m.toJson()).toList(),
    };
  }
}


// ================================
// Explore screen
// ================================
enum JoinState { notJoined, requested }

class ExploreCollectionUiModel {
  final String id;
  final String collectionName;
  final String collectionDescription;

  final String? ownerUsername;
  final int? numOfViewers;
  final String joinStatus;

  const ExploreCollectionUiModel({
    required this.id,
    required this.collectionName,
    required this.collectionDescription,
    this.ownerUsername,
    this.numOfViewers,
    this.joinStatus = 'none', 
  });

  JoinState get joinState =>
      joinStatus == 'pending' ? JoinState.requested : JoinState.notJoined;

  ExploreCollectionUiModel copyWith({
    String? id,
    String? collectionName,
    String? collectionDescription,
    String? ownerUsername,
    int? numOfViewers,
    String? joinStatus,
  }) {
    return ExploreCollectionUiModel(
      id: id ?? this.id,
      collectionName: collectionName ?? this.collectionName,
      collectionDescription: collectionDescription ?? this.collectionDescription,
      ownerUsername: ownerUsername ?? this.ownerUsername,
      numOfViewers: numOfViewers ?? this.numOfViewers,
      joinStatus: joinStatus ?? this.joinStatus,
    );
  }

  factory ExploreCollectionUiModel.fromJson(Map<String, dynamic> json) {
    return ExploreCollectionUiModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      collectionName: (json['collectionName'] ?? '').toString(),
      collectionDescription: (json['collectionDescription'] ?? '').toString(),
      ownerUsername: json['ownerUsername']?.toString(),
      numOfViewers: json['numOfViewers'] is int ? json['numOfViewers'] as int : null,
      joinStatus: (json['joinStatus'] ?? 'none').toString(),
    );
  }
}