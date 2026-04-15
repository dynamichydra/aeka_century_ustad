import 'dart:io';
import 'dart:ui';

import 'package:century_ai/features/camera_pages/camera_pages.dart';
import 'package:century_ai/features/home/home.dart';
import 'package:century_ai/features/home/presentation/pages/home_2.dart';
import 'package:century_ai/router/app_routes.dart';
import 'package:century_ai/router/shell_route.dart';
import 'package:go_router/go_router.dart';

final GoRouter router = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.camera,
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
          path: AppRoutes.home,
          name: "home",
          builder: (context, state) => HomeScreen(),
        ),        GoRoute(
          path: "/home_2",
          name: "home 2",
          builder: (context, state) => HomeScreen2(),
        ),
        GoRoute(
          path: AppRoutes.heart,
          name: "heart",
          builder: (context, state) => HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.star,
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
      path: AppRoutes.imagePreview,
      name: "Image Preview",
      builder: (context, state) {
        File? imageFile;
        String imageCategory = "";
        String? subCategory;
        String? image_id;

        if (state.extra is File) {
          imageFile = state.extra as File;
        } else if (state.extra is Map<String, dynamic>) {
          final data = state.extra as Map<String, dynamic>;
          imageFile = data["imageFile"] as File?;
          imageCategory = data["image_category"] as String? ?? "";
          subCategory = data["sub_category"] as String?;
          image_id = data["image_id"] as String?;
        }

        return ImagePreviewPage(
          imageFile: imageFile!,
          image_category: imageCategory,
          sub_category: subCategory,
          image_id: image_id,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.imageEdit,
      name: "Image Edit Page",
      builder: (context, state) {
        File? imageFile;
        Color? pickedColor;
        String? image_id;

        if (state.extra is File) {
          imageFile = state.extra as File;
        } else if (state.extra is Map<String, dynamic>) {
          final data = state.extra as Map<String, dynamic>;
          imageFile = data['imageFile'] as File?;
          pickedColor = data['pickedColor'] as Color?;
          image_id = data['image_id'] as String?;
        }

        return ImageEditPage(
          imageFile: imageFile!,
          pickedColor: pickedColor,
          image_id: image_id,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.imageEditScroll,
      name: "Image Edit Scroll Page",
      builder: (context, state) {
        File? imageFile;
        Color? pickedColor;
        String? image_id;

        if (state.extra is File) {
          imageFile = state.extra as File;
        } else if (state.extra is Map<String, dynamic>) {
          final data = state.extra as Map<String, dynamic>;
          imageFile = data['imageFile'] as File?;
          pickedColor = data['pickedColor'] as Color?;
          image_id = data['image_id'] as String?;
        }

        return ImageEditScrollPage(
          imageFile: imageFile!,
          pickedColor: pickedColor,
          image_id: image_id,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.imageColorPicker,
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
      path: AppRoutes.imageFinalize,
      name: "Image Finalize",
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return ImageFinalizePage(
          editedImage: data['editedImage'],
          selectedColor: data['selectedColor'] as Map<String, dynamic>,
          selectedLamination:
              data['selectedLamination'] as Map<String, dynamic>,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.compare,
      name: "compare",
      builder: (context, state) {
        File? originalImage;
        if (state.extra is File) {
          originalImage = state.extra as File;
        } else if (state.extra is Map<String, dynamic>) {
          originalImage =
              (state.extra as Map<String, dynamic>)['originalImage'] as File?;
        }
        return CompareImagePage(originalImage: originalImage!);
      },
    ),
  ],
);
