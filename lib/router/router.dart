import 'dart:io';



import 'package:century_ai/features/authentication/screens/onboarding.dart';
import 'package:century_ai/features/camera_pages/camera_pages_index.dart';
import 'package:century_ai/features/camera_pages/image_edit_page.dart';
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
    GoRoute(
      path: "/camera",
      name: "camera",
      builder: (context, state) => CameraPagesIndex(),
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
        ),
        // GoRoute(
        //   path: "/camera",
        //   name: "camera",
        //   builder: (context, state) => CameraIndex(),
        // ),
        GoRoute(
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
        final File imageFile = state.extra as File;
        return ImageEditPage(imageFile: imageFile);
      },
    ),

  ],
);
