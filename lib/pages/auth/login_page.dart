import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/supabase_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) return;
    setState(() => _loading = true);
    try {
      if (!SupabaseService.initialized) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Supabase not initialized. Add a .env file with SUPABASE_URL and SUPABASE_ANON_KEY and restart.')));
        return;
      }
      // Try modern API first, fallback to older if needed
      // Different Supabase client versions expose different auth methods.
      // Try the modern signInWithPassword first; if it's not available, try the older
      // signIn method signature (email/password). If neither exists, the call will
      // throw and be handled below.
      final auth = SupabaseService.client.auth;
      try {
        // dynamic call avoids static API mismatch between supabase versions
        await (auth as dynamic)
            .signInWithPassword(email: email, password: pass);
      } catch (e) {
        try {
          await (auth as dynamic).signIn(email: email, password: pass);
        } catch (_) {
          rethrow;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed in successfully')));
      // After sign in, route based on profile existence: seekers -> /seeker, employers -> /employee
      // After sign in, route based on profile existence: seekers -> /seeker, companies (employees) -> /employee
      // Attempt to resolve the signed-in user's id. Some supabase client
      // versions may not populate `currentUser` immediately, so poll a few
      // times if necessary.
      String? userId = SupabaseService.client.auth.currentUser?.id;
      final authDyn = SupabaseService.client.auth as dynamic;
      int attempts = 0;
      while ((userId == null || userId.isEmpty) && attempts < 10) {
        // try a few different shapes for different client versions
        try {
          userId = SupabaseService.client.auth.currentUser?.id ??
              (authDyn.currentUser != null ? authDyn.currentUser.id : null) ??
              (authDyn.user != null ? authDyn.user.id : null);
        } catch (_) {}
        if (userId != null && userId.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 200));
        attempts += 1;
      }
      String? destination;
      if (userId != null) {
        try {
          // Try modern maybeSingle() API first
          dynamic seeker;
          try {
            seeker = await (SupabaseService.client.from('seeker_profiles')
                    as dynamic)
                .select()
                .eq('id', userId)
                .maybeSingle();
          } catch (_) {
            final resp = await SupabaseService.client
                .from('seeker_profiles')
                .select()
                .eq('id', userId)
                .execute();
            seeker = resp.data;
          }
          final bool hasSeeker = seeker != null &&
              (seeker is Map || (seeker is List && seeker.isNotEmpty));
          if (hasSeeker) {
            destination = '/seeker';
          } else {
            // check employers by owner_user_id
            dynamic company;
            try {
              company =
                  await (SupabaseService.client.from('companies') as dynamic)
                      .select()
                      .eq('owner_user_id', userId)
                      .maybeSingle();
            } catch (_) {
              final resp = await SupabaseService.client
                  .from('companies')
                  .select()
                  .eq('owner_user_id', userId)
                  .execute();
              company = resp.data;
            }
            final bool hasCompany = company != null &&
                (company is Map || (company is List && company.isNotEmpty));
            if (hasCompany) {
              destination = '/employee';
            }
          }
        } catch (e) {
          // If anything goes wrong querying profiles, fallback to default behavior
          // but inform the user.
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Signed in but profile check failed: $e')));
        }
      }

      // Debug: show what we resolved for troubleshooting navigation issues
      if (mounted) {
        final dbg =
            'login debug: userId=${userId ?? 'null'} destination=${destination ?? 'null'}';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(dbg)));
        // ignore: avoid_print
        print(dbg);
      }

      // Attempt to extract an access token from the Supabase client in a
      // robust way that works across several client versions. We print it
      // to the console for debugging (requested by the user).
      try {
        final authDyn = SupabaseService.client.auth as dynamic;
        String? token;
        // Common shapes: currentSession.accessToken, session().accessToken,
        // currentSession.access_token, session().access_token
        try {
          final cs = authDyn.currentSession;
          token = cs?.accessToken ?? cs?.access_token;
        } catch (_) {}
        if (token == null) {
          try {
            final sess = await authDyn.session();
            token = sess?.accessToken ?? sess?.access_token;
          } catch (_) {}
        }
        // Fallback to the strongly-typed accessor if available
        try {
          token =
              token ?? SupabaseService.client.auth.currentSession?.accessToken;
        } catch (_) {}

        // Print token to console for debugging (will show in IDE/debug console).
        // ignore: avoid_print
        print('Supabase access token: ${token ?? '<none>'}');
      } catch (e) {
        // ignore: avoid_print
        print('Failed to read Supabase token: $e');
      }

      // If a destination was supplied via route args (login was asked to go somewhere), honor it.
      final next = ModalRoute.of(context)?.settings.arguments as String?;
      if (next != null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, next);
      } else if (destination != null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, destination);
      } else {
        // Default fallback: go to seeker dashboard
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/seeker');
      }
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sign in failed: $err')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: Center(
        child: Card(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Welcome Back',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Sign in to your account to continue',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 18),
              Align(
                  alignment: Alignment.centerLeft,
                  child: const Text('Email',
                      style: TextStyle(color: Colors.black54))),
              const SizedBox(height: 6),
              TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'john.doe@example.com')),
              const SizedBox(height: 12),
              Align(
                  alignment: Alignment.centerLeft,
                  child: const Text('Password',
                      style: TextStyle(color: Colors.black54))),
              const SizedBox(height: 6),
              TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder())),
              const SizedBox(height: 8),
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                      onPressed: () {},
                      child: const Text('Forgot your password?'))),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent),
                    onPressed: _loading ? null : _signIn,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _loading
                          ? const CircularProgressIndicator()
                          : const Text('Login'),
                    )),
              ),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: () {
                    final next =
                        ModalRoute.of(context)?.settings.arguments as String?;
                    Navigator.pushNamed(context, '/signup', arguments: next);
                  },
                  child: const Text("Don't have an account? Sign Up"))
            ]),
          ),
        ),
      ),
    );
  }
}
