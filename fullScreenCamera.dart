import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:notifye/components/ru_button.dart';
import 'package:notifye/components/ru_textfield.dart';
import 'package:notifye/pages/forgotpassword.dart';
import 'package:notifye/helper/validators.dart';



class LoginPage extends StatefulWidget {
  // text controllers

  const LoginPage({super.key, required this.onTap});

  final void Function()? onTap;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  // login function
  void login() async {
  if (_loginFormKey.currentState!.validate()) {
    showDialog(
      context: context,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (error) {
      // Handle the error and show an error message

  String errorMessage;
  switch (error.code) {
    case 'user-not-found':
      errorMessage = "Account not found. Please register first.";
      break;
    case 'wrong-password':
      errorMessage = "Wrong password. Please try again.";
      break;
    default:
      errorMessage = "An unexpected error occurred: ${error.message}";
      break;
} 
// Show error message
if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(errorMessage),
    ),
  );
}

      // Close the loading dialog if it's still open
      if(mounted) Navigator.pop(context);
    }
  }
}

@override
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: () {
      // Dismiss the keyboard when tapping anywhere outside the text fields
      FocusScope.of(context).unfocus();
    },
    child: Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SingleChildScrollView( // Wrap with SingleChildScrollView
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(25.0),
            child: Form(
              key: _loginFormKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "n",
                    style: TextStyle(
                      fontFamily: 'PixelifySans',
                      fontWeight: FontWeight.normal,
                      fontSize: 200,
                    ),
                  ),
                  const Text(
                    " n  o  t  !  f  y  e ",
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 25),
                  // email
                  RUTextfield(
                    hintText: "Email",
                    obscuredText: false,
                    controller: emailController,
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 10),
                  // password
                  RUTextfield(
                    hintText: "Password",
                    obscuredText: true,
                    controller: passwordController,
                    validator: (password) {
                      if (password == null || password.isEmpty) {
                        return 'Please enter a password';
                      }
                      return password.length < 6
                          ? 'Password can NOT be less than 6 characters'
                          : null;
                    },
                  ),
                  const SizedBox(height: 10),
                  // forgot password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordPage(),
                            ),
                          );
                        },
                        child: Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // sign in button
                  const SizedBox(height: 10),
                  RUButton(text: "Login", onTap: login),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      GestureDetector(
                        onTap: widget.onTap,
                        child: const Text(
                          " Register Here",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // don't have an account?
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
