import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../form_feedback.dart';
import '../services/auth_services.dart';
import 'home_screen.dart';
import 'login_screen.dart';

// profile form for google sign-in
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  final TextEditingController studentIdController = TextEditingController();
  late final TextEditingController emailController;

  bool loading = false;

  // max digits allowed for the studentID
  static const int maxStudentIdLength = 10;

  @override
  void initState() {
    super.initState();
    
    User? user = FirebaseAuth.instance.currentUser;
    nameController = TextEditingController(text: user?.displayName ?? '');
    emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    studentIdController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    // invalid input (red messages appear under the fields
    if (!(_formKey.currentState?.validate() ?? false)) return;

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await showInfoDialog(
        context,
        title: 'Signed out',
        message: 'Your session ended. Please log in again.',
        label: 'Log in',
      );
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
      return;
    }

    setState(() {
      loading = true;
    });

    String name = nameController.text.trim();
    String studentId = studentIdController.text.trim();

    try {
      if (name.isNotEmpty) {
        await user.updateDisplayName(name);
      }
      await AuthService().saveUserToFirestore(
        user,
        studentNumber: studentId,
        name: name,
      );

      if (!mounted) return;
      showSuccessSnack(context, 'Profile saved. Welcome to EventHub!');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, 'Could not save your profile. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
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
                  'Complete your profile',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const Text(
                  'We took your name and email from Google. Just add your Student ID to finish.',
                  style: TextStyle(color: AppColors.greyText, fontSize: 14),
                ),

                const SizedBox(height: 30),

                // full name (from Google) — red when empty
                TextFormField(
                  controller: nameController,
                  // filled from Google — only editable if Google had none
                  readOnly: nameController.text.trim().isNotEmpty,
                  validator: (value) =>
                      validateRequired(value, label: 'Full name'),
                  decoration: appInputDecoration(
                    label: 'Full name',
                    hint: 'Juan Dela Cruz',
                    prefixIcon: Icons.person_outline,
                    suffixIcon: nameController.text.trim().isNotEmpty
                        ? const Icon(Icons.check_circle,
                            color: AppColors.primary, size: 18)
                        : null,
                  ),
                ),

                const SizedBox(height: 20),

                // student id 
                TextFormField(
                  controller: studentIdController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(maxStudentIdLength),
                  ],
                  validator: validateStudentId,
                  decoration: appInputDecoration(
                    label: 'Student ID',
                    hint: 'e.g. 2023104567',
                    prefixIcon: Icons.badge_outlined,
                    suffixText:
                        '${studentIdController.text.length}/$maxStudentIdLength',
                    suffixStyle: const TextStyle(
                        color: AppColors.greyText, fontSize: 12),
                  ),
                ),

                const SizedBox(height: 20),

                // student email
                TextFormField(
                  controller: emailController,
                  readOnly: true,
                  validator: validateEmail,
                  decoration: appInputDecoration(
                    label: 'Student email',
                    hint: 'juan@student.edu.ph',
                    prefixIcon: Icons.mail_outline,
                    suffixIcon: const Icon(Icons.lock_outline,
                        color: AppColors.greyText, size: 18),
                  ),
                ),

                const SizedBox(height: 10),

                const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.greyText, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Your name and email stay linked to your Google account.',
                        style: TextStyle(
                            color: AppColors.greyText, fontSize: 12),
                      ),
                    ),
                  ],
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
                    onPressed: loading ? null : saveProfile,
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Save and continue',
                            style:
                                TextStyle(color: Colors.white, fontSize: 16),
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
