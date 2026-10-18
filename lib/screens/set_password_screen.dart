import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../form_feedback.dart';
import '../services/auth_services.dart';
import 'complete_profile_screen.dart';
import 'home_screen.dart';

// ------------------------------------------------------------
// SET AN EVENTHUB PASSWORD FOR GOOGLE-CREATED ACCOUNTS
// ------------------------------------------------------------
// Google users can add a password to the *same* account so they can
// log in with Google OR with email/password — no duplicate accounts.
// The student always confirms ownership with Google first, and their
// Google password is never asked for or stored.

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key, required this.email});

  // the EventHub account that will receive the password
  final String email;

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool obscurePassword = true;
  bool loading = false;

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  // press the save button
  Future<void> savePassword() async {
    // invalid input -> red messages appear under the fields
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      loading = true;
    });

    try {
      // proves ownership with Google, then updates THIS account
      await AuthService().setEventHubPassword(
        expectedEmail: widget.email,
        newPassword: passwordController.text,
      );

      // the Google sign-in inside the check may have signed us in
      User? user = FirebaseAuth.instance.currentUser;
      bool profileComplete =
          user != null && await AuthService().hasCompletedProfile(user);

      if (!mounted) return;
      showSuccessSnack(context,
          'EventHub password saved. You can now log in with your email and password.');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => profileComplete
              ? const HomeScreen()
              : const CompleteProfileScreen(),
        ),
        (route) => false,
      );
    } on PasswordSetupException catch (e) {
      if (mounted) showErrorSnack(context, e.message);
    } on FirebaseAuthException catch (e) {
      if (mounted) showErrorSnack(context, _messageFor(e));
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, 'Could not save the password. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // friendly text for Firebase errors
  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'This email already uses a password login. Log in with your password instead.';
      case 'invalid-credential':
      case 'invalid-email':
        return 'That Google account could not be verified for this email.';
      case 'requires-recent-login':
        return 'Please confirm your Google account again and retry.';
      case 'weak-password':
        return 'Please choose a stronger password (at least 8 characters).';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
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

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.lock_outline,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Set EventHub password',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Text(
                  'Add a password to your account',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Text(
                  'Your account (${widget.email}) currently signs in with Google. '
                  'With an EventHub password you can also log in using your email '
                  'and password — without creating a second account.',
                  style: const TextStyle(
                      color: AppColors.greyText, fontSize: 14),
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined,
                          color: AppColors.primary, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'For your security we will ask you to confirm your Google account first. '
                          'Your Google password is never shown or stored by EventHub.',
                          style: TextStyle(
                              color: AppColors.dark, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // new password — red outline + red message when invalid
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  validator: validatePassword,
                  // re-check the confirmation field so "Passwords do
                  // not match" clears as soon as this one is fixed
                  onChanged: (value) => _formKey.currentState?.validate(),
                  decoration: appInputDecoration(
                    label: 'New EventHub password',
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

                const SizedBox(height: 24),

                // save button
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
                    onPressed: loading ? null : savePassword,
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Confirm with Google and save',
                            style:
                                TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                Center(
                  child: TextButton(
                    onPressed: loading ? null : () => Navigator.pop(context),
                    child: const Text(
                      'Maybe later',
                      style: TextStyle(color: AppColors.greyText),
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
