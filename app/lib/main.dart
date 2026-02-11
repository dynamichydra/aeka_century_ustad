import 'package:century_ai/core/bootstrap/app_dependencies.dart';
import 'package:century_ai/cubit/auth/auth_cubit.dart';
import 'package:century_ai/cubit/products/products_cubit.dart';
import 'package:century_ai/cubit/profile/profile_cubit.dart';
import 'package:century_ai/cubit/tips/tips_cubit.dart';
import 'package:century_ai/router/router.dart';
import 'package:century_ai/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:century_ai/utils/helpers/network_manager.dart';
import 'package:century_ai/utils/popups/loaders.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_portal/flutter_portal.dart';

void main() {
  runApp(
    Portal(
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final AppDependencies _deps = AppDependencies.create();

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: _deps.authRepository),
        RepositoryProvider.value(value: _deps.userProfileRepository),
        RepositoryProvider.value(value: _deps.productRepository),
        RepositoryProvider.value(value: _deps.tipsRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => NetworkCubit()),
          BlocProvider(
            create: (_) => ProductsCubit(_deps.productRepository)..loadProducts(),
          ),
          BlocProvider(create: (_) => TipsCubit(_deps.tipsRepository)..loadTips()),
          BlocProvider(create: (_) => AuthCubit(_deps.authRepository)),
          BlocProvider(create: (_) => ProfileCubit(_deps.userProfileRepository)),
        ],
        child: BlocListener<NetworkCubit, List<ConnectivityResult>>(
          listener: (context, state) {
            if (state.contains(ConnectivityResult.none)) {
              TLoaders.customToast(
                context: context,
                message: 'No Internet Connection',
              );
            }
          },
          child: MaterialApp.router(
            title: 'Century Laminates',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.light,
            theme: TAppTheme.lightTheme,
            darkTheme: TAppTheme.darkTheme,
            routerConfig: router,
          ),
        ),
      ),
    );
  }
}
