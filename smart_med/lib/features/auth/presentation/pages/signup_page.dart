import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/features/auth/data/repositories/auth_user_flow_repository.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController diseaseController = TextEditingController();
  final TextEditingController newDiseaseController = TextEditingController();

  final List<String> diseases = [];
  bool showPassword = false;
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    emailController.dispose();
    passwordController.dispose();
    diseaseController.dispose();
    newDiseaseController.dispose();
    super.dispose();
  }

  void refreshVisibleDiseases() {
    final visibleDiseases = diseases.length > 7
        ? diseases.sublist(diseases.length - 7)
        : diseases;
    diseaseController.text = visibleDiseases.join('\n');
  }

  void showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
        backgroundColor: isError ? Colors.red : Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> validateSignup() async {
    final name = nameController.text.trim();
    final ageText = ageController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (name.isEmpty) {
      showMessage("Please enter your name");
      return;
    }

    if (ageText.isEmpty) {
      showMessage("Please enter your age");
      return;
    }

    final age = int.tryParse(ageText);
    if (age == null) {
      showMessage("Age must be a valid number");
      return;
    }

    if (age < 1 || age > 120) {
      showMessage("Please enter a valid age");
      return;
    }

    if (email.isEmpty) {
      showMessage("Please enter your email");
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      showMessage("Please enter a valid email address");
      return;
    }

    if (password.isEmpty) {
      showMessage("Please enter your password");
      return;
    }

    if (password.length < 6) {
      showMessage("Password must be at least 6 characters");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await authUserFlowRepository.signUpAndCreateProfile(
        email: email,
        password: password,
        username: name,
        age: age,
        chronicDiseases: List<String>.from(diseases),
      );

      if (!mounted) return;
      showMessage("Account created successfully", isError: false);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print(e.message);
      }

      if (!mounted) return;
      showMessage(e.message ?? "There is an error");
    } on AuthFlowException catch (e) {
      if (kDebugMode) {
        print(e.message);
      }

      if (!mounted) return;
      showMessage(e.message);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }

      if (!mounted) return;
      showMessage("Something went wrong");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration buildInputDecoration({
    required String hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      suffixIcon: suffixIcon,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          elevation: 0,
          title: const Text(
            "Create Account",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 22,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: AppIconBadge(
                          icon: Icons.person_add_alt_1_outlined,
                          size: 64,
                          iconSize: 30,
                          borderRadius: 22,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        "Welcome to Smart Med",
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Create your account to continue",
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildLabel(context, "Full Name *"),
                      TextField(
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        decoration: buildInputDecoration(
                          hintText: "Enter your full name",
                          prefixIcon: Icons.person_outline,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildLabel(context, "Your Age *"),
                      TextField(
                        controller: ageController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: buildInputDecoration(
                          hintText: "Enter your Age",
                          prefixIcon: Icons.calendar_month_outlined,
                        ),
                      ),
                      const SizedBox(height: 18),

                      _buildLabel(context, "Email *"),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: buildInputDecoration(
                          hintText: "Enter your email",
                          prefixIcon: Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 18),

                      _buildLabel(context, "Password *"),
                      TextField(
                        controller: passwordController,
                        obscureText: !showPassword,
                        textInputAction: TextInputAction.done,
                        decoration: buildInputDecoration(
                          hintText: "Enter your password",
                          prefixIcon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                showPassword = !showPassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildLabel(context, "Chronic Diseases"),
                      TextField(
                        controller: newDiseaseController,
                        decoration: buildInputDecoration(
                          hintText: "Enter disease name",
                          prefixIcon: Icons.medical_information_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (newDiseaseController.text
                                    .trim()
                                    .isNotEmpty) {
                                  setState(() {
                                    diseases.add(
                                      newDiseaseController.text.trim(),
                                    );
                                    refreshVisibleDiseases();
                                    newDiseaseController.clear();
                                  });
                                } else {
                                  showMessage("Please enter a disease first");
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: const Text("Add Disease"),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                if (diseases.isEmpty) {
                                  showMessage("No disease to remove");
                                  return;
                                }

                                setState(() {
                                  diseases.removeLast();
                                  refreshVisibleDiseases();
                                });
                              },
                              icon: const Icon(Icons.undo),
                              label: const Text("Undo Last"),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: diseaseController,
                        readOnly: true,
                        maxLines: 4,
                        decoration: buildInputDecoration(
                          hintText: "Added diseases will appear here",
                          prefixIcon: Icons.list_alt_outlined,
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : validateSignup,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Sign Up",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
