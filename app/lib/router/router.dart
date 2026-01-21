import 'dart:io';
import 'dart:ui';

import 'package:century_ai/features/authentication/screens/onboarding.dart';
import 'package:century_ai/features/camera_pages/camera_pages_index.dart';
import 'package:century_ai/features/camera_pages/image_edit_page.dart';
import 'package:century_ai/features/camera_pages/image_color_picker.dart';
import 'package:century_ai/features/camera_pages/image_finalize_page.dart';
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
      builder: (context, state) {
        bool fromColorPicker = false;
        File? originalImage;
        
        if (state.extra is bool) {
          fromColorPicker = state.extra as bool;
        } else if (state.extra is Map<String, dynamic>) {
          final data = state.extra as Map<String, dynamic>;
          fromColorPicker = data['fromColorPicker'] as bool? ?? false;
          originalImage = data['originalImage'] as File?;
        }
        
        return CameraPagesIndex(
          fromColorPicker: fromColorPicker,
          originalImage: originalImage,
        );
      },
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
        File? imageFile;
        Color? pickedColor;
        
        if (state.extra is File) {
          imageFile = state.extra as File;
        } else if (state.extra is Map<String, dynamic>) {
          final data = state.extra as Map<String, dynamic>;
          imageFile = data['imageFile'] as File?;
          pickedColor = data['pickedColor'] as Color?;
        }
        
        return ImageEditPage(
          imageFile: imageFile!,
          pickedColor: pickedColor,
        );
      },
    ),
    GoRoute(
      path: "/image_color_picker",
      name: "Image Color Picker",
      builder: (context, state) {
        File? imageFile;
        File? originalImage;
        
        if (state.extra is Map<String, dynamic>) {
          final data = state.extra as Map<String, dynamic>;
          imageFile = data['imageFile'] as File?;
          originalImage = data['originalImage'] as File?;
        }
        
        return ImageColorPickerPage(
          imageFile: imageFile!,
          originalImage: originalImage,
        );
      },
    ),
    GoRoute(
      path: "/image_finalize",
      name: "Image Finalize",
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return ImageFinalizePage(
          editedImage: data['editedImage'] as File,
          selectedColor: data['selectedColor'] as Map<String, dynamic>,
          selectedLamination: data['selectedLamination'] as Map<String, dynamic>,
        );
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
