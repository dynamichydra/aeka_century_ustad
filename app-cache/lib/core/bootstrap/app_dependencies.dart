import 'package:century_ai/data/repositories/auth_repository.dart';
import 'package:century_ai/data/repositories/product_repository.dart';
import 'package:century_ai/data/repositories/tips_repository.dart';
import 'package:century_ai/data/repositories/user_profile_repository.dart';
import 'package:century_ai/data/services/api_service.dart';

class AppDependencies {
  final ApiService apiService;
  final AuthRepository authRepository;
  final UserProfileRepository userProfileRepository;
  final ProductRepository productRepository;
  final TipsRepository tipsRepository;

  AppDependencies._({
    required this.apiService,
    required this.authRepository,
    required this.userProfileRepository,
    required this.productRepository,
    required this.tipsRepository,
  });

  factory AppDependencies.create() {
    final api = ApiService();
    return AppDependencies._(
      apiService: api,
      authRepository: AuthRepository(api),
      userProfileRepository: UserProfileRepository(api),
      productRepository: ProductRepository(api),
      tipsRepository: TipsRepository(api),
    );
  }
}
