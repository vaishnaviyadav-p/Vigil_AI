import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/core/network/api_client.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _emailCtrl = TextEditingController();
  bool _submitted = false;
  bool _loading = false;

  Future<void> _handleReset() async {
    if (_emailCtrl.text.isEmpty) return;
    setState(() => _loading = true);

    try {
      await ApiClient().dio.post('/auth/forgot-password', data: {'email': _emailCtrl.text.trim()});
      setState(() {
        _submitted = true;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _submitted = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: _submitted
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.safeGreen, size: 64),
                    const SizedBox(height: 16),
                    const Text('Instructions Dispatched', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('If an account matches this email, password recovery steps have been sent.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: () => context.go('/login'), child: const Text('Return to Login')),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter your registered email address to receive password reset verification.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loading ? null : _handleReset,
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Send Recovery Email'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
