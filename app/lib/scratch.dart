import 'package:firebase_auth/firebase_auth.dart';
void test() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    String? token = await user.getIdToken();
  }
}
