import 'package:century_ai/router/router.dart';
import 'package:century_ai/utils/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:century_ai/utils/helpers/network_manager.dart';
import 'package:century_ai/utils/popups/loaders.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(

      providers: [
        BlocProvider(create: (_) => NetworkCubit()),
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
    );
  }
}
