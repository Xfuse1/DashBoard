// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/supabase_service.dart';

class SeekerSignupPage extends StatefulWidget {
  const SeekerSignupPage({super.key});

  @override
  State<SeekerSignupPage> createState() => _SeekerSignupPageState();
}

class _SeekerSignupPageState extends State<SeekerSignupPage> {
  final _fullName = TextEditingController();
  final _jobTitle = TextEditingController();
  final _nationality = TextEditingController();
  final _country = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  int? signupCooldownSeconds;
  Timer? _signupCooldownTimer;

  void _startSignupCooldown(int seconds) {
    _signupCooldownTimer?.cancel();
    setState(() => signupCooldownSeconds = seconds);
    _signupCooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {
        signupCooldownSeconds = (signupCooldownSeconds ?? 0) - 1;
        if ((signupCooldownSeconds ?? 0) <= 0) {
          _signupCooldownTimer?.cancel();
          _signupCooldownTimer = null;
          signupCooldownSeconds = null;
        }
      });
    });
  }

  Future<void> _submitSeeker() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || pass.isEmpty || _fullName.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      if (!SupabaseService.initialized) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Supabase not initialized. Add a .env file with SUPABASE_URL and SUPABASE_ANON_KEY and restart.')));
        return;
      }
      final auth = SupabaseService.client.auth;
      await (auth as dynamic).signUp(email: email, password: pass);

      final userId = SupabaseService.client.auth.currentUser?.id;

      final row = {
        if (userId != null) 'id': userId,
        'full_name': _fullName.text.trim(),
        'job_title': _jobTitle.text.trim(),
        'nationality': _nationality.text.trim(),
        'country': _country.text.trim(),
        'phone': _phone.text.trim(),
        'email': email,
      };

      await SupabaseService.client
          .from('seeker_profiles')
          .insert(row)
          .execute();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Account created. Check email to confirm.')));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (err) {
      if (!mounted) return;
      final msg = err.toString();
      final retryMatch =
          RegExp(r'after\s+(\d+)\s+seconds', caseSensitive: false)
              .firstMatch(msg);
      if (retryMatch != null) {
        final seconds = int.tryParse(retryMatch.group(1) ?? '') ?? 30;
        _startSignupCooldown(seconds);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Too many requests — please try again in $seconds seconds.')));
      } else if (msg.contains('Could not find the table') ||
          msg.contains('404') ||
          msg.contains('PGRST205')) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Sign up partly succeeded but we couldn't create your profile row. Possible cause: the 'seeker_profiles' table doesn't exist in your Supabase project. Please create it or update the client to use the correct table name.")));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Sign up failed: $msg')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Seeker Sign up'),
          backgroundColor: AppColors.accent),
      body: Center(
        child: Card(
          child: Container(
            width: 760,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: _fullName,
                    decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: 8),
                TextField(
                    controller: _jobTitle,
                    decoration: const InputDecoration(labelText: 'Job title')),
                const SizedBox(height: 8),
                TextField(
                    controller: _nationality,
                    decoration:
                        const InputDecoration(labelText: 'Nationality')),
                const SizedBox(height: 8),
                TextField(
                    controller: _country,
                    decoration: const InputDecoration(labelText: 'Country')),
                const SizedBox(height: 8),
                TextField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 8),
                TextField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 8),
                TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password')),
                const SizedBox(height: 12),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent),
                        onPressed:
                            (_loading || (signupCooldownSeconds ?? 0) > 0)
                                ? null
                                : _submitSeeker,
                        child: _loading
                            ? const CircularProgressIndicator()
                            : Text((signupCooldownSeconds ?? 0) > 0
                                ? 'Try again in ${signupCooldownSeconds}s'
                                : 'Create Seeker Account')))
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _signupCooldownTimer?.cancel();
    _fullName.dispose();
    _jobTitle.dispose();
    _nationality.dispose();
    _country.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }
}
