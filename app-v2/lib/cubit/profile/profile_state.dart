import 'package:century_ai/data/models/user_profile_model.dart';
import 'package:equatable/equatable.dart';

class ProfileState extends Equatable {
  final bool isLoading;
  final bool isSaving;
  final UserProfileModel? profile;
  final String? errorMessage;
  final bool isSaved;

  const ProfileState({
    this.isLoading = false,
    this.isSaving = false,
    this.profile,
    this.errorMessage,
    this.isSaved = false,
  });

  ProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    UserProfileModel? profile,
    String? errorMessage,
    bool? isSaved,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
      isSaved: isSaved ?? false,
    );
  }

  @override
  List<Object?> get props => [isLoading, isSaving, profile, errorMessage, isSaved];
}
