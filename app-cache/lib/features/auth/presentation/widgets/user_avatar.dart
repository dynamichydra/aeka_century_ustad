import 'package:century_ai/db/models/user_profile_data.dart';
import 'package:century_ai/db/repositories/local_user_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

/// Round picture of the signed-in user: their saved profile photo, or an
/// empty-user placeholder when they have not added one. Updates when the
/// profile is saved.
class UserAvatar extends StatelessWidget {
  final double size;

  const UserAvatar({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfileData?>(
      valueListenable: LocalUserProfileRepository.current,
      builder: (context, profile, _) {
        final file = LocalUserProfileRepository.photoFileSync(
          profile?.photoFileName,
        );
        return ClipOval(
          child: SizedBox(
            width: size,
            height: size,
            child: file != null
                ? Image.file(file, fit: BoxFit.cover)
                : EmptyUserAvatar(size: size),
          ),
        );
      },
    );
  }
}

/// Grey circle with a person outline, for users without a photo.
class EmptyUserAvatar extends StatelessWidget {
  final double size;

  const EmptyUserAvatar({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      alignment: Alignment.center,
      child: Icon(
        Iconsax.user,
        size: size * 0.5,
        color: const Color(0xFF9E9E9E),
      ),
    );
  }
}
