import 'package:equatable/equatable.dart';

class HomeState extends Equatable {
  final bool isExterior;
  final bool isTrendingShowing;
  final bool isLikedShowing;
  final int selectedIndex;
  final String searchQuery;

  const HomeState({
    this.isExterior = true,
    this.isTrendingShowing = false,
    this.isLikedShowing = false,
    this.selectedIndex = 0,
    this.searchQuery = '',
  });

  HomeState copyWith({
    bool? isExterior,
    bool? isTrendingShowing,
    bool? isLikedShowing,
    int? selectedIndex,
    String? searchQuery,
  }) {
    return HomeState(
      isExterior: isExterior ?? this.isExterior,
      isTrendingShowing: isTrendingShowing ?? this.isTrendingShowing,
      isLikedShowing: isLikedShowing ?? this.isLikedShowing,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
        isExterior,
        isTrendingShowing,
        isLikedShowing,
        selectedIndex,
        searchQuery,
      ];
}
