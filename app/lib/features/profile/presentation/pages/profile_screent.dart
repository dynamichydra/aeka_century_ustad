import 'package:century_ai/common/widgets/profile/profile.dart';
import 'package:century_ai/features/profile/presentation/widgets/otp_page.dart';
import 'package:century_ai/utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final note = TextEditingController();
  final phone = TextEditingController();

  String? motherTongue;
  String? occupation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Profile(needUserName: false),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {},
                child: const Text("Edit"),
              ),
            ),

            const SizedBox(height: 12),

            _input("First Name", firstName),
            _input("Last Name", lastName),
            _input("Email", email),
            SizedBox(height: 8),
            Text(
              "Take PersonaliZation to next lable to adding more details to your profile",
            ),
            SizedBox(height: 8),
            _dropdown(
              label: "Mother Tongue",
              value: motherTongue,
              items: ["English", "Hindi", "Bengali", "Tamil"],
              onChanged: (v) => setState(() => motherTongue = v),
            ),
            SizedBox(height: 4),

            _dropdown(
              label: "Occupation",
              value: occupation,
              items: ["Student", "Developer", "Designer", "Business"],
              onChanged: (v) => setState(() => occupation = v),
            ),

            const SizedBox(height: 16),

            /// SUBMIT BUTTON
            Center(
              child: SizedBox(
                width: THelperFunctions.screenWidth(context) * 0.6,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text("Submit"),
                ),
              ),
            ),

            const SizedBox(height: 32),

            /// CHANGE NUMBER
            const Text(
              "Change Registered Number",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "Enter mobile number",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF737373)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF737373),
                    width: 1.5,
                  ),
                ),
                suffixIcon: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OtpPage()),
                    );
                  },
                  child: const Text("Get OTP"),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration bottomBorderDecoration(String label) {
    return const InputDecoration(
      filled: false,
      fillColor: Colors.transparent,
      border: UnderlineInputBorder(),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF737373)),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF737373), width: 2),
      ),
    );
  }

  Widget _input(String label, TextEditingController c, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: bottomBorderDecoration(label).copyWith(labelText: label),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: dropdownDecoration(label),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  InputDecoration dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: false,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF737373)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF737373)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF737373), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }
}
