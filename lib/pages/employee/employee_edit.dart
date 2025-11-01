import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

class EmployeeEditPage extends StatefulWidget {
  const EmployeeEditPage({super.key});

  @override
  State<EmployeeEditPage> createState() => _EmployeeEditPageState();
}

class _EmployeeEditPageState extends State<EmployeeEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameEn = TextEditingController();
  final _companyNameAr = TextEditingController();
  final _legalName = TextEditingController();
  final List<String> _industries = const [
    "Technology",
    "Healthcare",
    "Finance",
    "Education",
    "Retail"
  ];
  final List<String> _companySizes = const [
    '1-10',
    '11-50',
    '51-200',
    '201-500',
    '500+'
  ];

  String? _industry;
  String? _companySize;
  String? _country;
  int? _foundedYear;
  late final List<int> _years;

  final _city = TextEditingController();
  final _streetAddress = TextEditingController();
  final _website = TextEditingController();
  final _linkedin = TextEditingController();
  String? _logoUrl;
  bool _uploadingLogo = false;
  Uint8List? _logoPreviewBytes;

  static const String _logoBucket = 'company-logos';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = DateTime.now().year;
    _years = List<int>.generate(current - 1899, (i) => current - i);
    _foundedYear = current;
    _country = 'Egypt';
    _loadEmployer();
  }

  Future<void> _loadEmployer() async {
    if (!SupabaseService.initialized) return;
    final client = SupabaseService.client;
    String? userId = client.auth.currentUser?.id;
    try {
      final authDyn = client.auth as dynamic;
      userId = userId ??
          (authDyn.currentUser != null ? authDyn.currentUser.id : null) ??
          (authDyn.user != null ? authDyn.user.id : null);
    } catch (_) {}
    if (userId == null) return;

    try {
      dynamic row;
      try {
        row = await (client.from('companies') as dynamic)
            .select()
            .eq('owner_user_id', userId)
            .maybeSingle();
      } catch (_) {
        final resp = await client
            .from('companies')
            .select()
            .eq('owner_user_id', userId)
            .execute();
        row = resp.data;
      }
      // Debug: print the raw returned row to console and show a short
      // preview in a SnackBar so you can inspect the types/values quickly.
      try {
        debugPrint('[_loadEmployer] raw row: ${row?.toString()}');
      } catch (_) {}

      if (row != null) {
        setState(() {
          // Use toString() conversions to avoid runtime cast errors when the
          // PostgREST response types vary (e.g. numbers, nulls, or strings).
          _companyNameAr.text = (row['name_ar'] ?? '').toString();
          _companyNameEn.text = (row['name_en'] ?? '').toString();
          _legalName.text = (row['legal_name'] ?? '').toString();

          final dynIndustry = row['industry'];
          _industry =
              (dynIndustry == null || dynIndustry.toString().trim().isEmpty)
                  ? null
                  : dynIndustry.toString();

          // `size` may be stored as text; tolerate any type and convert to string
          final dynSize = row['size'];
          _companySize = (dynSize == null || dynSize.toString().trim().isEmpty)
              ? null
              : dynSize.toString();

          final dynFounded = row['founded_year'];
          if (dynFounded is int) {
            _foundedYear = dynFounded;
          } else if (dynFounded is String) {
            _foundedYear = int.tryParse(dynFounded) ?? _foundedYear;
          }

          final dynCountry = row['country'];
          _country =
              (dynCountry == null || dynCountry.toString().trim().isEmpty)
                  ? null
                  : dynCountry.toString();

          _city.text = (row['city'] ?? '').toString();
          _streetAddress.text = (row['street_address'] ?? '').toString();
          _website.text = (row['website'] ?? '').toString();
          _linkedin.text = (row['linkedin_url'] ?? '').toString();

          final dynLogo = row['logo_url'] ?? row['kyc_doc_url'];
          _logoUrl = (dynLogo == null) ? null : dynLogo.toString();
        });
      }
    } catch (e) {
      _showSnack('Failed to load employer: $e');
    }
  }

  @override
  void dispose() {
    _companyNameEn.dispose();
    _companyNameAr.dispose();
    _legalName.dispose();
    _city.dispose();
    _streetAddress.dispose();
    _website.dispose();
    _linkedin.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _urlOrEmpty(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final text = v.trim();
    final ok = Uri.tryParse(text) != null &&
        (text.startsWith('http://') ||
            text.startsWith('https://') ||
            text.contains('.'));
    return ok ? null : 'Invalid URL';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _fileNameFor(XFile file) {
    try {
      final name = file.name;
      if (name.isNotEmpty) return name;
    } catch (_) {}
    final segments = file.path.split(RegExp(r'[\\/]+'));
    return segments.isNotEmpty ? segments.last : 'logo.png';
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  String _mimeTypeForFile(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    return 'image/jpeg';
  }

  Widget _buildLogoPreview() {
    final border = BorderRadius.circular(8);
    if (_logoPreviewBytes != null) {
      return ClipRRect(
        borderRadius: border,
        child: Image.memory(
          _logoPreviewBytes!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    }
    if (_logoUrl != null && _logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: border,
        child: Image.network(
          _logoUrl!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: border,
      ),
      child: const Icon(Icons.business, size: 56, color: Colors.grey),
    );
  }

  Future<void> _pickAndUploadLogo() async {
    if (_uploadingLogo) return;
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _logoPreviewBytes = bytes;
      });

      if (!SupabaseService.initialized) {
        _showSnack('Supabase is not initialized. Add your Supabase keys.');
        return;
      }

      setState(() {
        _uploadingLogo = true;
      });

      final client = SupabaseService.client;
      // require authenticated user to avoid RLS failures
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        _showSnack('You must be signed in to upload a logo');
        return;
      }
      final sanitizedName =
          _sanitizeFileName(_fileNameFor(picked).toLowerCase());
      final storagePath =
          'logos/$userId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
      final storage = client.storage.from(_logoBucket);
      final options = FileOptions(
        contentType: _mimeTypeForFile(sanitizedName),
        upsert: true,
      );
      try {
        await storage.uploadBinary(storagePath, bytes, fileOptions: options);
      } catch (err) {
        if (err.toString().contains('already exists')) {
          await storage.updateBinary(storagePath, bytes, fileOptions: options);
        } else {
          rethrow;
        }
      }
      final publicUrl = storage.getPublicUrl(storagePath);

      if (!mounted) return;
      setState(() {
        _logoUrl = publicUrl;
        _logoPreviewBytes = null;
      });
      _showSnack('Logo uploaded successfully.');
    } catch (e) {
      _showSnack('Failed to upload logo: $e');
    } finally {
      if (mounted) {
        setState(() {
          _uploadingLogo = false;
        });
      }
    }
  }

  Future<void> _saveEmployer() async {
    if (!_formKey.currentState!.validate()) return;
    if (!SupabaseService.initialized) {
      _showSnack('Supabase not initialized');
      return;
    }
    setState(() => _saving = true);
    final client = SupabaseService.client;
    String? userId = client.auth.currentUser?.id;
    try {
      final authDyn = client.auth as dynamic;
      userId = userId ??
          (authDyn.currentUser != null ? authDyn.currentUser.id : null) ??
          (authDyn.user != null ? authDyn.user.id : null);
    } catch (_) {}
    if (userId == null) {
      _showSnack('No authenticated user');
      setState(() => _saving = false);
      return;
    }

    final row = {
      'owner_user_id': userId,
      'name_ar': _companyNameAr.text.trim(),
      'name_en': _companyNameEn.text.trim(),
      'legal_name': _legalName.text.trim(),
      'industry': _industry,
      'size': _companySize,
      'founded_year': _foundedYear,
      'country': _country,
      'city': _city.text.trim(),
      'street_address': _streetAddress.text.trim(),
      'website': _website.text.trim(),
      'linkedin_url': _linkedin.text.trim(),
      'logo_url': _logoUrl,
    };

    try {
      // First ensure an existing company row belongs to this user. We will
      // only perform an update. If there is no existing row, inform the
      // user rather than inserting a new one.
      dynamic existing;
      try {
        existing = await (client.from('companies') as dynamic)
            .select()
            .eq('owner_user_id', userId)
            .maybeSingle();
      } catch (_) {
        final resp = await client
            .from('companies')
            .select()
            .eq('owner_user_id', userId)
            .execute();
        existing = resp.data;
      }

      if (existing == null) {
        _showSnack(
            'No company record found for this account. Create a profile first.');
        return;
      }

      // Perform update-only. If update fails or returns null, show a helpful
      // message (this often indicates RLS/permission issues on Supabase).
      try {
        final res = await (client.from('companies') as dynamic)
            .update(row)
            .eq('owner_user_id', userId)
            .maybeSingle();
        if (res == null) {
          _showSnack('Company updated');
        }
      } catch (e) {
        _showSnack('Update failed: $e');
      }
    } catch (e) {
      _showSnack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Company Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                      child: TextFormField(
                    controller: _companyNameAr,
                    decoration: const InputDecoration(
                        labelText: 'Company Name (Arabic)'),
                    validator: _required,
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextFormField(
                    controller: _companyNameEn,
                    decoration: const InputDecoration(
                        labelText: 'Company Name (English)'),
                    validator: _required,
                  )),
                ],
              ),
              const SizedBox(height: 12),
              // Logo preview + upload
              Center(
                child: Column(
                  children: [
                    _buildLogoPreview(),
                    const SizedBox(height: 8),
                    _uploadingLogo
                        ? const CircularProgressIndicator()
                        : TextButton.icon(
                            onPressed: _pickAndUploadLogo,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload logo'),
                          ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              TextFormField(
                  controller: _legalName,
                  decoration: const InputDecoration(labelText: 'Legal Name'),
                  validator: _required),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: DropdownButtonFormField<String>(
                  // Only set initialValue when it matches one of the items.
                  initialValue:
                      (_industry != null && _industries.contains(_industry))
                          ? _industry
                          : null,
                  items: _industries
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _industry = v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                  decoration: const InputDecoration(labelText: 'Industry'),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: DropdownButtonFormField<String>(
                  // `companies.size` stores short values like '1-10'. Only use
                  // the stored value if it matches one of the dropdown items.
                  initialValue: (_companySize != null &&
                          _companySizes.contains(_companySize))
                      ? _companySize
                      : null,
                  items: _companySizes
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _companySize = v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                  decoration: const InputDecoration(labelText: 'Company Size'),
                )),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: DropdownButtonFormField<int>(
                  initialValue: _foundedYear,
                  items: _years
                      .map((y) =>
                          DropdownMenuItem(value: y, child: Text(y.toString())))
                      .toList(),
                  onChanged: (v) => setState(() => _foundedYear = v),
                  validator: (v) => (v == null) ? 'Required' : null,
                  decoration: const InputDecoration(labelText: 'Founded Year'),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: DropdownButtonFormField<String>(
                  // Only set initialValue if it matches one of the allowed names.
                  initialValue: (_country != null &&
                          [
                            'Egypt',
                            'Saudi Arabia',
                            'United Arab Emirates',
                            'United States'
                          ].contains(_country))
                      ? _country
                      : null,
                  items: const [
                    DropdownMenuItem(value: 'Egypt', child: Text('Egypt')),
                    DropdownMenuItem(
                        value: 'Saudi Arabia', child: Text('Saudi Arabia')),
                    DropdownMenuItem(
                        value: 'United Arab Emirates',
                        child: Text('United Arab Emirates')),
                    DropdownMenuItem(
                        value: 'United States', child: Text('United States')),
                  ],
                  onChanged: (v) => setState(() => _country = v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                  decoration: const InputDecoration(labelText: 'Country'),
                )),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: _city,
                        decoration: const InputDecoration(labelText: 'City'))),
                const SizedBox(width: 12),
                Expanded(
                    child: TextFormField(
                        controller: _streetAddress,
                        decoration: const InputDecoration(
                            labelText: 'Street Address'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: _website,
                        decoration: const InputDecoration(labelText: 'Website'),
                        validator: _urlOrEmpty)),
                const SizedBox(width: 12),
                Expanded(
                    child: TextFormField(
                        controller: _linkedin,
                        decoration: const InputDecoration(
                            labelText: 'LinkedIn Profile URL'),
                        validator: _urlOrEmpty)),
              ]),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () {
                        _saveEmployer();
                      },
                child: _saving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator())
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
