//Frontend/lib/core/api/shared_collection_api.dart
import 'api_client.dart';
import 'endpoints.dart';

class SharedCollectionApi {
  final ApiClient _api;
  SharedCollectionApi(this._api);

  // =========================================================
  // CREATE COLLECTION
  // POST /api/shared-collections/createCollection
  // =========================================================
  Future<Map<String, dynamic>> createCollection({
    required String collectionName,
    required String collectionDescription,
  }) async {
    return _api.post(
      Endpoints.createCollection,
      auth: true,
      data: {
        'collectionName': collectionName,
        'collectionDescription': collectionDescription,
      },
    );
  }
  // =========================================================
  // GET OTHERS COLLECTIONS
  // GET /api/shared-collections/getOthersCollections
  // =========================================================
  Future<List<dynamic>> getOthersCollections({bool auth = true}) async {
    return _api.getList(Endpoints.getOthersCollections, auth: auth);
  }

  // =========================================================
  // GET OWNED COLLECTIONS
  // GET /api/shared-collections/getOwnedCollections
  // =========================================================
  Future<List<dynamic>> getOwnedCollections({bool auth = true}) async {
    return _api.getList(Endpoints.getOwnedCollections, auth: auth);
  }

  // =========================================================
  // GET JOINED COLLECTIONS
  // GET /api/shared-collections/getJoinedCollections
  // =========================================================
  Future<List<dynamic>> getJoinedCollections({bool auth = true}) async {
    return _api.getList(Endpoints.getJoinedCollections, auth: auth);
  }

  // =========================================================
  // GET CollectionDetails COLLECTIONS
  // GET /api/shared-collections/$id/getCollectionDetails
  // =========================================================
Future<Map<String, dynamic>> getCollectionDetails(String collectionId,
    {bool auth = true}) async {
  return _api.getMap(
    '${Endpoints.getCollectionDetails}?id=$collectionId',
    auth: auth,
  );
}


  // =========================================================
  // INCREMENT VIEW
  // POST /api/shared-collections/:id/incrementView
  // =========================================================
  Future<Map<String, dynamic>> incrementView(String collectionId, {bool auth = true}) async {
    return _api.post(Endpoints.incrementCollectionView(collectionId), auth: auth);
  }

  // =========================================================
  // UPDATE COLLECTION
  // PATCH /api/shared-collections/:id/updateCollection
  // body: { collectionName?, collectionDescription? }
  // =========================================================
  Future<Map<String, dynamic>> updateCollection(
    String collectionId, {
    String? collectionName,
    String? collectionDescription,
  }) async {
    return _api.patch(
      Endpoints.updateCollection(collectionId),
      auth: true,
      data: {
        'collectionName': collectionName,
        'collectionDescription': collectionDescription,
      },
    );
  }

  // =========================================================
  // DELETE COLLECTION
  // DELETE /api/shared-collections/:id/deleteCollection
  // =========================================================
  Future<Map<String, dynamic>> deleteCollection(String collectionId) async {
    return _api.delete(
      Endpoints.deleteCollection(collectionId),
      auth: true,
    );
  }

  // =========================================================
  // CREATE Join Request
  // POST /api/shared-collections/$collectionId/joinRequests/create
  // =========================================================

Future<Map<String, dynamic>> createJoinRequest(String collectionId, {bool auth = true}) async {
  return _api.post(
    Endpoints.createJoinRequest(collectionId),
    auth: auth,
    data: {},
  );
}

 // =========================================================
  // Decide Join Request (Accept/Reject)
  // PATCH /api/shared-collections/$collectionId/joinRequests/$requestId/decide
  // =========================================================

Future<Map<String, dynamic>> decideJoinRequest(
  String collectionId,
  String requestId, {
  required String decision, // "accept" | "reject"
  bool auth = true,
}) {
  return _api.patch(
    Endpoints.decideJoinRequest(collectionId, requestId),
    auth: auth,
    data: {'decision': decision},
  );
}

 // =========================================================
  // GET All Join Request
  // GET /api/shared-collections/$collectionId/joinRequests
  // =========================================================


Future<Map<String, dynamic>> getJoinRequests(String collectionId, {bool auth = true}) async {
  return _api.get(
    Endpoints.getJoinRequests(collectionId),
    auth: auth,
  );
}

  // =========================================================
  // Report an added news
  // POST /api/sharedCollections/$collectionId/addedNews/$addedNewsId/report
  // =========================================================

