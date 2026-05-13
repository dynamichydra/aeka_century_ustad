import 'package:century_ai/cubit/tips/tips_state.dart';
import 'package:century_ai/data/repositories/tips_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TipsCubit extends Cubit<TipsState> {
  final TipsRepository _tipsRepository;

  TipsCubit(this._tipsRepository) : super(const TipsState());

  Future<void> loadTips({int limit = 6}) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final tips = await _tipsRepository.getTips(limit: limit);
      emit(state.copyWith(isLoading: false, tips: tips));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }
}
