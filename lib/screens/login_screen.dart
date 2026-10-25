import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../form_feedback.dart';
import '../services/auth_services.dart';
import 'complete_profile_screen.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'set_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
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

      if (result == null) {
        setState(() {
          googleLoading = false;
        });
        return;
      }

      if (!mounted) return;

      bool profileComplete =
          await AuthService().hasCompletedProfile(result.user!);
      if (!mounted) return;

      setState(() {
        googleLoading = false;
      });

      if (!profileComplete) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const CompleteProfileScreen()),
        );
        return;
      }

      // returning user with a completed profile (straight to home)
      showSuccessSnack(context, 'Signed in with Google.');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        googleLoading = false;
      });
      if (mounted) {
        showErrorSnack(context, 'Google sign-in failed. Try again.');
      }
    }
  }

  // press the log in button
  void logIn() async {
    String email = emailController.text.trim();
    String password = passwordController.text;

    // invalid input -> red border + red message below that field
    // (nothing is sent to Firebase until every field is valid)
    if (!(_formKey.currentState?.validate() ?? false)) {
      // field errors replace any older form-wide message
      if (errorMessage.isNotEmpty) {
        setState(() {
          errorMessage = '';
        });
      }
      return;
    }

    setState(() {
      loading = true;
      errorMessage = '';
    });

    try {
      await AuthService().login(email: email, password: password);
      if (!mounted) return;
      showSuccessSnack(context, 'Logged in successfully.');
      // go to home screen after logging in
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
      return;
    } on FirebaseAuthException catch (e) {
      setState(() {
        loading = false;
      });

      if (e.code == 'wrong-password') {
        setState(() {
          errorMessage = 'Email or password is incorrect. Try again.';
        });
        return;
      }

      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        // Google-created accounts have no password yet — offer to
        // set an EventHub password instead of failing silently
        bool googleOnly = await AuthService().isGoogleOnlyAccount(email);
        if (!mounted) return;
        setState(() {
          errorMessage = googleOnly
              ? 'This account signs in with Google and has no EventHub password yet.'
              : 'Email or password is incorrect. Try again.';
        });
        if (googleOnly) offerPasswordSetup(email);
        return;
      }

      setState(() {
        errorMessage = e.code == 'too-many-requests'
            ? 'Too many attempts. Please wait a moment and try again.'
            : 'Something went wrong. Try again.';
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = 'Something went wrong. Try again.';
      });
    }

    setState(() {
      loading = false;
    });
  }

  // AlertDialog- this account was created with Google, so it has no
  // password — let the student add one securely (never the Google one)
  void offerPasswordSetup(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('No EventHub password yet'),
        content: Text(
          'This account was created with Google, so email/password login '
          'does not work for $email yet.\n\n'
          'You can set an EventHub password (never your Google password) '
          'to log in either way — no second account is created.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not now',
                style: TextStyle(color: AppColors.greyText)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => SetPasswordScreen(email: email)),
              );
            },
            child: const Text('Set password',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          // red border + red message while typing; both clear
          // automatically as soon as the input becomes valid
          autovalidateMode: AutovalidateMode.onUserInteraction,
          key: _formKey,
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

              // school email — red outline + red message when invalid
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                validator: validateEmail,
                decoration: appInputDecoration(
                  label: 'School email',
                  hint: 'juan@student.edu.ph',
                  prefixIcon: Icons.mail_outline,
                ),
              ),

              const SizedBox(height: 20),

              // password — red outline + red message when invalid
              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                validator: (value) =>
                    validateRequired(value, label: 'Password'),
                decoration: appInputDecoration(
                  label: 'Password',
                  hint: 'Your password',
                  prefixIcon: Icons.lock_outline,
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
      ),
    );
  }

  // dialog to ask for the email, then send a password reset link
  void askForgotPassword() {
    TextEditingController emailInput = TextEditingController();
    final GlobalKey<FormState> resetFormKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Forgot password?'),
        content: Form(
          key: resetFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: TextFormField(
            controller: emailInput,
            keyboardType: TextInputType.emailAddress,
            validator: validateEmail,
            decoration: appInputDecoration(
              label: 'Email',
              hint: 'juan@student.edu.ph',
              prefixIcon: Icons.mail_outline,
            ),
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
              // invalid email -> red border + red message in the dialog
              if (!(resetFormKey.currentState?.validate() ?? false)) {
                return;
              }
              String email = emailInput.text.trim();
              // save the messenger before the dialog closes
              ScaffoldMessengerState messenger =
                  ScaffoldMessenger.of(context);
              Navigator.pop(context);
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: email);
                showSnackOn(messenger, 'Reset link sent. Check your email.');
              } catch (e) {
                showSnackOn(messenger, 'Could not send reset email.',
                    error: true);
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
