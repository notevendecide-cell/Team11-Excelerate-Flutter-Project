import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/auth_controller.dart';
import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class SignupScreen extends StatefulWidget {
  final AuthController auth;

  const SignupScreen({super.key, required this.auth});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await widget.auth.signupLearner(
        fullName: _fullName.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      // AuthController updates auth state; router redirect will take user to /learner.
      context.go('/learner');
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Signup failed', message: e.message);
    } catch (_) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Signup failed', message: 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learner Signup'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.person_add_alt_1_outlined, color: scheme.onSecondaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Create your learner account', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text('You will be signed in after signup.', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _fullName,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Full name',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (v) {
                                    final value = (v ?? '').trim();
                                    if (value.isEmpty) return 'Full name is required';
                                    if (value.length < 2) return 'Enter a valid name';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.mail_outline),
                                  ),
                                  validator: (v) {
                                    final value = (v ?? '').trim();
                                    if (value.isEmpty) return 'Email is required';
                                    if (!value.contains('@')) return 'Enter a valid email';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  autofillHints: const [AutofillHints.newPassword],
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                                    ),
                                  ),
                                  validator: (v) {
                                    final value = v ?? '';
                                    if (value.isEmpty) return 'Password is required';
                                    if (value.length < 6) return 'Minimum 6 characters';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _confirmPassword,
                                  obscureText: _obscure,
                                  autofillHints: const [AutofillHints.newPassword],
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(
                                    labelText: 'Confirm password',
                                    prefixIcon: Icon(Icons.lock_outline),
                                  ),
                                  validator: (v) {
                                    final value = v ?? '';
                                    if (value.isEmpty) return 'Confirm your password';
                                    if (value != _password.text) return 'Passwords do not match';
                                    return null;
                                  },
                                  onFieldSubmitted: (_) => _loading ? null : _submit(),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _loading ? null : _submit,
                                    child: _loading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('Create account'),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: _loading ? null : () => context.go('/login'),
                                  child: const Text('Already have an account? Sign in'),
                                ),
                              ],
                            ),
                          ),
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
    );
  }
}
