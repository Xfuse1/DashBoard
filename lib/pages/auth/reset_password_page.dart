import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;
  String? _info;

  bool get _isRecoveryLink {
    final params = _readAllUrlParams();
    final type = params['type'] ?? '';
    return type.toLowerCase() == 'recovery' ||
        params.containsKey('access_token') ||
        params.containsKey('refresh_token');
  }

  Map<String, String> _readAllUrlParams() {
    final uri = Uri.base;
    final out = <String, String>{};
    out.addAll(uri.queryParameters);
    if (uri.fragment.isNotEmpty) {
      try {
        out.addAll(Uri.splitQueryString(uri.fragment));
      } catch (_) {}
    }
    return out;
  }

  Future<void> _submit() async {
    final pass = _newPassCtrl.text;
    final confirm = _confirmCtrl.text;
    if (pass.isEmpty || pass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password must be at least 8 characters')));
      return;
    }
    if (pass != confirm) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() {
      _submitting = true;
      _info = null;
    });
    try {
      if (!SupabaseService.initialized) {
        throw Exception('Supabase not initialized');
      }

      // After opening the recovery link, the user should already have an active session.
      // We just update their password.
      final auth = SupabaseService.client.auth;
      await auth.updateUser(UserAttributes(password: pass));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated. Please sign in.')));
      // Sign out to clear the recovery session, then go to login.
      try {
        await auth.signOut();
      } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _info = 'Failed to update password: $e';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      backgroundColor: AppColors.secondary,
      body: Center(
        child: Card(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Set a new password',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (!_isRecoveryLink)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'This page is intended for password recovery links. If you did not come from an email, go back to Login.',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                const Text('New password'),
                const SizedBox(height: 6),
                TextField(
                  controller: _newPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                const Text('Confirm password'),
                const SizedBox(height: 6),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                if (_info != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_info!, style: const TextStyle(color: Colors.red)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _submitting
                          ? const CircularProgressIndicator()
                          : const Text('Update Password'),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

