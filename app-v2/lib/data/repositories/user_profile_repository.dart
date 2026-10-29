import 'package:century_ai/data/models/user_profile_model.dart';
import 'package:century_ai/data/services/api_service.dart';

class UserProfileRepository {
  final ApiService _apiService;

  UserProfileRepository(this._apiService);

  Future<UserProfileModel> getProfile({int userId = 1}) async {
    final response = await _apiService.getUserById(userId);
    return UserProfileModel.fromJson(response);
  }

  Future<UserProfileModel> updateProfile(UserProfileModel profile) async {
    final response = await _apiService.updateUserById(
      profile.id,
      profile.toUpdatePayload(),
    );
    return UserProfileModel.fromJson(response);
  }
}
