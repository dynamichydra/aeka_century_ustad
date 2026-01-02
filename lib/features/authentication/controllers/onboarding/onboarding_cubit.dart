import 'package:flutter_bloc/flutter_bloc.dart';

class OnboardingState {
  final int pageIndex;
  final bool isSecondImage;
  final bool isOtpStage;

  OnboardingState({
    required this.pageIndex,
    this.isSecondImage = false,
    this.isOtpStage = false,
  });
}

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit() : super(OnboardingState(pageIndex: 0));

  void updatePageIndicator(int index) =>
      emit(OnboardingState(pageIndex: index, isSecondImage: false, isOtpStage: false));

  void dotNavigationClick(int index) {
    emit(OnboardingState(pageIndex: index, isSecondImage: false, isOtpStage: false));
  }

  void setOtpStage(bool value) {
    emit(OnboardingState(
      pageIndex: state.pageIndex,
      isSecondImage: state.isSecondImage,
      isOtpStage: value,
    ));
  }

  void nextPage(bool hasSecondImage) {
    if (hasSecondImage && !state.isSecondImage) {
      emit(OnboardingState(pageIndex: state.pageIndex, isSecondImage: true, isOtpStage: false));
    } else {
      if (state.pageIndex < 2) {
        emit(OnboardingState(pageIndex: state.pageIndex + 1, isSecondImage: false, isOtpStage: false));
      }
    }
  }

  void skipPage() {
    emit(OnboardingState(pageIndex: 2, isSecondImage: false, isOtpStage: false));
  }
}


