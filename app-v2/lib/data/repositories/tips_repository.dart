import 'package:century_ai/data/models/tip_model.dart';
import 'package:century_ai/data/services/api_service.dart';

class TipsRepository {
  final ApiService _apiService;

  TipsRepository(this._apiService);

  Future<List<TipModel>> getTips({int limit = 6}) async {
    try {
      final raw = await _apiService.getPosts(limit: limit);
      return raw
          .map<TipModel>(
            (item) => TipModel.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList();
    } catch (_) {
      return const <TipModel>[
        TipModel(
          id: '1',
          title: 'Capture clear images',
          body: 'Capture clear images in good lighting for accurate results.',
        ),
        TipModel(
          id: '2',
          title: 'Avoid blurry shots',
          body: 'Hold your phone steady and keep the lens clean.',
        ),
        TipModel(
          id: '3',
          title: 'Avoid dim lighting',
          body: 'Use natural light or a bright white light source.',
        ),
      ];
    }
  }
}
