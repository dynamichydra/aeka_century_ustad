import 'package:equatable/equatable.dart';
import '../../data/models/avatar_model.dart';

class AvatarState extends Equatable {
  final bool isLoading;
  final List<AvatarModel> avatars;
  final String? error;

  const AvatarState({
    this.isLoading = false,
    this.avatars = const [],
    this.error,
  });

  AvatarState copyWith({
    bool? isLoading,
    List<AvatarModel>? avatars,
    String? error,
  }) {
    return AvatarState(
      isLoading: isLoading ?? this.isLoading,
      avatars: avatars ?? this.avatars,
      error: error,
    );
  }

  @override
  List<Object?> get props => [isLoading, avatars, error];
}
