import 'package:flutter/material.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';

enum NameAlignment { left, center, right }

class Profile extends StatelessWidget {
  const Profile({
    super.key,
    this.avatarRadius = 40,
    this.nameAlignment = NameAlignment.center,
    this.userName = 'Namaste Ramesh',
    this.needUserName = true
  });

  final double avatarRadius;
  final NameAlignment nameAlignment;
  final String userName;
  final bool needUserName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        /// ✅ IMAGE ALWAYS CENTER
        _AvatarWithBorder(radius: avatarRadius),

        const SizedBox(height: TSizes.spaceBtwItems),

        /// ✅ NAME ALIGNMENT ONLY
       if (needUserName)
          Align(
            alignment: _getNameAlignment(),
            child: Text(
              userName,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: _getTextAlign(),
            ),
          ),
      ],
    );
  }

  Alignment _getNameAlignment() {
    switch (nameAlignment) {
      case NameAlignment.left:
        return Alignment.centerLeft;
      case NameAlignment.right:
        return Alignment.centerRight;
      default:
        return Alignment.center;
    }
  }

  TextAlign _getTextAlign() {
    switch (nameAlignment) {
      case NameAlignment.left:
        return TextAlign.left;
      case NameAlignment.right:
        return TextAlign.right;
      default:
        return TextAlign.center;
    }
  }
}

class _AvatarWithBorder extends StatelessWidget {
  const _AvatarWithBorder({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Color(0xFFC5C3C3),
          shape: BoxShape.circle,
        ),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Color(0xFF9A9797),
            shape: BoxShape.circle,
          ),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF504B4B),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: radius,
              backgroundImage: const AssetImage(TImages.user),
            ),
          ),
        ),
      ),
    );
  }
}
