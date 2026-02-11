import 'package:century_ai/common/widgets/inputs/text_field.dart';
import 'package:century_ai/common/widgets/profile/profile.dart';
import 'package:century_ai/features/search/presentation/widgets/search_result_items.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  @override
  Widget build(BuildContext context) {
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
                    children: const [
                      Profile(
                        nameAlignment: NameAlignment.left,
                        avatarRadius: 20,
                      ),
                      SizedBox(height: TSizes.sm),
                      _SearchInput(),
                    ],
                  ),
                ),
              ),
            ),

            /// 🔽 LIST SECTION
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return const SearchResultItem();
                }, childCount: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}





class _SearchInput extends StatelessWidget {
  const _SearchInput();

  @override
  Widget build(BuildContext context) {
    return TTextField(
      labelText: 'Search',
      prefixIcon: const Icon(Icons.search),
      isCircularIcon: true,
      onChanged: (value) {
        // 🔍 handle search
      },
    );
  }
}
