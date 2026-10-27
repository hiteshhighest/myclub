import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'brand_mark.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool loading = false;
  bool obscure = true;
  String? error;
  bool success = false;

  Future<void> updatePassword() async {
    if (passwordController.text.length < 8) {
      setState(() => error = 'Use at least 8 characters for your new password.');
      return;
    }
    if (passwordController.text != confirmController.text) {
      setState(() => error = 'The passwords do not match.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: passwordController.text),
      );
      if (mounted) setState(() => success = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not update your password. Request a new reset link and try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandMark(size: 78)),
                  const SizedBox(height: 28),
                  Text(success ? 'Password updated' : 'Create a new password',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  Text(success
                    ? 'Your password has been changed. You can continue using MyClub.'
                    : 'Choose a strong password you have not used before.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!success) ...[
                            TextField(
                              controller: passwordController,
                              obscureText: obscure,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                labelText: 'New password (8+ characters)',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => obscure = !obscure),
                                  icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: confirmController,
                              obscureText: obscure,
                              decoration: const InputDecoration(
                                labelText: 'Confirm new password',
                                prefixIcon: Icon(Icons.lock_reset_rounded),
                              ),
                            ),
                          ],
                          if (error != null) ...[
                            const SizedBox(height: 12),
                            Text(error!, style: TextStyle(color: colors.error)),
                          ],
                          const SizedBox(height: 18),
                          if (!success)
                            FilledButton(
                              onPressed: loading ? null : updatePassword,
                              child: Text(loading ? 'Updating password…' : 'Update password'),
                            )
                          else
                            FilledButton(
                              onPressed: () => Supabase.instance.client.auth.signOut(),
                              child: const Text('Back to sign in'),
                            ),
                        ],
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
