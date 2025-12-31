import 'dart:ffi';

import 'package:century_ai/features/ai_image/camera_index.dart';
import 'package:century_ai/features/ai_image/image_edit_page.dart';
import 'package:century_ai/features/authentication/screens/onboarding.dart';
import 'package:century_ai/features/home/screens/home.dart';
import 'package:century_ai/router/shell_route.dart';
import 'package:go_router/go_router.dart';

final GoRouter router = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const Onboarding(),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return NavWrapper(child: child); // persistent layout
      },
      routes: [
        GoRoute(
          path: "/",
          name: "home",
          builder: (context, state) => HomeScreen(),
        ), GoRoute(
          path: "/camera",
          name: "camera",
          builder: (context, state) => CameraIndex(),
        ), GoRoute(
          path: "/heart",
          name: "heart",
          builder: (context, state) => HomeScreen(),
        ),
        GoRoute(
          path: "/star",
          name: "star",
          builder: (context, state) => HomeScreen(),
        ),
      ],
    ),

    // Auth Pages
    // GoRoute(
    //   path: "/login",
    //   name: "login",
    //   builder: (context, state) => LoginPage(),
    // ),
    GoRoute(
      path: "/image_edit_page",
      name: "Image Edit Page",
      builder: (context, state) {
        final int id = state.extra as int;
        return ImageEditPage(id: id,);
      },
    ),

  ],
);
