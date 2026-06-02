import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/features/auth/data/repositories/auth_repository.dart';
import 'package:smart_med/features/auth/data/repositories/auth_user_flow_repository.dart';
import 'package:smart_med/features/auth/presentation/pages/signup_page.dart';
import 'package:smart_med/core/widgets/app_snack_bar.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool showPassword = false;
  bool isLoading = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
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

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }

  Future<void> validateLogin() async {
    final l10n = context.l10n;
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage(l10n.text('auth.validation.emailPasswordRequired'));
      return;
    }

    if (!_isValidEmail(email)) {
      showMessage(l10n.text('auth.validation.validEmail'));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await authUserFlowRepository.signInAndEnsureProfile(
        email: email,
        password: password,
      );

      if (!mounted) return;

      showMessage(l10n.text('auth.signIn.success'), isError: false);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        showMessage(l10n.text('auth.signIn.invalidCredentials'));
      } else {
        showMessage(l10n.text('auth.signIn.error'));
      }
    } on AuthFlowException {
      showMessage(l10n.text('auth.signIn.error'));
    } catch (e) {
      showMessage(l10n.text('auth.signIn.unexpected'));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> sendResetPasswordEmail() async {
    final l10n = context.l10n;
    final email = emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      showMessage(l10n.text('auth.validation.emailFirst'));
      return;
    }

    if (!_isValidEmail(email)) {
      showMessage(l10n.text('auth.validation.validEmail'));
      return;
    }

    try {
      await authRepository.resetPassword(email: email);

      if (!mounted) return;
      showMessage(l10n.text('auth.reset.sent'), isError: false);
    } on FirebaseAuthException {
      showMessage(l10n.text('auth.reset.error'));
    } catch (e) {
      showMessage(l10n.text('auth.reset.unexpected'));
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
          toolbarHeight: 70,
          centerTitle: true,
          title: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              l10n.text('app.name'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: AppIconBadge(
                          icon: Icons.lock_person_outlined,
                          size: 64,
                          iconSize: 30,
                          borderRadius: 22,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.text('auth.welcomeBack'),
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.text('auth.signIn.subtitle'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.text('auth.email'),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: buildInputDecoration(
                          hintText: l10n.text('auth.emailHint'),
                          prefixIcon: Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.text('auth.password'),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: passwordController,
                        obscureText: !showPassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) async {
                          if (!isLoading) {
                            await validateLogin();
                          }
                        },
                        decoration: buildInputDecoration(
                          hintText: l10n.text('auth.passwordHint'),
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
                          onPressed: isLoading
                              ? null
                              : () async {
                                  await validateLogin();
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  l10n.text('auth.signIn'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: GestureDetector(
                          onTap: isLoading
                              ? null
                              : () async {
                                  await sendResetPasswordEmail();
                                },
                          child: Text(
                            l10n.text('auth.forgotPassword'),
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.primary,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignupPage(),
                              ),
                            );
                          },
                          child: Text(
                            l10n.text('auth.createAccountPrompt'),
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.primary,
                              decoration: TextDecoration.underline,
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
}
