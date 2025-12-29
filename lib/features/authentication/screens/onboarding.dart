import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:century_ai/utils/constants/sizes.dart';
import 'package:century_ai/utils/constants/text_strings.dart';
import 'package:century_ai/utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';

class Onboarding extends StatelessWidget {
const Onboarding({ Key? key }) : super(key: key);

  @override
  Widget build(BuildContext context){
    return Scaffold(
       body: Stack(
        children: [
          // Horizontal Scrollable Page
          PageView(
            children: [
              Onbording_contetn(),
              Column(
                children: [
                  Image(
                    width: THelperFunctions.screenWidth(context) * 0.8,
                    height: THelperFunctions.screenHeight(context) * 0.6,
                    image: AssetImage(TImages.onBoardingImage2)
                    ),
                    Text(TTexts.onBoardingTitle2, style: Theme.of(context).textTheme.headlineMedium,textAlign: TextAlign.center,),
                    SizedBox(height: TSizes.spaceBtwItems,),
                    Text(TTexts.onBoardingSubTitle2, style: Theme.of(context).textTheme.bodyMedium,textAlign: TextAlign.center,),
                ],
              ),
              Column(
                children: [
                  Image(
                    width: THelperFunctions.screenWidth(context) * 0.8,
                    height: THelperFunctions.screenHeight(context) * 0.6,
                    image: AssetImage(TImages.onBoardingImage3)
                    ),
                    Text(TTexts.onBoardingTitle3, style: Theme.of(context).textTheme.headlineMedium,textAlign: TextAlign.center,),
                    SizedBox(height: TSizes.spaceBtwItems,),
                    Text(TTexts.onBoardingSubTitle3, style: Theme.of(context).textTheme.bodyMedium,textAlign: TextAlign.center,),
                ],
              )
            ],
          )
        ],
       ),
    );
  }
}

class Onbording_contetn extends StatelessWidget {
  const Onbording_contetn({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image(
          width: THelperFunctions.screenWidth(context) * 0.8,
          height: THelperFunctions.screenHeight(context) * 0.6,
          image: AssetImage(TImages.onBoardingImage1)
          ),
          Text(TTexts.onBoardingTitle1, style: Theme.of(context).textTheme.headlineMedium,textAlign: TextAlign.center,),
          SizedBox(height: TSizes.spaceBtwItems,),
          Text(TTexts.onBoardingSubTitle1, style: Theme.of(context).textTheme.bodyMedium,textAlign: TextAlign.center,),
      ],
    );
  }
}