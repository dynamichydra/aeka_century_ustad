import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.isSearching,
    required this.onClear,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 0.8),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: "Search sku (e.g. 101G)",
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          prefixIcon: Icon(
            Symbols.search,
            size: 16,
            color: Colors.grey.shade600,
          ),
          suffixIcon: isSearching
              ? IconButton(
                  icon: Icon(
                    Symbols.close,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }
}
