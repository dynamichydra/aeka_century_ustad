import 'package:century_ai/common/widgets/inputs/text_field.dart';
import 'package:century_ai/common/widgets/profile/profile.dart';
import 'package:century_ai/utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';

class OtpPage extends StatelessWidget {
  const OtpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final otp = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text("Verify OTP")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Profile(avatarRadius: 60,needUserName: false,),
            const SizedBox(height: 32),
             TTextField(
              labelText: 'Enter Your OTP',
              controller: otp,
              prefixIcon: Icon(Icons.mail),
              isCircularIcon: true,
            ),
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                width: THelperFunctions.screenWidth(context) * 0.6,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text("Submit"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
