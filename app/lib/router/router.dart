import 'dart:io';

import 'package:century_ai/features/authentication/screens/onboarding.dart';
import 'package:century_ai/features/camera_pages/camera_pages_index.dart';
import 'package:century_ai/features/camera_pages/image_edit_page.dart';
import 'package:century_ai/features/home/screens/home.dart';
import 'package:century_ai/features/home/screens/product_explorer.dart';
import 'package:century_ai/features/home/screens/product_library.dart';
import 'package:century_ai/features/profile/profile_screent.dart';
import 'package:century_ai/features/search/search_page.dart';
import 'package:century_ai/router/shell_route.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
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
         GoRoute(
          path: "/search",
          name: "search",
          builder: (context, state) => const SearchScreen(),
        )
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
    GoRoute(
      path: "/product-explorer",
      name: "product-explorer",
      builder: (context, state) {
        final product = state.extra as ProductImageModel;
        return ProductExplorerScreen(selectedProduct: product);
      },
    ),
    GoRoute(
      path: "/product-library",
      name: "product-library",
      builder: (context, state) => const ProductLibraryScreen(),
    ),
    GoRoute(
      path: "/profile",
      name: "profile",
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);
