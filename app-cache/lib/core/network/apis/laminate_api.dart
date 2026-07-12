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
      "findBySKUId/search",
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
    String itemType = "Laminates",
    int limit = 5,
  }) async {

    var res = await api.post(
      "/find-nearest-laminates",
      {
        "hexcode": hexCodes.join(","),
        "itemType": itemType,
        "limit_results": limit,
      },
    );

    return res;
  }

  /// Fetch By Category (Paginated)
  Future<dynamic> fetchByCategory({
    required String category,
    required String subcategory,
    String itemType = "Laminates",
    int? page,
    int? pageLimit,
  }) async {

    final Map<String, dynamic> body = {
      "category": category,
      "itemType": itemType,
    };

    if (subcategory.isNotEmpty && subcategory != "All") {
      body["subcategory"] = subcategory;
    } else {
      body["subcategory"] = false;
    }

    if (page != null) {
      body["page"] = page;
    }
    if (pageLimit != null) {
      body["pageLimit"] = pageLimit;
    }

    var res = await api.post(
      "findByCategory/paginated",
      body,
    );

    return res;
  }

  /// Daily Sync Incremental
  Future<dynamic> fetchIncremental({
    required String date,
    int? page,
    int? pageLimit,
  }) async {
    final Map<String, dynamic> body = {
      "date": date,
    };

    if (page != null) {
      body["page"] = page;
    }
    if (pageLimit != null) {
      body["pageLimit"] = pageLimit;
    }

    var res = await api.post(
      "laminates/incremental",
      body,
    );

    return res;
  }
}