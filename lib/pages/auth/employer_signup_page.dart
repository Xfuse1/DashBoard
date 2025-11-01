// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/supabase_service.dart';

class EmployerSignupPage extends StatefulWidget {
  const EmployerSignupPage({super.key});

  @override
  State<EmployerSignupPage> createState() => _EmployerSignupPageState();
}

class _EmployerSignupPageState extends State<EmployerSignupPage> {
  final _companyName = TextEditingController();
  final _companyNameAr = TextEditingController();
  final _companyLegal = TextEditingController();
  final _companyIndustry = TextEditingController();
  final _companySize = TextEditingController();
  final _companyCountry = TextEditingController();
  final _foundedYear = TextEditingController();
  final _city = TextEditingController();
  final _streetAddress = TextEditingController();
  final _website = TextEditingController();
  final _linkedin = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _contactName = TextEditingController();
  final _contactTitle = TextEditingController();
  final _taxId = TextEditingController();

  bool _loading = false;
  int? signupCooldownSeconds;
  Timer? _signupCooldownTimer;
  int _currentStep = 0;
  String _selectedPlan = 'free';
  String? _registrationFileName;
  final List<String> _additionalPhones = [];
  final List<String> _additionalEmails = [];

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

  Future<void> _submitEmployer() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || pass.isEmpty || _companyName.text.trim().isEmpty)
      return;
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

      // Prepare row to match your DB schema (public.companies)
      final foundedYear = int.tryParse(_foundedYear.text.trim());
      final row = {
        'owner_user_id': userId,
        'name_en': _companyName.text.trim(),
        'name_ar': _companyNameAr.text.trim(),
        'legal_name': _companyLegal.text.trim(),
        'industry': _companyIndustry.text.trim(),
        // your SQL defines the column as `size company_size` — use that name
        'size': _companySize.text.trim(),
        'founded_year': foundedYear,
        'country': _companyCountry.text.trim(),
        'city': _city.text.trim(),
        'street_address': _streetAddress.text.trim(),
        'website': _website.text.trim(),
        'linkedin_url': _linkedin.text.trim(),
        'contact_name': _contactName.text.trim(),
        'email': email,
        'additional_phones': _additionalPhones.join(','),
        'plan': _selectedPlan,
        'tax_id': _taxId.text.trim(),
        'kyc_doc_url': _registrationFileName,
      };

      await SupabaseService.client.from('companies').insert(row).execute();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employer account created.')));
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
                "Employer created but we couldn't create the employer profile row. Ensure the 'companies' table exists in Supabase or update the table name.")));
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
    // Multi-step employer signup using Stepper to match the requested UI
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Company Account'),
        backgroundColor: AppColors.accent,
      ),
      body: Center(
        child: Card(
          child: Container(
            width: 760,
            padding: const EdgeInsets.all(20),
            child: Stepper(
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep < 2) {
                  setState(() => _currentStep += 1);
                } else {
                  // final submit
                  _submitEmployer();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) setState(() => _currentStep -= 1);
              },
              controlsBuilder: (context, details) {
                final isLast = _currentStep == 2;
                return Row(
                  children: [
                    if (_currentStep > 0)
                      TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Back')),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 18),
                        child: _loading
                            ? const CircularProgressIndicator()
                            : Text(isLast ? 'Finish' : 'Next'),
                      ),
                    ),
                  ],
                );
              },
              steps: [
                Step(
                  title: const Text('Company Info'),
                  content: Column(children: [
                    TextField(
                        controller: _companyNameAr,
                        decoration: const InputDecoration(
                            labelText: 'Company Name (Arabic)')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _companyName,
                        decoration: const InputDecoration(
                            labelText: 'Company Name (English)')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _companyLegal,
                        decoration:
                            const InputDecoration(labelText: 'Legal Name')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                        value: _companyIndustry.text.isEmpty
                            ? null
                            : _companyIndustry.text,
                        decoration:
                            const InputDecoration(labelText: 'Industry'),
                        items: const [
                          DropdownMenuItem(
                              value: 'Technology', child: Text('Technology')),
                          DropdownMenuItem(
                              value: 'Healthcare', child: Text('Healthcare')),
                          DropdownMenuItem(
                              value: 'Finance', child: Text('Finance')),
                          DropdownMenuItem(
                              value: 'Education', child: Text('Education')),
                          DropdownMenuItem(
                              value: 'Retail', child: Text('Retail')),
                        ],
                        onChanged: (v) =>
                            setState(() => _companyIndustry.text = v ?? '')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                        value: _companySize.text.isEmpty
                            ? null
                            : _companySize.text,
                        decoration:
                            const InputDecoration(labelText: 'Company Size'),
                        items: const [
                          DropdownMenuItem(
                              value: '1-10', child: Text('1-10 employees')),
                          DropdownMenuItem(
                              value: '11-50', child: Text('11-50 employees')),
                          DropdownMenuItem(
                              value: '51-200', child: Text('51-200 employees')),
                          DropdownMenuItem(
                              value: '201-500',
                              child: Text('201-500 employees')),
                          DropdownMenuItem(
                              value: '500+', child: Text('500+ employees')),
                        ],
                        onChanged: (v) =>
                            setState(() => _companySize.text = v ?? '')),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: _foundedYear,
                              decoration: const InputDecoration(
                                  labelText: 'Founded Year'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                              controller: _companyCountry,
                              decoration:
                                  const InputDecoration(labelText: 'Country'))),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: _city,
                              decoration:
                                  const InputDecoration(labelText: 'City'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                              controller: _streetAddress,
                              decoration: const InputDecoration(
                                  labelText: 'Street Address'))),
                    ]),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _website,
                        decoration: const InputDecoration(
                            labelText: 'Website (https://example.com)')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _linkedin,
                        decoration: const InputDecoration(
                            labelText: 'LinkedIn Profile URL')),
                  ]),
                ),
                Step(
                  title: const Text('Contact & Prefs'),
                  content: Column(children: [
                    TextField(
                        controller: _contactName,
                        decoration: const InputDecoration(
                            labelText: 'Contact Person\'s Name')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _contactTitle,
                        decoration: const InputDecoration(
                            labelText: 'Contact Person\'s Job Title')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _email,
                        decoration: const InputDecoration(
                            labelText: 'Email (for login)')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _password,
                        obscureText: true,
                        decoration:
                            const InputDecoration(labelText: 'Password')),
                    const SizedBox(height: 12),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: const Text('Additional Company Phones')),
                    const SizedBox(height: 6),
                    ..._additionalPhones
                        .map((p) => ListTile(title: Text(p)))
                        .toList(),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              decoration:
                                  const InputDecoration(hintText: 'Add phone'),
                              onSubmitted: (v) {
                                if (v.trim().isNotEmpty)
                                  setState(
                                      () => _additionalPhones.add(v.trim()));
                              })),
                      IconButton(icon: const Icon(Icons.add), onPressed: () {}),
                    ]),
                    const SizedBox(height: 12),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: const Text('Additional Company Emails')),
                    const SizedBox(height: 6),
                    ..._additionalEmails
                        .map((e) => ListTile(title: Text(e)))
                        .toList(),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              decoration:
                                  const InputDecoration(hintText: 'Add email'),
                              onSubmitted: (v) {
                                if (v.trim().isNotEmpty)
                                  setState(
                                      () => _additionalEmails.add(v.trim()));
                              })),
                      IconButton(icon: const Icon(Icons.add), onPressed: () {}),
                    ]),
                  ]),
                ),
                Step(
                  title: const Text('Billing & KYC'),
                  content: Column(children: [
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Choose your plan')),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedPlan = 'free'),
                              child: Card(
                                  color: _selectedPlan == 'free'
                                      ? Colors.green.shade50
                                      : null,
                                  child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(children: const [
                                        Text('Free'),
                                        Text('0 EGP/mo')
                                      ]))))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedPlan = 'basic'),
                              child: Card(
                                  color: _selectedPlan == 'basic'
                                      ? Colors.green.shade50
                                      : null,
                                  child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(children: const [
                                        Text('Basic'),
                                        Text('500 EGP/mo')
                                      ]))))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedPlan = 'pro'),
                              child: Card(
                                  color: _selectedPlan == 'pro'
                                      ? Colors.green.shade50
                                      : null,
                                  child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(children: const [
                                        Text('Pro'),
                                        Text('1500 EGP/mo')
                                      ]))))),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _taxId,
                        decoration: const InputDecoration(
                            labelText: 'Tax ID / VAT Number')),
                    const SizedBox(height: 12),
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Commercial Registration Document')),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                        onPressed: () {
                          setState(() =>
                              _registrationFileName = 'uploaded_document.pdf');
                        },
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload file (placeholder)')),
                    if (_registrationFileName != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                              'Selected: ' + (_registrationFileName ?? ''))),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _signupCooldownTimer?.cancel();
    _companyName.dispose();
    _companyNameAr.dispose();
    _companyLegal.dispose();
    _companyIndustry.dispose();
    _companySize.dispose();
    _companyCountry.dispose();
    _foundedYear.dispose();
    _city.dispose();
    _streetAddress.dispose();
    _website.dispose();
    _linkedin.dispose();
    _email.dispose();
    _password.dispose();
    _contactName.dispose();
    _contactTitle.dispose();
    _taxId.dispose();
    super.dispose();
  }
}
