import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/features/auth/data/repositories/auth_user_flow_repository.dart';
import 'package:smart_med/core/widgets/app_snack_bar.dart';

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
  bool showPassword = false;
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showMessage(String message, {bool isError = true}) {
    AppSnackBar.show(
      context,
      message,
      type: isError ? AppSnackBarType.error : AppSnackBarType.success,
    );
  }

  Future<void> validateSignup() async {
    final l10n = context.l10n;
    final name = nameController.text.trim();
    final ageText = ageController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (name.isEmpty) {
      showMessage(l10n.text('auth.validation.nameRequired'));
      return;
    }

    if (ageText.isEmpty) {
      showMessage(l10n.text('auth.validation.ageRequired'));
      return;
    }

    final age = int.tryParse(ageText);
    if (age == null) {
      showMessage(l10n.text('auth.validation.ageNumber'));
      return;
    }

    if (age < 1 || age > 120) {
      showMessage(l10n.text('auth.validation.ageRange'));
      return;
    }

    if (email.isEmpty) {
      showMessage(l10n.text('auth.validation.emailRequired'));
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      showMessage(l10n.text('auth.validation.validEmail'));
      return;
    }

    if (password.isEmpty) {
      showMessage(l10n.text('auth.validation.passwordRequired'));
      return;
    }

    if (password.length < 6) {
      showMessage(l10n.text('auth.validation.passwordLength'));
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
      );

      if (!mounted) return;
      showMessage(l10n.text('auth.signup.success'), isError: false);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print(e.message);
      }

      if (!mounted) return;
      showMessage(l10n.text('auth.signup.error'));
    } on AuthFlowException catch (e) {
      if (kDebugMode) {
        print(e.message);
      }

      if (!mounted) return;
      showMessage(l10n.text('auth.signup.error'));
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }

      if (!mounted) return;
      showMessage(l10n.text('auth.signup.unexpected'));
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
    final l10n = context.l10n;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          elevation: 0,
          title: Text(
            l10n.text('auth.createAccount'),
            style: const TextStyle(fontWeight: FontWeight.bold),
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
                        l10n.text('app.name'),
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.text('auth.signup.subtitle'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildLabel(context, l10n.text('auth.fullName')),
                      TextField(
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        decoration: buildInputDecoration(
                          hintText: l10n.text('auth.fullNameHint'),
                          prefixIcon: Icons.person_outline,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildLabel(context, l10n.text('auth.age')),
                      TextField(
                        controller: ageController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: buildInputDecoration(
                          hintText: l10n.text('auth.ageHint'),
                          prefixIcon: Icons.calendar_month_outlined,
                        ),
                      ),
                      const SizedBox(height: 18),

                      _buildLabel(context, l10n.text('auth.email')),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: buildInputDecoration(
                          hintText: l10n.text('auth.emailHint'),
                          prefixIcon: Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 18),

                      _buildLabel(context, l10n.text('auth.password')),
                      TextField(
                        controller: passwordController,
                        obscureText: !showPassword,
                        textInputAction: TextInputAction.done,
                        decoration: buildInputDecoration(
                          hintText: l10n.text('auth.passwordCreateHint'),
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
                              : Text(
                                  l10n.text('auth.createAccount'),
                                  style: const TextStyle(
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
