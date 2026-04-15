import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/cubit/home/home_cubit.dart';
import 'package:century_ai/cubit/products/products_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onCategoryCleared;
  final VoidCallback onSearchStarted;

  const HomeSearchBar({
    super.key,
    required this.controller,
    required this.onCategoryCleared,
    required this.onSearchStarted,
  });

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  late bool _isSearching;

  @override
  void initState() {
    super.initState();
    _isSearching = false;
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
      setState(() {
        _isSearching = true;
      });
      widget.onCategoryCleared();
      widget.onSearchStarted();
      context.read<HomeCubit>().fetchResults(query);
      context.read<ProductsCubit>().searchProducts(query);
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
        style: const TextStyle(
          fontWeight: FontWeight.w100,
          fontSize: 13,
        ),
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
            maxHeight: 32,
            maxWidth: 44,
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
                        size: 16,
                        color: TColors.primary,
                      )
                    : Image.asset(
                        "assets/icons/app_icons/ai_search.png",
                        width: 16,
                        height: 16,
                      ),
              ),
            ),
          ),
          hintText: "Ai based furniture idea search",
          hintStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w100,
            color: Color(0xFF5D5D5D),
          ),
        ),
        onChanged: (val) {
          context.read<HomeCubit>().setSearchQuery(val);
          if (val.isEmpty) {
            setState(() {
              _isSearching = false;
            });
          }
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
