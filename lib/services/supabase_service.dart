// Ignore the deprecation warning from the Supabase client about `.execute()`.
// We'll keep using the current API surface for backwards compatibility with the
// project's pinned package version.
// ignore_for_file: deprecated_member_use
import 'package:supabase_flutter/supabase_flutter.dart';
// flutter/foundation imported earlier but not required; keep file minimal.
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseService {
  // Whether Supabase.initialize has been called successfully.
  static bool initialized = false;

  static SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase. Reads configuration from environment variables.
  /// Use a local `.env` file (see `.env.example`) or set environment vars.
  static Future<void> init() async {
    // Load .env if present (safe to call multiple times)
    try {
      await dotenv.load();
    } catch (_) {
      // ignore if no .env
    }

    // Support both plain and NEXT_PUBLIC-prefixed env vars (common in some setups)
    final url = dotenv.env['SUPABASE_URL'] ??
        dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ??
        const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ??
        dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ??
        const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

    if (url.isEmpty || anonKey.isEmpty) {
      throw Exception(
          'Supabase URL and ANON key must be provided via .env or environment variables.\n'
          'Set SUPABASE_URL and SUPABASE_ANON_KEY (or NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY).');
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      // debug: kDebugMode,
      // If a service role key is present in env (only use in trusted server environments),
      // the client will still be initialized with anonKey; do not set serviceRole here for
      // client apps. We only read it to allow server-side code in this repo to access it if
      // necessary via dotenv, but we do NOT pass it to the client initializer.
    );
    initialized = true;
    // Enforce stored project binding: if the app was previously bound to a
    // different Supabase URL, clear session so user must sign in again.
    try {
      await _enforceProjectBinding(url);
    } catch (_) {}
  }

  static Future<void> _enforceProjectBinding(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('supabase_project_url');
      if (stored == null) return; // nothing bound yet
      if (stored != url) {
        // project changed: sign out and clear binding
        try {
          await Supabase.instance.client.auth.signOut();
        } catch (_) {}
        await prefs.remove('supabase_project_url');
      }
    } catch (_) {}
  }

  /// Persist the current Supabase project URL so future app runs detect
  /// mismatches and require re-login.
  static Future<void> bindCurrentProject() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = dotenv.env['SUPABASE_URL'] ??
          dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ??
          const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
      if (url.isNotEmpty) await prefs.setString('supabase_project_url', url);
    } catch (_) {}
  }

  /// Sign out the current user and clear the stored project binding.
  static Future<void> signOutAndClearBinding() async {
    try {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('supabase_project_url');
    } catch (_) {}
  }

  /// Safe helper: attempt to fetch from Supabase, return empty list on any error.
  static Future<List<Map<String, dynamic>>> fetchTableRows(String table,
      {int limit = 100, Map<String, dynamic>? filters}) async {
    try {
      final resp = await client.from(table).select().limit(limit).execute();
      final data = resp.data;
      if (data == null || data is! List) return [];
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Try common payment table names and return rows.
  static Future<List<Map<String, dynamic>>> fetchPayments(
      {int limit = 100}) async {
    const candidates = ['payments', 'invoices', 'billing'];
    for (final t in candidates) {
      final rows = await fetchTableRows(t, limit: limit);
      if (rows.isNotEmpty) return rows;
    }
    return [];
  }

  /// Try common ledger table names for credit history and return rows.
  static Future<List<Map<String, dynamic>>> fetchLedger(
      {int limit = 100}) async {
    const candidates = ['credit_ledger', 'ledger', 'credits', 'transactions'];
    for (final t in candidates) {
      final rows = await fetchTableRows(t, limit: limit);
      if (rows.isNotEmpty) return rows;
    }
    return [];
  }

  /// Fetch ledger rows for a specific user (looks for a `credit_ledger` table).
  /// Falls back to fetchLedger() if the specific table or query fails.
  static Future<List<Map<String, dynamic>>> fetchLedgerForUser(String userId,
      {int limit = 100}) async {
    try {
      final resp = await client
          .from('credit_ledger')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit)
          .execute();
      final data = resp.data;
      if (data == null || data is! List) return [];
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      // If table doesn't exist or query fails, fall back to generic search
      return fetchLedger(limit: limit);
    }
  }
}
