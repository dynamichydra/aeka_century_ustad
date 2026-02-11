import 'package:century_ai/common/widgets/inputs/text_field.dart';
import 'package:century_ai/common/widgets/profile/profile.dart';
import 'package:century_ai/cubit/products/products_cubit.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:century_ai/features/search/presentation/widgets/search_result_items.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProductsCubit>().state;
    final products = state.products.isEmpty
        ? ProductImages.productImages
        : state.products;
    final normalized = _query.trim().toLowerCase();
    final filtered = normalized.isEmpty
        ? products
        : products.where((p) => p.name.toLowerCase().contains(normalized)).toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              elevation: 0,
              floating: true,
              snap: true,
              pinned: false,
              expandedHeight: 220,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Profile(
                        nameAlignment: NameAlignment.left,
                        avatarRadius: 20,
                      ),
                      const SizedBox(height: TSizes.sm),
                      _SearchInput(
                        onChanged: (value) {
                          setState(() => _query = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (state.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = filtered[index];
                  return SearchResultItem(
                    title: product.name,
                    image: product.image,
                  );
                }, childCount: filtered.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TTextField(
      labelText: 'Search',
      prefixIcon: const Icon(Icons.search),
      isCircularIcon: true,
      onChanged: onChanged,
    );
  }
}