 Future<Map<String, dynamic>> reportAddedNews(
    String collectionId,
    String addedNewsId, {
    required String reportReason,
    bool auth = true,
  }) {
    return  _api.post(
       Endpoints.createReport(collectionId, addedNewsId),
      data: {'reportReason': reportReason},
      auth: auth,
    );
  }

  // =========================================================
  // Get all reports to Creator
  // GET /api/sharedCollections/$collectionId/reports
  // =========================================================

  Future<Map<String, dynamic>> getReports(
    String collectionId, {
    bool auth = true,
  }) {
    return _api.get(
      Endpoints.getReports(collectionId),
      auth: auth,
    );
  }
// =========================================================
// Add article to shared collection
// POST /api/shared-collections/$collectionId/addArticle
// =========================================================
Future<Map<String, dynamic>> addArticleToCollection(
  String collectionId, {
  required String originalNewsId,
  bool auth = true,
}) {
  return _api.post(
    Endpoints.addArticleToCollection(collectionId),
    auth: auth,
    data: {
      'originalNewsId': originalNewsId,
    },
  );
}

// =========================================================
// DELETE ADDED NEWS
// DELETE /api/shared-collections/$collectionId/addedNews/$addedNewsId
// =========================================================
Future<Map<String, dynamic>> deleteAddedNews(
  String collectionId,
  String addedNewsId, {
  bool auth = true,
}) async {
  return _api.delete(
    Endpoints.deleteAddedNews(collectionId, addedNewsId),
    auth: auth,
  );
}

// =========================================================
// Archive Addded News
// PATCH /api/shared-collections/$collectionId/addedNews/$addedNewsId/archive
// =========================================================

Future<Map<String, dynamic>> archiveAddedNews(
  String collectionId,
  String addedNewsId, {
  bool auth = true,
}) {
  return _api.patch(
    Endpoints.archiveAddedNews(collectionId, addedNewsId),
    auth: auth,
    data: {},
  );
}

// =========================================================
// Restore Archived Addded News
// PATCH /api/shared-collections/$collectionId/addedNews/$addedNewsId/restore
// =========================================================
Future<Map<String, dynamic>> restoreAddedNews(
  String collectionId,
  String addedNewsId, {
  bool auth = true,
}) {
  return _api.patch(
    Endpoints.restoreAddedNews(collectionId, addedNewsId),
    auth: auth,
    data: {},
  );
}

// =========================================================
// Get Archived Addded News
// GET /api/shared-collections/$collectionId/archivedNews
// =========================================================
Future<Map<String, dynamic>> getArchivedNews(
  String collectionId, {
  bool auth = true,
}) {
  return _api.get(
    Endpoints.getArchivedNews(collectionId),
    auth: auth,
  );
}
// =========================================================
// GET ADDED NEWS SUMMARY
// GET /api/shared-collections/$collectionId/addedNews/$addedNewsId/summary
// =========================================================
Future<Map<String, dynamic>> getAddedNewsSummary(
  String collectionId,
  String addedNewsId, {
  bool auth = true,
}) {
  return _api.get(
    Endpoints.getAddedNewsSummary(collectionId, addedNewsId),
    auth: auth,
  );
}

// =========================================================
// GET ADDED NEWS AUDIO
// GET /api/shared-collections/$collectionId/addedNews/$addedNewsId/audio?mode=$mode
// =========================================================
Future<Map<String, dynamic>> getAddedNewsAudio(
  String collectionId,
  String addedNewsId, {
  required String mode,
  bool auth = true,
}) {
  return _api.get(
    Endpoints.getAddedNewsAudio(collectionId, addedNewsId, mode),
    auth: auth,
  );
}

// =========================================================
// LEAVE COLLECTION
// DELETE /api/shared-collections/$collectionId/members/leave
// =========================================================
Future<Map<String, dynamic>> leaveCollection(
  String collectionId, {
  bool auth = true,
}) async {
  return _api.delete(
    Endpoints.leaveCollection(collectionId),
    auth: auth,
  );
}

// =========================================================
// DELETE MEMBER
// DELETE /api/shared-collections/$collectionId/members/$memberId
// =========================================================
Future<Map<String, dynamic>> deleteMember(
  String collectionId,
  String memberId,
) async {
  return _api.delete(
    Endpoints.deleteMember(collectionId, memberId),
    auth: true,
  );
}

// =========================================================
// GET SHARE LINK
// GET /api/shared-collections/$collectionId/share-link
// =========================================================
Future<Map<String, dynamic>> getShareLink(String collectionId) async {
  return _api.get(
    Endpoints.getShareLink(collectionId),
    auth: true,
  );
}

}