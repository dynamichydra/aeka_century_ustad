import '../api_client.dart';

class LaminateService {

  final ApiClient api = ApiClient();

  /// Fetch By SKU
  Future<dynamic> fetchBySku({
    required String skuId,
    bool skusAllCode = false,
    String laminateType = "Laminates",
  }) async {

     var res = await api.post(
      "/findBySKUId",
      {
        "SKUId": skuId,
        "SKUsALLCode": skusAllCode,
        "LaminateType": laminateType,
      },
    );

     return res;
  }

  /// Fetch By Hex Code
  Future<dynamic> fetchByHex({
    required List<String> hexCodes,
    String itemType = "Exteria",
    int limit = 5,
  }) async {

    var res = await api.post(
      "/find-nearest-laminates",
      {
        "hexcode": hexCodes.join(","),
        "itemType": "Exteria",
        "limit_results": 10,
      },
    );

    return res;
  }

  /// Fetch By Category
  Future<dynamic> fetchByCategory({
    required String category,
    required String subcategory,
    String itemType = "Laminates",
  }) async {

    var res = await api.post(
      "/findByCategory",
      {
        "category": category,
        "subcategory": subcategory,
        "itemType": itemType,
      },
    );

    return res;
  }
}