import 'dart:io';
import 'dart:ui';

import 'package:century_ai/db/repositories/local_user_profile_repository.dart';
import 'package:century_ai/features/auth/data/auth_storage.dart';
import 'package:century_ai/features/auth/presentation/pages/login_page.dart';
import 'package:century_ai/features/auth/presentation/pages/onboarding_page.dart';
import 'package:century_ai/features/auth/presentation/pages/otp_page.dart';
import 'package:century_ai/features/auth/presentation/pages/profile_setup_page.dart';
import 'package:century_ai/features/camera_pages/camera_pages.dart';
import 'package:century_ai/features/home/home.dart';
import 'package:century_ai/features/home/presentation/pages/home_2.dart';
import 'package:century_ai/router/app_routes.dart';
import 'package:century_ai/router/shell_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:century_ai/cubit/image_edit/image_edit_cubit.dart';
import 'package:century_ai/cubit/products/products_cubit.dart';
import 'package:century_ai/data/repositories/product_repository.dart';

final GoRouter router = GoRouter(
  // Signed-in users go straight home; everyone else to login. Onboarding is
  // switched off for now (its route still exists).
  // Firebase restores the signed-in user during Firebase.initializeApp in
  // main(), before the router is first read.
  // Signed-in users without a complete profile go to profile setup first;
  // main() loads that flag before the router is read.
  initialLocation: !AuthStorage.isLoggedIn
      ? AppRoutes.login
      : LocalUserProfileRepository.currentUserComplete
      ? AppRoutes.home
      : AppRoutes.profileSetup,
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
        ),
        GoRoute(
          path: AppRoutes.home2,
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
    GoRoute(
      path: AppRoutes.onboarding,
      name: "onboarding",
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: AppRoutes.login,
      name: "login",
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: AppRoutes.otp,
      name: "otp",
      builder: (context, state) => OtpPage(phone: state.extra as String? ?? ''),
    ),
    GoRoute(
      path: AppRoutes.profileSetup,
      name: "profile setup",
      builder: (context, state) => const ProfileSetupPage(),
    ),
    GoRoute(
      path: AppRoutes.profile,
      name: "profile",
      builder: (context, state) => const ProfileSetupPage(viewMode: true),
    ),
    GoRoute(
      path: AppRoutes.imagePreview,
      name: "Image Preview",
      builder: (context, state) {
        File? imageFile;
        String imageCategory = "";
        String? subCategory;
        String? image_id;
        String? applicationType;
        String? originalImageUrl;
        String? imageUrl;

        if (state.extra is File) {
          imageFile = state.extra as File;
        } else if (state.extra is Map<String, dynamic>) {
          final data = state.extra as Map<String, dynamic>;
          imageFile = data["imageFile"] as File?;
          imageCategory = data["image_category"] as String? ?? "";
          subCategory = data["sub_category"] as String?;
          image_id = data["image_id"] as String?;
          originalImageUrl = data["originalImageUrl"] as String?;
          imageUrl = data["imageUrl"] as String?;
          // Support both new applicationType string and legacy isExterior bool
          applicationType =
              data["applicationType"] as String? ??
              ((data["isExterior"] as bool? ?? false)
                  ? "EXTERIOR"
                  : "INTERIOR");
        }

        if (imageFile == null) {
          return Scaffold(
            body: Center(child: Text("Error: No image provided")),
          );
        }

        return BlocProvider(
          create: (context) => ProductsCubit(context.read<ProductRepository>()),
          child: ImagePreviewPage(
            imageFile: imageFile,
            image_category: imageCategory,
            sub_category: subCategory,
            image_id: image_id,
            originalImageUrl: originalImageUrl,
            imageUrl: imageUrl,
            applicationType: applicationType,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.imageUploadPreview,
      name: "Image Upload Preview",
      builder: (context, state) {
        File? imageFile;
        String imageCategory = "";
        String? subCategory;

        if (state.extra is Map<String, dynamic>) {
          final data = state.extra as Map<String, dynamic>;
          imageFile = data["imageFile"] as File?;
          imageCategory = data["image_category"] as String? ?? "";
          subCategory = data["sub_category"] as String?;
        }

        if (imageFile == null) {
          return Scaffold(
            body: Center(child: Text("Error: No image provided")),
          );
        }

        return BlocProvider(
          create: (context) => ProductsCubit(context.read<ProductRepository>()),
          child: ImageUploadPreviewPage(
            imageFile: imageFile,
            image_category: imageCategory,
            sub_category: subCategory,
          ),
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
        String? originalImageUrl;
        String? imageUrl;
        bool isExterior = false;

        if (state.extra is File) {
          imageFile = state.extra as File;
        } else if (state.extra is Map<String, dynamic>) {
          final data = state.extra as Map<String, dynamic>;
          imageFile = data['imageFile'] as File?;
          pickedColor = data['pickedColor'] as Color?;
          image_id = data['image_id'] as String?;
          originalImageUrl = data['originalImageUrl'] as String?;
          imageUrl = data['imageUrl'] as String?;
          // Support both new applicationType string and legacy isExterior bool
          final appType = data['applicationType'] as String?;
          isExterior = appType != null
              ? appType.toUpperCase() == 'EXTERIOR'
              : (data['isExterior'] as bool? ?? false);
        }

        if (imageFile == null) {
          return Scaffold(
            body: Center(child: Text("Error: No image for editing")),
          );
        }

        return BlocProvider(
          create: (_) => ImageEditCubit(),
          child: ImageEditPage(
            imageFile: imageFile,
            pickedColor: pickedColor,
            image_id: image_id,
            originalImageUrl: originalImageUrl,
            imageUrl: imageUrl,
            isExterior: isExterior,
          ),
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
        String? originalImageUrl;
        String? imageUrl;
        bool isExterior = false;

        if (state.extra is File) {
          imageFile = state.extra as File;
        } else if (state.extra is Map<String, dynamic>) {
          final data = state.extra as Map<String, dynamic>;
          imageFile = data['imageFile'] as File?;
          pickedColor = data['pickedColor'] as Color?;
          image_id = data['image_id'] as String?;
          originalImageUrl = data['originalImageUrl'] as String?;
          imageUrl = data['imageUrl'] as String?;
          // Support both new applicationType string and legacy isExterior bool
          final appType = data['applicationType'] as String?;
          isExterior = appType != null
              ? appType.toUpperCase() == 'EXTERIOR'
              : (data['isExterior'] as bool? ?? false);
        }

        if (imageFile == null) {
          return Scaffold(
            body: Center(child: Text("Error: No image for editing")),
          );
        }

        return BlocProvider(
          create: (_) => ImageEditCubit(),
          child: ImageEditScrollPage(
            imageFile: imageFile,
            pickedColor: pickedColor,
            image_id: image_id,
            originalImageUrl: originalImageUrl,
            imageUrl: imageUrl,
            isExterior: isExterior,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.imageColorPicker,
      name: "Image Color Picker",
      builder: (context, state) {
        File? imageFile;
        File? originalImage;

        if (state.extra is File) {
          imageFile = state.extra as File;
        } else if (state.extra is Map<String, dynamic>) {
          final data = state.extra as Map<String, dynamic>;
          imageFile = data['imageFile'] as File?;
          originalImage = data['originalImage'] as File?;
        }

        if (imageFile == null) {
          return Scaffold(
            body: Center(child: Text("Error: No image for color picking")),
          );
        }

        return ImageColorPickerPage(
          imageFile: imageFile,
          originalImage: originalImage,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.imageFinalize,
      name: "Image Finalize",
      builder: (context, state) {
        if (state.extra is! Map<String, dynamic>) {
          return const Scaffold(
            body: Center(child: Text("Error: Missing data for finalization")),
          );
        }
        final data = state.extra as Map<String, dynamic>;
        return ImageFinalizePage(
          editedImage: data['editedImage'],
          usedLaminates:
              data['usedLaminates'] as List<Map<String, dynamic>>? ?? [],
        );
      },
    ),
    GoRoute(
      path: AppRoutes.compare,
      name: "compare",
      builder: (context, state) {
        File? originalImage;
        String? furnitureId;
        String? sessionId;

        if (state.extra is File) {
          originalImage = state.extra as File;
        } else if (state.extra is Map<String, dynamic>) {
          final data = state.extra as Map<String, dynamic>;
          originalImage = data['originalImage'] as File?;
          furnitureId = data['furnitureId'] as String?;
          sessionId = data['sessionId'] as String?;
        }

        if (originalImage == null) {
          return Scaffold(
            body: Center(child: Text("Error: No image for comparison")),
          );
        }

        return CompareImagePage(
          originalImage: originalImage,
          furnitureId: furnitureId,
          sessionId: sessionId,
        );
      },
    ),
  ],
);
