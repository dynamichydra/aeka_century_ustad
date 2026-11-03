import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/db/models/user_profile_data.dart';
import 'package:century_ai/db/repositories/local_user_profile_repository.dart';
import 'package:flutter/material.dart';

/// Round picture of the signed-in user: their saved profile photo, or the
/// default avatar when they have not added one. Updates when the profile is
/// saved.
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
                : Image.asset(TImages.user, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}
