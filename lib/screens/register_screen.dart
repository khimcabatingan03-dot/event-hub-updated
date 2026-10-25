import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../form_feedback.dart';
import '../services/auth_services.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController studentNumberController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool obscurePassword = true;
  bool loading = false;
  String errorMessage = '';

  // max digits allowed for the student number
  static const int maxStudentNumberLength = 10;

  // press the create account button
  void createAccount() async {
    String name = nameController.text.trim();
    String studentNumber = studentNumberController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text;

    // invalid input -> red border + red message below each field
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
      await AuthService().register(
          name: name,
          email: email,
          password: password,
          studentNumber: studentNumber);

      if (!mounted) return;
      showSuccessSnack(context, 'Account created. Welcome to EventHub!');
      // go to home screen after creating the account
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        loading = false;
      });
      if (!mounted) return;
      if (e.code == 'email-already-in-use') {
        // important issue -> ask the student what to do next
        _offerLoginInstead(email);
      } else if (e.code == 'weak-password') {
        setState(() {
          errorMessage = 'Password must be at least 8 characters.';
        });
      } else {
        setState(() {
          errorMessage = 'Something went wrong. Try again.';
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = 'Something went wrong. Try again.';
      });
    }
  }

  // this email already belongs to an account (it may have been created
  // with Google or a password) — point the student to the login screen
  void _offerLoginInstead(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Email already registered'),
        content: Text(
          '$email already has an EventHub account.\n\n'
          'Log in with your password, or tap "Continue with Google" '
          'if you signed up with Google — no second account is created.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back',
                style: TextStyle(color: AppColors.greyText)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const LoginScreen()),
              );
            },
            child: const Text('Log in',
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

              const SizedBox(height: 20),

              const Text(
                'Create account',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              const Text(
                'Join EventHub with your school email.',
                style: TextStyle(color: AppColors.greyText, fontSize: 14),
              ),

              const SizedBox(height: 30),

              // full name — red outline + red message when invalid
              TextFormField(
                controller: nameController,
                validator: (value) => validateRequired(value, label: 'Full name'),
                decoration: appInputDecoration(
                  label: 'Full name',
                  hint: 'Juan Dela Cruz',
                  prefixIcon: Icons.person_outline,
                ),
              ),

              const SizedBox(height: 20),

              // student number (digits only, max 10)
              TextFormField(
                controller: studentNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  // hard stop: can't type past 10 digits
                  LengthLimitingTextInputFormatter(maxStudentNumberLength),
                ],
                validator: validateStudentId,
                onChanged: (value) {
                  // rebuild so the counter below updates while typing
                  setState(() {});
                },
                decoration: appInputDecoration(
                  label: 'Student number',
                  hint: 'e.g. 2023104567',
                  prefixIcon: Icons.badge_outlined,
                  suffixText:
                      '${studentNumberController.text.length}/$maxStudentNumberLength',
                  suffixStyle: const TextStyle(
                      color: AppColors.greyText, fontSize: 12),
                ),
              ),

              const SizedBox(height: 20),

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
                validator: validatePassword,
                // re-check the confirmation field so "Passwords do not
                // match" clears as soon as this one is fixed
                onChanged: (value) => _formKey.currentState?.validate(),
                decoration: appInputDecoration(
                  label: 'Password',
                  hint: 'At least 8 characters',
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

              const SizedBox(height: 20),

              // confirm password — red outline + red message when invalid
              TextFormField(
                controller: confirmController,
                obscureText: obscurePassword,
                validator: (value) => validatePasswordConfirmation(
                    value, passwordController.text),
                decoration: appInputDecoration(
                  label: 'Confirm password',
                  hint: 'Re-enter your password',
                  prefixIcon: Icons.lock_outline,
                ),
              ),

              const SizedBox(height: 10),

              // error message (red text)
              if (errorMessage.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        errorMessage,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 20),

              // create account button
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
                  onPressed: loading ? null : createAccount,
                  child: loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Create account',
                          style:
                              TextStyle(color: Colors.white, fontSize: 16),
                        ),
                ),
              ),

              const SizedBox(height: 30),

              // already registered link
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                    );
                  },
                  child: const Text(
                    'Already registered? Log in',
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
}
