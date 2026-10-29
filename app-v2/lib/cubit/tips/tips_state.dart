import 'package:century_ai/data/models/tip_model.dart';
import 'package:equatable/equatable.dart';

class TipsState extends Equatable {
  final bool isLoading;
  final List<TipModel> tips;
  final String? errorMessage;

  const TipsState({
    this.isLoading = false,
    this.tips = const <TipModel>[],
    this.errorMessage,
  });

  TipsState copyWith({
    bool? isLoading,
    List<TipModel>? tips,
    String? errorMessage,
  }) {
    return TipsState(
      isLoading: isLoading ?? this.isLoading,
      tips: tips ?? this.tips,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [isLoading, tips, errorMessage];
}
