import 'package:century_ai/common/widgets/inputs/text_field.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

class SearchInput extends StatefulWidget {
  const SearchInput({super.key});

  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  @override
  Widget build(BuildContext context) {
    return TTextField(
      labelText: 'Search',
      prefixIcon: Icon(Iconsax.search_normal),
      fillColor: Colors.white,
      suffixIcon: Image(
        image: AssetImage(TImages.homeInputRightIcon),
        fit: BoxFit.cover,
      ),
      isCircularIcon: true,
      readOnly: true,
      onTap: (){
        context.go('/search');
      },
    );
  }
}
