import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

// This page loads the current seeker's profile from `seeker_profiles`
// and allows the user to update it. It uses the authenticated user's
// id as the record id (id == auth.uid()).

class SeekerEditPage extends StatefulWidget {
  const SeekerEditPage({super.key});

  @override
  State<SeekerEditPage> createState() => _SeekerEditPageState();
}

class _SeekerEditPageState extends State<SeekerEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _jobTitle = TextEditingController();
  final _nationality = TextEditingController();
  final _country = TextEditingController();
  final _phone = TextEditingController();
  Uint8List? _imagePreviewBytes;
  String? _profileImageUrl;
  bool _uploadingImage = false;

  // Use your Supabase storage bucket name (from the screenshot it's `profile_image`)
  static const String _imageBucket = 'profile_image';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!SupabaseService.initialized) return;
    final client = SupabaseService.client;
    // try to get user id robustly
    String? userId = client.auth.currentUser?.id;
    try {
      final authDyn = client.auth as dynamic;
      userId = userId ??
          (authDyn.currentUser != null ? authDyn.currentUser.id : null) ??
          (authDyn.user != null ? authDyn.user.id : null);
    } catch (_) {}
    if (userId == null) return;

    try {
      dynamic profile;
      try {
        profile = await (client.from('seeker_profiles') as dynamic)
            .select()
            .eq('id', userId)
            .maybeSingle();
      } catch (_) {
        final resp = await client
            .from('seeker_profiles')
            .select()
            .eq('id', userId)
            .execute();
        profile = resp.data;
      }
      if (profile != null) {
        setState(() {
          _fullName.text = (profile['full_name'] ?? '') as String;
          _jobTitle.text = (profile['job_title'] ?? '') as String;
          _nationality.text = (profile['nationality'] ?? '') as String;
          _country.text = (profile['country'] ?? '') as String;
          _phone.text = (profile['phone'] ?? '') as String;
          _profileImageUrl = (profile['profile_image_url'] ?? '') as String?;
        });
      }
    } catch (e) {
      // ignore load errors for now, show a SnackBar
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load profile: $e')));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (!SupabaseService.initialized) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supabase not initialized')));
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No authenticated user')));
      setState(() => _saving = false);
      return;
    }

    final row = {
      'full_name': _fullName.text.trim(),
      'job_title': _jobTitle.text.trim(),
      'nationality': _nationality.text.trim(),
      'country': _country.text.trim(),
      'phone': _phone.text.trim(),
      'profile_image_url': _profileImageUrl,
    };

    try {
      // Try update first (modern client API)
      bool updated = false;
      try {
        final res = await (client.from('seeker_profiles') as dynamic)
            .update(row)
            .eq('id', userId)
            .maybeSingle();
        if (res != null) updated = true;
      } catch (_) {
        // Legacy flow: use execute() then verify by selecting the row
        try {
          await client
              .from('seeker_profiles')
              .update(row)
              .eq('id', userId)
              .execute();
        } catch (_) {
          // ignore update error here, we'll try to verify below
        }

        try {
          dynamic verify = await (client.from('seeker_profiles') as dynamic)
              .select()
              .eq('id', userId)
              .maybeSingle();
          if (verify != null) updated = true;
        } catch (_) {
          final check = await client
              .from('seeker_profiles')
              .select()
              .eq('id', userId)
              .execute();
          if (check.data != null) updated = true;
        }
      }

      if (!updated) {
        // Insert as fallback (set id so RLS allows it if policies require id == auth.uid()).
        // Treat duplicate-key errors as success because the row already exists.
        final insertRow = {
          'id': userId,
          'full_name': row['full_name'],
          'job_title': row['job_title'],
          'nationality': row['nationality'],
          'country': row['country'],
          'phone': row['phone']
        };
        try {
          try {
            await (client.from('seeker_profiles') as dynamic)
                .insert(insertRow)
                .execute();
          } catch (_) {
            await client.from('seeker_profiles').insert(insertRow).execute();
          }
        } catch (e) {
          final msg = e.toString();
          if (msg.contains('duplicate key') || msg.contains('23505')) {
            // row exists — treat as saved
          } else {
            rethrow;
          }
        }
      }

      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _jobTitle.dispose();
    _nationality.dispose();
    _country.dispose();
    _phone.dispose();

    super.dispose();
  }

  String _fileNameFor(XFile file) {
    try {
      final name = file.name;
      if (name.isNotEmpty) return name;
    } catch (_) {}
    final segments = file.path.split(RegExp(r'[\\/]+'));
    return segments.isNotEmpty ? segments.last : 'image.png';
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

  Widget _buildImagePreview() {
    final border = BorderRadius.circular(8);
    if (_imagePreviewBytes != null) {
      return ClipRRect(
        borderRadius: border,
        child: Image.memory(
          _imagePreviewBytes!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    }
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: border,
        child: Image.network(
          _profileImageUrl!,
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
      child: const Icon(Icons.person, size: 56, color: Colors.grey),
    );
  }

  Future<void> _pickAndUploadImage() async {
    if (_uploadingImage) return;
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
        _imagePreviewBytes = bytes;
      });

      if (!SupabaseService.initialized) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Supabase is not initialized.')));
        return;
      }

      setState(() => _uploadingImage = true);

      final client = SupabaseService.client;
      // Require a signed-in user for uploads. Using a fallback like 'anonymous'
      // can trigger row-level security (RLS) failures when the DB expects
      // id == auth.uid(). Show a friendly message instead of proceeding.
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('You must be signed in to upload a profile image')));
        return;
      }
      final sanitizedName =
          _sanitizeFileName(_fileNameFor(picked).toLowerCase());
      final storagePath =
          'profiles/$userId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
      final storage = client.storage.from(_imageBucket);
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
        _profileImageUrl = publicUrl;
        _imagePreviewBytes = null;
      });
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Image uploaded')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Seeker Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image preview + upload
              Center(
                child: Column(
                  children: [
                    _buildImagePreview(),
                    const SizedBox(height: 8),
                    _uploadingImage
                        ? const CircularProgressIndicator()
                        : TextButton.icon(
                            onPressed: _pickAndUploadImage,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload photo'),
                          ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _jobTitle,
                decoration: const InputDecoration(labelText: 'Job Title'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nationality,
                decoration: const InputDecoration(labelText: 'Nationality'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _country,
                decoration: const InputDecoration(labelText: 'Country'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _saveProfile,
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
