/* -- LIST OF Constants used in APIs -- */

class TApiConstants {
  static const String baseUrl =
      'https://decor-studio-api.centuryply.com/';

  // Furniture endpoints
  static const String featuredBrowse = '/browse/featured';
  static const String roomBrowse = '/browse/room';
  static const String groupBrowse = '/browse/group';
  static const String productBrowse = '/browse/product';
  static const String interiorBrowse = '/browse/interior';
  static const String exteriorBrowse = '/browse/exterior';
  static const String similarProducts = '/similar/products';
  static const String upload = '/upload';
  static const String searchSimilar = '/search/similar';
  static const String searchText = '/search/text';
  static const String trendingProducts = '/product/trending';
  static const String tryOn =
      'https://decor-studio-api.centuryply.com/tryon';
  static const String tryOnV2 =
      'https://decor-studio-api.centuryply.com/tryon-v2';
  static const String tryOnV3 =
      'https://decor-studio-api.centuryply.com/tryon-v3';

  static const String tryOnV4 =
      'https://decor-studio-api.centuryply.com/tryon/generate';

  static const String favorites = '/me/favourites';

  // Dummy endpoints (legacy)
  static const String products = '/products';
  static const String users = '/users';
  static const String posts = '/posts';
}
