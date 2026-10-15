import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/auth_services.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool loading = false;
  bool googleLoading = false;
  String errorMessage = '';

  // press the continue with google button
  void googleLogin() async {
    setState(() {
      googleLoading = true;
      errorMessage = '';
    });

    try {
      var result = await AuthService().signInWithGoogle();

      // user closed the google picker
      if (result == null) {
        setState(() {
          googleLoading = false;
        });
        return;
      }

      // put the google account details into the textfields
      setState(() {
        emailController.text = result.user!.email ?? '';
        passwordController.text = '';
        googleLoading = false;
      });

      // small delay so the student can see the fields filled
      await Future.delayed(const Duration(seconds: 1));

      // go to home screen after logging in
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        googleLoading = false;
        errorMessage = 'Google sign-in failed. Try again.';
      });
    }
  }

  // press the log in button
  void logIn() async {
    String email = emailController.text.trim();
    String password = passwordController.text;

    // input validation
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Please fill up all the fields.';
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = '';
    });

    try {
      await AuthService().login(email: email, password: password);
      // go to home screen after logging in
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        // Google accounts have no password, so email/password login
        // will always fail for them
        if (e.code == 'wrong-password' ||
            e.code == 'invalid-credential' ||
            e.code == 'user-not-found') {
          errorMessage =
              'Email or password is incorrect. If you signed up with '
              'Google, tap "Continue with Google" instead.';
        } else {
          errorMessage = 'Incorrect email or password. Try again.';
        }
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Something went wrong. Try again.';
      });
    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // back button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),

              const SizedBox(height: 10),

              // logo
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Eventhub',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              const Text(
                'Welcome back',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              const Text(
                'Log in to browse and register for events.',
                style: TextStyle(color: AppColors.greyText, fontSize: 14),
              ),

              const SizedBox(height: 30),

              // school email
              const Text('School email',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'juan@student.edu.ph',
                  prefixIcon: const Icon(Icons.mail_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // password
              const Text('Password',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Your password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // error message (red text)
              if (errorMessage.isNotEmpty)
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),

              const SizedBox(height: 8),

              // forgot password link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // simple reset: ask for the email then send a reset link
                    askForgotPassword();
                  },
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ),

              // log in button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: loading ? null : logIn,
                  child: loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Log in',
                          style:
                              TextStyle(color: Colors.white, fontSize: 16),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // "or" divider
              const Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or',
                        style: TextStyle(color: AppColors.greyText)),
                  ),
                  Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                ],
              ),

              const SizedBox(height: 20),

              // continue with google button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: googleLoading ? null : googleLogin,
                  icon: googleLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary),
                        )
                      : const Text(
                          'G',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                  label: Text(
                    googleLoading
                        ? 'Signing in...'
                        : 'Continue with Google',
                    style: const TextStyle(
                        color: Colors.black, fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // create account link
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: const Text(
                    'New to EventHub? Create an account',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // dialog to ask for the email, then send a password reset link
  void askForgotPassword() {
    TextEditingController emailInput = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Forgot password?'),
        content: TextField(
          controller: emailInput,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'juan@student.edu.ph',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.greyText)),
          ),
          TextButton(
            onPressed: () async {
              String email = emailInput.text.trim();
              // save the messenger before the dialog closes
              ScaffoldMessengerState messenger =
                  ScaffoldMessenger.of(context);
              Navigator.pop(context);
              if (email.isEmpty) return;
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: email);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Reset link sent. Check your email.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Could not send reset email.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            child: const Text('Send link',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
