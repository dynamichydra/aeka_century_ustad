import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/cubit/home/home_cubit.dart';
import 'package:century_ai/cubit/products/products_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onCategoryCleared;
  final void Function(String query) onSearchStarted;
  final bool isExterior;

  const HomeSearchBar({
    super.key,
    required this.controller,
    required this.onCategoryCleared,
    required this.onSearchStarted,
    this.isExterior = false,
  });

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  late bool _isSearching;

  @override
  void initState() {
    super.initState();
    _isSearching = false; // Always start with search icon
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  void _handleControllerChange() {
    // Only revert back to "Search" icon if the text becomes empty
    if (widget.controller.text.isEmpty && _isSearching) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _clearSearch() {
    widget.controller.clear();
    setState(() {
      _isSearching = false;
    });
    context.read<HomeCubit>().clearSearch();
    context.read<ProductsCubit>().fetchFeaturedProducts();
  }

  void _performSearch() {
    final query = widget.controller.text;
    if (query.isNotEmpty) {
      // Dismiss the keyboard
      FocusScope.of(context).unfocus();
      
      setState(() {
        _isSearching = true;
      });
      widget.onCategoryCleared();
      widget.onSearchStarted(query);
      context.read<HomeCubit>().fetchResults(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        cursorHeight: 15,
        style: const TextStyle(fontWeight: FontWeight.w100, fontSize: 13),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          suffixIconConstraints: const BoxConstraints(
            maxHeight: 40,
            maxWidth: 50,
          ),
          suffixIcon: GestureDetector(
            onTap: _isSearching ? _clearSearch : _performSearch,
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 4,
                    spreadRadius: 0,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: _isSearching
                    ? const Icon(
                        Icons.close,
                        size: 20,
                        color: TColors.primary,
                      )
                    : Image.asset(
                        "assets/icons/app_icons/ai_search.png",
                        width: 20,
                        height: 20,
                      ),
              ),
            ),
          ),
          hintText: widget.isExterior ? "Ai search" : "Ai based furniture idea search",
          hintStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w100,
            color: Color(0xFF5D5D5D),
          ),
        ),
        onChanged: (val) {
          context.read<HomeCubit>().setSearchQuery(val);
        },
        onSubmitted: (val) {
          if (val.isNotEmpty) {
            _performSearch();
          }
        },
      ),
    );
  }
}
