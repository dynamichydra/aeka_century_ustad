import 'package:equatable/equatable.dart';

class HomeState extends Equatable {
  final bool isExterior;
  final bool isTrendingShowing;
  final bool isLikedShowing;
  final int selectedIndex;
  final String searchQuery;
  final bool isLoading;

  const HomeState({
    this.isExterior = true,
    this.isTrendingShowing = false,
    this.isLikedShowing = false,
    this.selectedIndex = 0,
    this.searchQuery = '',
    this.isLoading = false,
  });

  HomeState copyWith({
    bool? isExterior,
    bool? isTrendingShowing,
    bool? isLikedShowing,
    int? selectedIndex,
    String? searchQuery,
    bool? isLoading,
  }) {
    return HomeState(
      isExterior: isExterior ?? this.isExterior,
      isTrendingShowing: isTrendingShowing ?? this.isTrendingShowing,
      isLikedShowing: isLikedShowing ?? this.isLikedShowing,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        isExterior,
        isTrendingShowing,
        isLikedShowing,
        selectedIndex,
        searchQuery,
        isLoading,
      ];
}
