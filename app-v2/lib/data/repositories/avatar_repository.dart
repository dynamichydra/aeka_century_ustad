import '../models/avatar_model.dart';
import '../services/api_service.dart';

class AvatarRepository {
  final ApiService apiService;

  AvatarRepository(this.apiService);

  Future<List<AvatarModel>> getAvatars() async {
    final result = await apiService.fetchPeople();
    print("Results");
    print(result);
    return result.map<AvatarModel>((json) {
      return AvatarModel.fromJson(json);
    }).toList();
  }
}
