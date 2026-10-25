import 'api_client.dart';
import 'endpoints.dart';

class ProfileApi {
  final ApiClient _api;
  ProfileApi(this._api);

  Future<Map<String, dynamic>> getMyProfile() {
    return _api.getMap(Endpoints.usersProfile, auth: true);
  }

  Future<Map<String, dynamic>> updateMyProfile(Map<String, dynamic> body) {
    return _api.patchMap(Endpoints.usersProfile, data: body, auth: true);
  }

  Future<Map<String, dynamic>> addInterests(List<String> interests) {
    return _api.postMap(Endpoints.usersInterest, data: {'interests': interests}, auth: true);
  }

  Future<Map<String, dynamic>> removeInterest(String interestKey) {
    return _api.deleteMap('${Endpoints.usersInterestRemove}/$interestKey', auth: true);
  }

  Future<Map<String, dynamic>> deleteMyProfile() {
    return _api.deleteMap(Endpoints.usersProfile, auth: true);
  }
}
